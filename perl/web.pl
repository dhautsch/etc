#!/usr/bin/perl
#
#

use File::Basename;
use Getopt::Long;
use strict;

my $UNAME = qx(uname); chomp $UNAME;
sub ps {
        my @ret_;
        my $cmd_ = 'ps --columns=2000 -ef 2>&1';

        if ($UNAME eq 'SunOS') {
                $ENV{COLUMNS} = 2000;
                $cmd_ = 'ps -ef 2>&1';
        }

        foreach (qx($cmd_)) {
                if (m!/usr/bin/perl\s+(\-d\s+)*$0\s+\-start!) {
                        s!^\s+!!;
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

use Socket;
use Carp;

my $HOST = qx(uname -n); chomp $HOST;
my $PID = $$;
my $TMP;
my $EOL = "\015\012";
my $TRAILING_DEC = '(\d+)$';
my $INT_PAT = "^$TRAILING_DEC";

sub spawn;  # forward declaration

sub ts {
	my $ts_ = shift || time;

	if ($ts_) {
		my @t_ = localtime($ts_); 
		$ts_ = sprintf("%d%2.2d%2.2d%2.2d%2.2d%2.2d", $t_[5]+1900,$t_[4]+1,$t_[3],$t_[2], $t_[1], $t_[0]);
	}
	else {
		$ts_ = undef;
	}

	return $ts_;
}

sub logmsg {
	my $ts_ = ts();

	print STDERR "$$:$ts_ @_\n";
}

foreach my $p_ (glob("http-$HOST_ALIAS-*-tmp")) {
	unlink($p_);
}

my $PORT = $PROP{$PROP[$#PROP]};

my $PROTO = getprotobyname('tcp');

($PORT) = $PORT =~ /^(\d+)$/ or die "invalid port";
socket(SERVER, PF_INET, SOCK_STREAM, $PROTO)	|| die "socket: $!";
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "setsockopt: $!";
bind(SERVER, sockaddr_in($PORT, INADDR_ANY)) || die "bind: $!";
listen(SERVER, SOMAXCONN) || die "listen: $!";

logmsg "$0 started on port $PORT";

my $PADDR;
use POSIX ":sys_wait_h";
use Errno;

sub REAPER {
	local $!;   # don't let waitpid() overwrite current error

	while ((my $pid_ = waitpid(-1,WNOHANG)) > 0 && WIFEXITED($?)) {
		logmsg "reaped $pid_" . ($? ? " with exit $?" : '') if $ENV{DEBUG_REAPER};
	}

	$SIG{CHLD} = \&REAPER;  # loathe sysV
}

$SIG{CHLD} = \&REAPER;

while(1) {
	$PADDR = accept(CLIENT, SERVER) || do {
	# try again if accept() returned because a signal was received
		next if $!{EINTR};
		die "accept: $!";
	};

	my ($port_, $iaddr_) = sockaddr_in($PADDR);
	my $name_ = gethostbyaddr($iaddr_, AF_INET);

	$name_ =~ s!\..*!!; # trim off domain

	$name_ = "$name_\[" . inet_ntoa($iaddr_) . "]:$port_";

	spawn sub {
		$|=1;

		my $httpStat_ = "404 Not Found";
		my $ct_;
		my $get_;
		my $ls_;
		my $health_;
		my $last_;
		my $l_ = 0;
		my $out_;
		my $logMsg_= "$name_ \042$get_\042 $httpStat_";

		while (<>) {
			$get_ = $1 if m!^(GET\s+/infaps)!;
			$ls_ = $1 if m!^(GET\s+/ls)!;
			$last_ = $1 if m!^(GET\s+/last)!;
			$health_ = $1 if m!^(GET\s+/health/\d+)!;
			last if m!^\s!;
		}


		#
		# Here is where we do the work
		#
		if ($get_ || $ls_ || $last_ || $health_) {
			my @a_;
			my $ts_ = ts();
			my $fmtLen_ = sprintf("%12.12d", $l_);

			$TMP = "$TOP/http-$$-tmp";

			open(TMP, ">$TMP") or die "Wopen $TMP : $!";

			if ($ls_ || $get_) {
				print TMP "#\n# http_mpstat TS=$ts_ HTTP_PORT(PID)=$HOST:$PORT($PID) LEN=$fmtLen_\n#\n";
			}

			if ($ls_) {
				$get_ = $ls_;

				map { print TMP } qx(ls -lart $TOP);
			}
			elsif ($last_ || $health_) {
				my $output_;

				if ($health_ =~ m!$TRAILING_DEC!) {
					$output_ = $1;
					$get_ = $health_;
				}
				else {
					$get_ = $last_;
				}

				foreach (qx($TOP/infaps)) {
					@a_ = split;

					print TMP join('@', 'infaps', $ts_, $HOST, $a_[2], $a_[3], $a_[5]), "\n";
				}

				my @files_ = glob("$LOGNAME_PAT*.log");

				if (scalar(@files_) > 0 && ! $output_) {
					@files_ = ( $files_[$#files_] );
				}

				foreach (@files_) {
					my $f_ = $_;

					s!$LOGNAME_PAT.!!;
					s!.log!!;

					if (m!$INT_PAT!) {
						my $i_ = $1;

						if (($last_ || $i_ > $output_) && open(IN, $f_)) {
							my $cnt_ = 0;

							while (<IN>) {
								print TMP;
								$cnt_++;
							}

							print TMP "fetched\@$i_\@$HOST\@$f_\@$cnt_\n";

							close IN;
						}
					}
				}

				print TMP join('@', 'http_mpstat', $ts_, $HOST, $PORT, $PID, $get_, $fmtLen_), "\n";
			}
			else {
				map { print TMP } qx($TOP/infaps);
			}

			close TMP;

			#
			# Linux seems to not be syncing to disk properly but the following
			# causes the sync and returns the file size
			#
			@a_ = split(/\s+/, scalar(qx(wc -c $TMP)));
			foreach (qx(wc -c $TMP)) {
				s!^\s+!!;
				@a_ = split;
				$l_ = $a_[0];
			}
#			logmsg "xx l_=$l_";

			$httpStat_ = "200 OK";

			$logMsg_ = "$name_ \042$get_\042 $httpStat_";

			$ct_ = "text/plain";
		}

		print "HTTP/1.1 $httpStat_$EOL";
		print "Server: $0$EOL"; 
#FIX DATE
#		print "Date: Wed, 12 Oct 2016 00:29:51 GMT$EOL";
		print "Connection: close$EOL";
		print "Content-type: $ct_$EOL" if $ct_;
		print "Content-Length: $l_$EOL$EOL";

		if ($ct_) {
			open(TMP, $TMP) or die "Ropen $TMP : $!";
			while (<TMP>) {
				if (m!^(\#\s)*http_mpstat!) {
					my $fmtLen_ = sprintf("%12.12d", $l_);

					s!$TRAILING_DEC!$fmtLen_!;
				}
				print;
			}
			close TMP;
			unlink($TMP);
		}
		print $EOL if $ct_;

		logmsg $logMsg_;

#		while ( <> ) { }; # NO OPERATION, waiting for client to close
	};

	close CLIENT;
}

sub spawn {
	my $coderef = shift;

	unless (@_ == 0 && $coderef && ref($coderef) eq 'CODE') {
		confess "usage: spawn CODEREF";
	}

	my $pid_;

	if (! defined($pid_ = fork)) {
		logmsg "cannot fork: $!";
		return;
	} 
	elsif ($pid_) {
		logmsg "begat $pid_" if $ENV{DEBUG_REAPER};
		return; # I'm the parent
	}
	# else I'm the child -- go spawn
	open(STDIN,  "<&CLIENT")   || die "can't dup client to stdin";
	open(STDOUT, ">&CLIENT")   || die "can't dup client to stdout";
	## open(STDERR, ">&STDOUT") || die "can't dup stdout to stderr";
	exit &$coderef();
}
