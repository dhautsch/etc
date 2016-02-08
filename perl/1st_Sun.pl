#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use strict;

my $TIME = time;
my $DAY = 86400;
my @TIME = localtime(time);
my %H;
my %WDAY = (Sun => 0, Mon => 1, Tue => 2, Wed => 3, Thur => 4, Fri => 5, Sat => 6);
my $WDAY;
my $PAT = '((1st|2nd|3rd|4th|5th|6th)_)*(Sun|Mon|Tue|Wed|Thur|Fri|Sat)';
my $WDAY_CNT;
my %OPTS;
my @OUT;
my $EXIT = 1;

if (GetOptions(\%OPTS, 'test') && @ARGV == 1 && $ARGV[0] =~ m!$PAT!) {
	my $day_ = $3;
	my $wk_ = $2 ? $2 : 0;
	$WDAY_CNT = substr($wk_, 0, 1);
	$WDAY = $WDAY{$day_};
	$WDAY_CNT--;
}
else {
	print "Usage: $0 [-test] $PAT\n";
	print "\t-test : test if today matches $PAT\n";
	exit(1);
}

$OPTS{test} = sprintf("%04d-%02d-%02d", $TIME[5] + 1900, $TIME[4] + 1, $TIME[3]) if $OPTS{test};

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
		my @a_ = @{$H{$year_}{$month_}{WDAY}[$WDAY]};

		if ($WDAY_CNT > -1) {
			my $href_ = $a_[$WDAY_CNT];

			if ($href_) {
				@a_ = ($a_[$WDAY_CNT]);
			}
			else {
				@a_ = ();
			}
		}

		foreach (@a_) {
			if ($OPTS{test}) {
				if ($OPTS{test} eq $_->{DATE}) {
					push @OUT, "$_->{DATE} $_->{NOON}\n";
					last;
				}
			}
			else {
				push @OUT, "$_->{DATE} $_->{NOON}\n";
			}
		}
	}
}

if (@OUT) {
	print "#\n#  DATE    PERL_TIME_AT_NOON\n#\n";
	map { print } sort @OUT;
	$EXIT = 0;
}

exit($EXIT);
