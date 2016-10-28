#!/usr/bin/perl

use strict;
my $HOSTNAME = qx(uname -n); chomp $HOSTNAME;
my $IPADDRESS = qx(host -t a $HOSTNAME); chomp $IPADDRESS; $IPADDRESS =~ s!.*\s+!!;
my $INTERFACE = qx(/sbin/ifconfig |grep -B1 $IPADDRESS | head -1); chomp $INTERFACE;
my @a_ = split(/\s+/, $INTERFACE);
my $MAC = uc($a_[$#a_]);
my $SPEED;

$INTERFACE = $a_[0];

foreach (qx(/sbin/ethtool  $INTERFACE 2>/dev/null)) {
        if (m!Speed:\s+(\S+)!) {
                $SPEED = $1;
                $SPEED =~ s/000M/G/g;
        }
}

print "$MAC\n";
print "$SPEED\n";
