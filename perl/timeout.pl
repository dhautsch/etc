#!/usr/bin/perl
#
# http://www.perlmonks.org/?node_id=783615
#

use strict;

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


my $ALARM = shift;
my $CHILD;
my $EC = 0;

exit(1) unless @ARGV;

sub REAPER {
	my $pid_ = wait;
	my $ec_ = $?;
	# loathe sysV: it makes us not only reinstate
	# the handler, but place it after the wait
	$SIG{CHLD} = \&REAPER;

	logmsg "In REAPER CHILD_PID=$pid_ EC=$?" if $ENV{DEBUG_REAPER};

	return ($pid_, $ec_);
}
$SIG{CHLD} = \&REAPER;

$SIG{ALRM} = sub {
	my $msg_ = "ALARM";

	if ($CHILD) {
		kill('ALRM', $CHILD);

		$msg_ = "kill($CHILD) $msg_";
	}
	logmsg $msg_ if $ENV{DEBUG_REAPER};
};

alarm($ALARM);

if (! defined($CHILD = fork)) {
	logmsg "cannot fork: $!";
	exit(2);
}
elsif ($CHILD) {
	logmsg "begat $CHILD" if $ENV{DEBUG_REAPER};
}
else {
	exec(@ARGV);
	exit(0);
}

logmsg "Before REAPER CHILD_PID=$CHILD ALARM=$ALARM" if $ENV{DEBUG_REAPER};
($CHILD, $EC) = REAPER();
logmsg "After REAPER CHILD_PID=$CHILD EC=$EC" if $ENV{DEBUG_REAPER};
alarm(0);
exit($EC);
