#!/usr/bin/perl

use strict;

if ($ENV{RP_USERPASS}) {
    my @a_ = split(/\//, $ENV{RP_USERPASS});
    $ENV{RP_USER} = $a_[0];
    $ENV{RP_PASSWORD} = $a_[1];
}
else {
    print STDERR "Input User Id : ";
    $ENV{RP_USER} = <STDIN>; chomp $ENV{RP_USER};

    print STDERR "Input Password : ";
    system ( "stty -echo");
    $ENV{RP_PASSWORD} = <STDIN>; chomp $ENV{RP_PASSWORD};
    system ( "stty echo");
}

my $EXIT = 1;

if ($ENV{RP_USER} && $ENV{RP_PASSWORD}) {
    my $tmp_ = "/tmp/tmp-$$.txt";
    my $uname_ = qx(uname -a);
    my $cmd_ = "ldapsearch";
    my $searchBase_ = 'ou=corporate,dc=yoyodyne,dc=com';
    my $bindDN_ = "uid=$ENV{RP_USER},ou=people,$searchBase_";

    END { unlink($tmp_) };

    open(TMP, ">$tmp_") or die "Wopen $tmp_ : $!";
    chmod(0600, $tmp_ ) or die "Chmod $tmp_ : $!";
    print TMP $ENV{RP_PASSWORD};
    close TMP;

    if ($uname_ =~ m!Linux!) {
        $cmd_ .= " -y";
    }
    else {
        $cmd_ .= " -j";
    }

    $cmd_ .= " $tmp_ -D $bindDN_ -h enterprise-ldap -b $searchBase_ '(uid=$ENV{RP_USER})' dn";

    foreach (qx($cmd_ 2>&1)) {
        if (m!^dn:\s+$bindDN_!) {
            $EXIT = 0;
            print "\n$_";
        }
    }
}
print "\nVALIDATION FAILED\n" if $EXIT;

exit($EXIT);
