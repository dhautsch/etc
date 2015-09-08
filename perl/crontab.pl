#!/usr/bin/perl

use Time::Piece;
use Data::Dumper;
use strict;

#
# Crontab file format is
#
# MIN HR MONTH_DAY MONTH DAY_OF_WEEK CRON...
# 0 is Sunday for DAY_OF_WEEK
# Each element can be * or range (1-2) or comma delimited ( 1,2,3-4,5 ) #
#04 13-16 * * 01-03 true 4 hello world
#05 13 * * 01 true hello 5 world
#06 16 * * 03 true hello 6 world
#*  18 *  7 4 true *  18 *  7 4
#25 18 30 * * true 25 18 30 * *
#

my %CRONTAB;
my $COMMENT_REGEX = '\#.*$';
my $EMPTY_REGEX = '^\s*$';

if (0) {
my $t1 = localtime;
my $t2 = localtime(time + 7*86400);
my $s = $t2 - $t1;
print $t1->datetime, "\n";
print $t2->datetime, "\n";
print $t2->day_of_week, "\n";
print $t1->mon, "\n";
print "Difference is: ", $s->days, "\n"; }

$Data::Dumper::Sortkeys++;

while (<>) {
    s!$COMMENT_REGEX!!;
    next if m!$EMPTY_REGEX!;

    my @cron_ = split;
    next if @cron_ < 6;

    my $minutes_ = cron_range_populate (59, $cron_[0]);
    my $hours_   = cron_range_populate (23, $cron_[1]);
    my $monthDays_ = cron_range_populate (31, $cron_[2], 1);
    my $months_ = cron_range_populate (12, $cron_[3], 1);
    my $days_    = cron_range_populate ( 6, $cron_[4]);

    if ($minutes_ && $hours_ && $monthDays_ && $months_ && $days_) {
	@cron_ = @cron_[5..$#cron_];
	my $cron_ = "@cron_";

	foreach my $min_ (@$minutes_) {
	    foreach my $hr_ (@$hours_) {
		foreach my $monthDay_ (@$monthDays_) {
		    foreach my $month_ (@$months_) {
			foreach my $day_ (@$days_) {
			    push @{$CRONTAB{$min_}{$hr_}{$monthDay_}{$month_-1}{$day_}}, \$cron_;
			}
		    }
		}
	    }
	}
    }
}

if (scalar(keys %CRONTAB) > 0 && chdir("/usr/tmp")) {

    print Dumper(\%CRONTAB) if $ENV{CRONTAB_DEBUG};

    while (1) {
	my $time_ = time;

	$time_ = 60 - (($time_ % 60) - 30);
	sleep($time_);

	$time_ = time;
	my @time_ = localtime($time_);
	my $displayTime_ = localtime($time_);

	my $cron_ = $CRONTAB{$time_[1]}{$time_[2]}{$time_[3]}{$time_[4]}{$time_[6]};

	if ($cron_) {
	    foreach my $task_ (@$cron_) {
		my $cmd_ = $$task_;

		unless ($cmd_ =~ m!>!) {
		    $cmd_ = "$cmd_ >/dev/null 2>&1";
		}

		unless ($cmd_ =~ m!2>&1!) {
		    $cmd_ = "$cmd_ 2>&1";
		}

		$cmd_ = "nohup $cmd_ &";
		print "$displayTime_ \$CRONTAB\{$time_[1]\}\{$time_[2]\}\{$time_[3]\}\{$time_[4]\}\{$time_[6]\} $cmd_\n" if $ENV{CRONTAB_DEBUG};
		qx($cmd_);
	    }
	}
    }
}


exit(0);

sub btwn {
    return $_[1] <= $_[0] && $_[0] <= $_[2]; }

sub cron_range_populate    {
    my ($max, $range, $min) = @_;
    my @range = ();

    $min = 0 unless ($min == 0 || $min == 1);
    if ($range eq '*') { return \@{[$min..$max]}; }
    elsif ($range !~ /[-,]/) { push @range, int($range); }
    else    {
        my @mini = split /,/, $range;
        for (@mini)    {
            return undef if /-.*-/;    # 1 dash per subsection, e.g., "2-6-9, 24" is invalid
            if ( !/-/ )    { push @range, $_; }
            else    {
                return undef unless /(\d+)-(\d+)/;
                return undef unless $1 < $2;
                push @range, (int($1)..int($2));

            }
        }
    }
    return undef if $#range == -1;
    for (@range) { return undef unless ($_ >= $min && $_ <= $max); }
    return \@range;
}
