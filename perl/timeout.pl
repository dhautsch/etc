#!/usr/bin/perl
#
# http://www.perlmonks.org/?node_id=783615
#

use strict;

my $ALARM = shift;

if (@ARGV) {

	my @a_;

	foreach (@ARGV) {
		if (substr($_, 0, 1) eq "'") {
			push @a_, $_;
		}
		else {
			push @a_, "'$_'";
		}
	}

	eval {
		local $SIG{ALRM} = sub { die "ALARM\n" }; # NB: \n required
		alarm($ALARM);
		print qx(@a_);
		alarm(0);
	};
}
