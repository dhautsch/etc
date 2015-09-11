#!/usr/bin/perl

use File::Basename;
use Time::Piece;
use Data::Dumper;
use strict;

#
# Crontab file format is
#
# MIN HR MONTH_DAY MONTH DAY_OF_WEEK CRON...
# 0 is Sunday for DAY_OF_WEEK
# Each element can be * or range (1-2) or comma delimited ( 1,2,3-4,5 )
#
#04 13-16 * * 01-03 /bin/true
#05 13 * * 01 /bin/true
#06 16 * * 03 /bin/true
#*  18 *  7 4 /bin/true
#25 18 30 * * /bin/true
#

my $PS = 'ps --columns 255 aux';
my $SLEEP = 15;
my $SCRIPT = dirname($0); $SCRIPT = qx(cd $SCRIPT && pwd); chomp $SCRIPT; $SCRIPT = "$SCRIPT/" . basename($0);
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
print "Difference is: ", $s->days, "\n";
}

$Data::Dumper::Sortkeys++;

unless (@ARGV == 1) {
	my @crontab_ = fileparse($SCRIPT, qw(.pl));

	$crontab_[0] = "$crontab_[1]$crontab_[0].txt";

	if (-f $crontab_[0]) {
		push @ARGV, $crontab_[0];
	}
	else {
		print STDERR "Cannot find crontab file !!!\n";
		exit(2);
	}
}

$ENV{CRONTAB_PID} = getPid($SCRIPT);

unless ($ENV{CRONTAB_PID}) {
	my $cmd_ = "nohup $SCRIPT @ARGV > /dev/null 2>&1 &";

	print STDERR "$cmd_\n";
	qx($cmd_);
	print STDERR "Sleep $SLEEP...\n";
	sleep($SLEEP);
	$ENV{CRONTAB_PID} = getPid($SCRIPT);
	print STDERR "CRONTAB_PID=$ENV{CRONTAB_PID}\n";
	exit($ENV{CRONTAB_PID} ? 0 : 1);
}

while (<>) {
	s!$COMMENT_REGEX!!;
	next if m!$EMPTY_REGEX!;

	my @cron_ = split;

	unless (@cron_ == 6 && -x $cron_[5]) {
		print STDERR "Skipping $_";
	}

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
#							push @{$CRONTAB{$min_}{$hr_}{$monthDay_}{$month_-1}{$day_}}, \$cron_;
							my $x_ = $month_-1;
							push @{$CRONTAB{"$min_,$hr_,$monthDay_,$x_,$day_"}}, \$cron_;
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
		$cron_ = $CRONTAB{"$time_[1],$time_[2],$time_[3],$time_[4],$time_[6]"};

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
				print "$displayTime_ \$CRONTAB\{MIN=$time_[1]\}\{HR=$time_[2]\}\{MONTH_DAY=$time_[3]\}\{MONTH=$time_[4]\}\{DAY_OF_WEEK=$time_[6]\} $cmd_\n" if $ENV{CRONTAB_DEBUG};
				qx($cmd_);
			}
		}
	}
}


exit(0);

sub btwn {
	return $_[1] <= $_[0] && $_[0] <= $_[2];
}

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

sub getPid {
	my $pat_ = shift;
	my @a_;

	if ($pat_) {
		foreach my $qx_ (qx(ps --columns 255 aux)) {
			@a_ = split(/\s+/, $qx_) if $qx_ =~ m!$pat_!;
		}
	}

	return $a_[1];
}
