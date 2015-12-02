#!/usr/bin/perl

use Data::Dumper;
use strict;

my $TIME = time;
my $DAY = 86400;
my @TIME = localtime(time);
my %H;
my %WDAY = (Sun => 0, Mon => 1, Tue => 2, Wed => 3, Thur => 4, Fri => 5, Sat => 6);
my $WDAY;
my $PAT = '(1st|2nd|3rd|4th|5th|6th)_(Sun|Mon|Tue|Wed|Thur|Fri|Sat)';
my $WDAY_CNT;
my @OUT;

if (@ARGV == 1 && $ARGV[0] =~ m!$PAT!) {
	$WDAY_CNT = substr($1, 0, 1);
	$WDAY = $WDAY{$2};
	$WDAY_CNT--;
}
else {
	print "Usage: $0 $PAT\n";
	exit(1);
}

$TIME -= $TIME[0];
$TIME -= ($TIME[1]*60);
$TIME -= ($TIME[3]*$DAY);
$TIME += ((12-$TIME[2])*3600);

$Data::Dumper::Sortkeys++;

foreach my $i_ (1..365) {
	$TIME += $DAY;

	@TIME = localtime($TIME);
	$TIME[5] += 1900;
	$TIME[4] = sprintf("%02d", $TIME[4] + 1);
	$TIME[3] = sprintf("%02d", $TIME[3]);

	push @{$H{$TIME[5]}{$TIME[4]}{WDAY}[$TIME[6]]}, {'DATE', sprintf("%04d-%s-%s", $TIME[5], $TIME[4], $TIME[3]), 'NOON', $TIME, 'MDAY', $TIME[3]};
}

foreach my $year_ (keys %H) {
	foreach my $month_ (keys %{$H{$year_}}) {
		my $href_ = $H{$year_}{$month_}{WDAY}[$WDAY][$WDAY_CNT];

		if ($href_) {
			push @OUT, "$href_->{DATE} $href_->{NOON}\n";
		}
	}
}

if (@OUT) {
	print "#\n#  DATE    PERL_TIME_AT_NOON\n#\n";
	map { print } sort @OUT;
}
