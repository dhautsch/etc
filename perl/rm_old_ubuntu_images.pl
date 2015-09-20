#!/usr/bin/perl
# list old kernels
# dpkg -l linux-{image,headers}-"[0-9]*" | awk '/ii/{print $2}'
#
# dont delete oldest current or next to current
# get current with uname -r
#
use Data::Dumper;
use strict;

my @HEADERS;
my @VERSIONS;
my %SAVE_VERSIONS;
my %WHACK_VERSIONS;
my $QX = 'dpkg -l';

$Data::Dumper::Sortkeys++;

$ENV{COLUMNS} = 500;

foreach (qx($QX)) {
    if (m!^ii\s+(linux-(image|headers)-\d+\S+)!) {
	if ($2 eq 'image') {
	    push @VERSIONS, $1;
	}
	else {
	    push @HEADERS, $1;
	}
    }
}

map { $SAVE_VERSIONS{$_}++ } shift @VERSIONS;
map { $SAVE_VERSIONS{$_}++ } pop @VERSIONS;
map { $SAVE_VERSIONS{$_}++ } pop @VERSIONS;

foreach (keys %SAVE_VERSIONS) {
    my $pat_ = $_;
    $pat_ =~ s!^\w+-\w+-!!;
    $pat_ =~ s!-\w+$!!;
    map { $SAVE_VERSIONS{$_}++ } grep {/$pat_/} @HEADERS;
}

foreach (@VERSIONS, @HEADERS) {
    $WHACK_VERSIONS{$_}++ unless $SAVE_VERSIONS{$_};
}

print "###\n### To WHACK : $0 WHACK\n###\n### SAVE VERSIONS\n###\n";
map { print "$_\n" } sort keys %SAVE_VERSIONS;
print "###\n### WHACK VERSIONS\n###\n";
map { print "$_\n" } sort keys %WHACK_VERSIONS;

if ($ARGV[0] eq 'WHACK') {
    map { print qx(sudo apt-get purge -y $_) } sort keys %WHACK_VERSIONS;
}
#sudo apt-get purge $(from list above)
