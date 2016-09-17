#!/usr/bin/perl
#
# Use this as a template for a daemon
#
use File::Basename;
use Getopt::Long;
use strict;

sub ps {
	my @ret_;

	foreach (qx(ps --columns=2000 -ef 2>&1)) {
		if (m!/usr/bin/perl\s+$0!) {
			my @a_ = split(/\s+/, $_);

			next if $a_[$#a_] ne '-start';

			push @ret_, $_;
		}
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
unless ($ENV{A22_SKIP_NOHUP}) {
	unless ($ENV{A22_RUN_PROCESS_NOHUP}) {
		my $cmd_ = "nohup $0 -start < /dev/null > /dev/null 2>&1 &";

		print STDERR "$HOST $cmd_\n";
		$ENV{A22_RUN_PROCESS_NOHUP} = $$;
		exec($cmd_);
		exit(2);
	}
}


#
# Add your code after here
#

#
# Add your code after here
#
while (sleep(60)) {
  1;
}
exit(0);
