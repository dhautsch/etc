#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use strict;

my $TIME = time;
my $DAY = 86400;
my @TIME = localtime($TIME);
my %H;
my %WDAY = (Sun => 0, Mon => 1, Tue => 2, Wed => 3, Thr => 4, Fri => 5, Sat => 6);
my $WDAY;
my $PAT = '((1st|2nd|3rd|4th|5th|6th)_)*(Sun|Mon|Tue|Wed|Thr|Fri|Sat)';
my $WDAY_CNT;
my %OPTS;
my @OUT;
my $EXIT = 1;

if (GetOptions(\%OPTS, 'help', 'test', 'last', 'next') && @ARGV == 1 && $ARGV[0] =~ m!$PAT!) {
	my $day_ = $3;
	my $wk_ = $2 ? $2 : 0;
	$WDAY_CNT = substr($wk_, 0, 1);
	$WDAY = $WDAY{$day_};
	$WDAY_CNT--;

	my $flgCnt_ = 0;

	foreach my $flg_ (qw(test last next)) {
		if ($OPTS{$flg_}) {
			$OPTS{$flg_} = sprintf("%04d-%02d-%02d", $TIME[5] + 1900, $TIME[4] + 1, $TIME[3]);
			$flgCnt_++;
		}
	}

	$OPTS{help}++ if $flgCnt_ > 1;
}
else {
	$OPTS{help}++;
}


if ($OPTS{help}) {
	print "Usage: $0 [-test|-last|-next] $PAT\n";
	print "\t-test : test if today matches $PAT\n";
	print "\t-last : return last $PAT\n";
	print "\t-next : return next $PAT\n";
	exit($EXIT);
}

# Substract out seconds
$TIME -= $TIME[0];
# Subtract out minutes
$TIME -= ($TIME[1]*60);
# Normalize for gmt noon
$TIME = int($TIME/$DAY)*$DAY+$DAY/2;
# Subtract out 365 days
$TIME -= 365*$DAY;

#print scalar(gmtime($TIME)), " ", scalar(localtime($TIME)), "\n";

$Data::Dumper::Sortkeys++;

foreach my $i_ (1..730) {
	$TIME += $DAY;

	@TIME = localtime($TIME);
	$TIME[5] += 1900;
	$TIME[4] = sprintf("%02d", $TIME[4] + 1);
	$TIME[3] = sprintf("%02d", $TIME[3]);

	push @{$H{$TIME[5]}{$TIME[4]}{WDAY}[$TIME[6]]}, {'DATE', sprintf("%04d-%s-%s", $TIME[5], $TIME[4], $TIME[3]), 'NOON', $TIME, 'MDAY', $TIME[3]};
}

foreach my $year_ (sort keys %H) {
	foreach my $month_ (sort keys %{$H{$year_}}) {
		my @a_ = @{$H{$year_}{$month_}{WDAY}[$WDAY] ? $H{$year_}{$month_}{WDAY}[$WDAY] : []};

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
			elsif ($OPTS{next}) {
				if ($OPTS{next} lt $_->{DATE}) {
					push @OUT, "$_->{DATE} $_->{NOON}\n";
				}
			}
			elsif ($OPTS{last}) {
				if ($OPTS{last} gt $_->{DATE}) {
					push @OUT, "$_->{DATE} $_->{NOON}\n";
				}
			}
			else {
				push @OUT, "$_->{DATE} $_->{NOON}\n";
			}
		}
	}
}

if (@OUT) {
	if ($OPTS{last}) {
		@OUT = ($OUT[$#OUT]);
	}
	elsif ($OPTS{next}) {
		@OUT = ($OUT[0]);
	}
	print "#\n#  DATE    NIX_TIME_AT_NOON_GMT\n#\n" if scalar(@OUT) > 1;
	map { print } sort @OUT;
	$EXIT = 0;
}

exit($EXIT);
