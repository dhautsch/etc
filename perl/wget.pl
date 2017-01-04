#!/usr/bin/perl

use strict;
use IO::Socket;

my $EOL = "\015\012";
my $BLANK = $EOL x 2;
my %INET = (Proto => "tcp");

if (@ARGV == 1 && $ARGV[0] =~ m!^http://([^\:]+):(\d+)(\S+)!) {
        $INET{PeerAddr} = $1;
        $INET{PeerPort} = $2;
        $INET{Url} = $3;
}
else {
        die "Usage: $0 http://<host>:<port></url>";
}

my $remote_ = IO::Socket::INET->new(%INET) || die "cannot connect to httpd on $INET{PeerAddr}";

$remote_->autoflush(1);
print $remote_ "GET $INET{Url} HTTP/1.0" . $BLANK;
while ( <$remote_> ) {
        print;
}

close $remote_;
