#!/usr/bin/perl
#
# Simple web server
#
use strict;
use Socket;
use Carp;

my $EOL = "\015\012";

sub spawn;  # forward declaration
sub logmsg {
	my @t_ = localtime;
	my $s_ = sprintf("%4.4d%2.2d%2.2d%2.2d%2.2d%2.2d", $t_[5]+1900, $t_[4]+1, $t_[3], $t_[2], $t_[1], $t_[0]);

	print STDERR "$$:$s_ @_\n";
}

unless ($0 =~ m!^/!) {
	logmsg "Use full path to invoke $0";
	exit(1);
}

my $PORT = shift;

unless ($PORT) {
	logmsg "Usage $0 PORT";
	exit(1);
}

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

	$name_ = "$name_\[" . inet_ntoa($iaddr_) . "]:$port_";

	spawn sub {
		$|=1;

		my $httpStat_ = "404 Not Found";
		my $ct_;
		my $get_;
		my $l_ = 0;
		my $out_;
		my $logMsg_= "$name_ \042$get_\042 $httpStat_";

		while (<>) {
			$get_ = $1 if m!^(GET\s+\S+\s+\S+)!;
			last if m!^\s!;
		}


		#
		# Here is where we do the work
		#
		if ($get_) {
			$httpStat_ = "200 OK";

			$logMsg_ = "$name_ \042$get_\042 $httpStat_";

			$out_ = "#\n# $logMsg_\n#\n" . scalar(qx(cat $0));
			$l_ = length($out_);

			$ct_ = "text/plain";
		}

		print "HTTP/1.1 $httpStat_$EOL";
		print "Server: $0$EOL"; 
#FIX DATE
#		print "Date: Wed, 12 Oct 2016 00:29:51 GMT$EOL";
		print "Connection: close$EOL";
		print "Content-type: $ct_$EOL" if $ct_;
		print "Content-Length: $l_$EOL$EOL";
		print $out_ if $ct_;
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
