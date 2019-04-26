#!/usr/bin/perl

use Data::Dumper;
use File::Basename;
use strict;
my $LEAD_WS = '^\s*';
my $TRL_WS = '\s*$';
my $LINE_CNT = 0;
my $CHAR_CNT = 0;
my $OUT_MSG = "bad init";
my @SCRIPT_LIST = qw(PHealthMon.ksh Static.ksh RunTop.ksh df gather_stats.pl);
my %SCRIPT_OUT_COLS = qw(PHealthMon.ksh 5 Static.ksh 5 RunTop.ksh 6 df 5 gather_stats.pl 8);
my $START_STOP_PAT = '(START|STOP)-(' . join('|', @SCRIPT_LIST) . ')';

if ($ARGV[0] eq 'META') {
    
    print Dumper({ SCRIPT_LIST => \@SCRIPT_LIST, SCRIPT_OUT_COLS => \%SCRIPT_OUT_COLS });
    exit(0);
}

while (<>) {
    my %h_ = checkMPStatLine($_);

    if ($h_{OK}) {
        $LINE_CNT++;
        $CHAR_CNT+=length($_);
    }
    else {
        $OUT_MSG = $h_{FAIL};
        $LINE_CNT = 0;
        $CHAR_CNT = 0;
        last;
    }
}

$OUT_MSG = "lines=$LINE_CNT,len=$CHAR_CNT" if $LINE_CNT;

print "$OUT_MSG\n";
exit($LINE_CNT ? 0 : 1);

sub checkMPStatLine {
    my $s_ = shift;
    my $chompCnt_ = chomp $s_;
    my %ret_;

    if (defined($s_)) {
        my $len_ = length($s_);
        
        if ($len_) {
            $ret_{OK} = $len_;

            if ($chompCnt_ == 1) {
                my @a_ = split(/\@/, $s_);

                unless ($a_[0] eq 'http_mpstat' && scalar(@a_) == 7
                        && ($a_[6] =~ m!wrote=(\d+),stat=(\d+)! && int($1) == int($2)
                            || $a_[6] =~ m!wrote=(\d+),aliasAdj=(\d+),stat=(\d+)! && abs(int($1) - int($3)) == int($2))
                        || ($a_[1] eq 'PROG' || $a_[1] eq 'STDERR' || scalar(@a_) == 6)
                        || $a_[0] eq 'infaps' && scalar(@a_) == 6
                        || $a_[0] =~ m!$START_STOP_PAT! && scalar(@a_) == 3
                        || $SCRIPT_OUT_COLS{$a_[0]} && scalar(@a_) == $SCRIPT_OUT_COLS{$a_[0]}
                        || $a_[0] eq 'fetched' && scalar(@a_) == 5
                        || $a_[0] eq 'curl_mpstat' && scalar(@a_) == 6
                        || $s_ =~ m!^curl_mpstat\s+(PROG|STDERR)!) {
                    %ret_ = ( FAIL => "badly formed");
                }
            }
            else {
                %ret_ = ( FAIL => "missing newline");
            }
        }
        else {
            %ret_ = ( FAIL => "zero len");
        }
    }
    else {
        %ret_ = ( FAIL => "is undef");
    }

    return %ret_;
}
