#!/usr/bin/perl

use strict;
my @HEX = qw(0 1 2 3 4 5 6 7 8 9 A B C D E F);

print "\tfinal static char[] K = { ";

foreach my $i_ (0..$#HEX) {
        print ", " if $i_;
        print "'";
        print $HEX[int(rand(16))];
        print "'";
}

print " };\n";
