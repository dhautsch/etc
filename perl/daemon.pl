#!/usr/bin/perl
#
#

use File::Basename;
use Getopt::Long;
use strict;

sub ps {
	my @ret_;

	foreach (qx(ps --columns=2000 -ef 2>&1)) {
		push @ret_, $_ if m!/usr/bin/perl\s+(\-d\s+)*$0\s+\-start!;
	}

	return @ret_;
}

my $HOST = qx(uname -n); chomp $HOST;
my $TOP = dirname($0);
my %OPTS;

unless ($TOP =~ m!^/!) {
	print STDERR "Use full path to invoke $0, exiting...\n";
	exit(2);
}

$OPTS{help}++ unless GetOptions(\%OPTS, 'ps', 'stop', 'restart', 'start');

$OPTS{CNT} = scalar(keys %OPTS);
$OPTS{help}++ if $OPTS{CNT} > 1;
$OPTS{help}++ unless $OPTS{CNT};

if ($OPTS{help}) {
	print STDERR "Usage: $0 (-ps|-stop|-start|-restart)\n";
	print STDERR "\t-ps  : show running process.\n";
	print STDERR "\t-stop  : stop running process.\n";
	print STDERR "\t-start : start the process.\n";
	print STDERR "\t-restart : stop and start the process.\n";
	exit(2);
}

$OPTS{stop}++ if $OPTS{restart};

$OPTS{LOG} = $ARGV[0] ? $ARGV[0] : '/dev/null';

if ($OPTS{stop} || $OPTS{ps}) {
	my @ps_ = ps();

	if (scalar(@ps_)) {
		if ($OPTS{ps}) {
			map { print STDERR "$HOST $_" } @ps_;
			exit(0);
		}

		foreach my $ps_ (@ps_) {
			my @a_ = split(/\s+/, $ps_);

			print STDERR "$HOST killng $ps_";

			if (kill(15, $a_[1])) {
			}
			else {
				print STDERR "$HOST failed to kill $ps_";
				exit(1);
			}
		}

		exit(0) if $OPTS{stop} && ! $OPTS{restart};
	}
	else {
		print STDERR "$HOST $0 not running!!!\n";
		exit(0) unless $OPTS{restart};
	}
}

if (scalar(ps()) > 1) {
	print STDERR "$HOST $0 already running, exiting...\n";
	exit(0);
}

#$ENV{A22_SKIP_NOHUP}++;
unless ($ENV{SKIP_NOHUP}) {
	unless ($ENV{RUN_PROCESS_NOHUP}) {
		my $cmd_ = "nohup $0 -start < /dev/null > $OPTS{LOG} 2>&1 &";

		print STDERR "$HOST $cmd_\n";
		$ENV{RUN_PROCESS_NOHUP} = $$;
		exec($cmd_);
		exit(2);
	}
}


#
# Add your code after here
#

my $INT_REGEX = '^\d+$';
my $WS_REGEX = '^\s*$';
my $TRL_WS = '\s*$';
my $HOST_ALIAS = $HOST; $HOST_ALIAS =~ s!^.*\-!!;
my $CFG = "$TOP/config.properties";
my @PROP = qw(
monitor.url
monitor.mpstat_interval
monitor.mpstat_count
monitor.port
);
my $PROP_REGEX_STR = '^(' . join('|', @PROP) . ')=(.*)';
my $PROP_REGEX = qr($PROP_REGEX_STR);
my %PROP;

my @OUT;

open(CFG, $CFG) or die "Ropen $CFG : $!";
while (<CFG>) {
	if (m!$PROP_REGEX!) {
		my $k_ = $1;
		my $v_ = $2;

		$v_ =~ s!$TRL_WS!!;

		$PROP{$k_} = $v_ if $v_;
	}
}
close CFG;

my $LOGNAME_PAT = "mpstat_${HOST_ALIAS}";

chdir($TOP) or die "Chdir $TOP : $!";

$ENV{MPSTAT_INTERVAL} = $PROP{$PROP[1]} if $PROP{$PROP[1]};
$ENV{MPSTAT_COUNT} = $PROP{$PROP[2]} if $PROP{$PROP[2]};

unless ($PROP{$PROP[0]}) {
	print STDERR "Not defined $PROP[0]!!!\n";
	exit(2);
}


use POSIX ":sys_wait_h";
use CGI::Util;

my %FORK;
my $SECS = 300;
my $MAX_PROCESSED_TS = 0;

foreach my $p_ (glob("$LOGNAME_PAT.*.tmp")) {
	unlink($p_);
}

my $CURRENT = time;
my $NEXT = int($CURRENT/($SECS))*$SECS+$SECS;
my $SLEEP = $NEXT - $CURRENT;

if ($SLEEP > 0) {
	print STDERR ts($CURRENT) . " sleep $SLEEP seconds.\n";
	sleep($SLEEP);
}

while (1) {
	$NEXT += $SECS;
	$ENV{MPSTAT_COLLECTED} = $NEXT;

	my $tsFormated_ = ts($ENV{MPSTAT_COLLECTED});
	my $tmp_ = "$LOGNAME_PAT.$tsFormated_.tmp";
	my $rename_ = "$LOGNAME_PAT.$tsFormated_.log";

	open(OUT, ">$tmp_") or die "Wopen $tmp_ : $!";
	close OUT;

	foreach my $p_ (qx(find $TOP -mmin +300 -name '$LOGNAME_PAT.*.log')) {
		chomp $p_;
		unlink($p_);
	}

	my $child_ = fork();

	if (defined $child_) {
		if ($child_) { # in parent
			$FORK{$child_} = $tsFormated_;

			print STDERR ts(time) . " forked PID=$child_ for $tmp_\n";
		}
		else { # in child


			open(OUT, ">$tmp_") or die "Wopen $tmp_ : $!";

			foreach (qx(df -k 2>/dev/null)) {
				my @a_ = split;

				$a_[4] =~ s!\%!!;

				next unless $a_[4] =~ m!$INT_REGEX!;

				print OUT join('@', 'df', $tsFormated_, $HOST, $a_[5], $a_[4]), "\n";
			}

			foreach my $f_ (qw(PHealthMon.ksh Static.ksh RunTop.ksh)) {
				foreach (qx($TOP/$f_)) {
					print OUT join('@', $f_, $tsFormated_, $HOST, $_);
				}
			}

			close OUT;

			exit(0);
		}
	}
	else {
		print STDERR ts(time) . " fork failed for $tmp_!!!\n";
	}

	$child_ = waitpid(-1, WNOHANG);

	if ($child_ > 0 && $FORK{$child_}) {
		$tsFormated_ = $FORK{$child_};

		$tmp_ = "$LOGNAME_PAT.$tsFormated_.tmp";
		$rename_ = "$LOGNAME_PAT.$tsFormated_.log";

		print STDERR ts(time) . " PID=$child_ completed.\n";

		if ($tsFormated_ > $MAX_PROCESSED_TS) {
			$MAX_PROCESSED_TS = $tsFormated_;

			rename($tmp_, $rename_) or die "Rename $rename_ : $!";

			print STDERR ts(time) . " PID=$child_ rename $tmp_ to $rename_.\n";

			my $stat_ = 999;;
			my $url_ = "$PROP{$PROP[0]}?ts=$tsFormated_";

			foreach (qx(wget --spider $url_ 2>&1)) {
				if (m!HTTP\s+request\s+sent,\s+awaiting\s+response...\s+(\d+)!) {
					$stat_ = $1;
				}
			}

			print STDERR ts(time) . " $stat_ $url_\n";

			delete $FORK{$child_};
		}
		else {
			print STDERR ts(time) . " PID=$child_ unlink $tmp_!!!\n";
		}
	}

	$CURRENT = time;
	$SLEEP = $NEXT - $CURRENT;
	if ($SLEEP > 0) {
		print STDERR ts($CURRENT) . " sleep $SLEEP seconds.\n";
		sleep($SLEEP);
	}

}
exit(0);

sub ts {
	my $ts_ = shift;

	if ($ts_) {
		my @t_ = localtime($ts_); 
		$ts_ = sprintf("%d%2.2d%2.2d%2.2d%2.2d%2.2d", $t_[5]+1900,$t_[4]+1,$t_[3],$t_[2], $t_[1], $t_[0]);
	}
	else {
		$ts_ = undef;
	}

	return $ts_;
}
