#!/usr/bin/perl
# How to Calculate Trendline
# http://classroom.synonym.com/calculate-trendline-2709.html
# Zero slope is flat. Postitive is up. Negative is down.
#
use strict;

my @XY = ( 1, 3, 2, 5, 3, 6.5);

sub slope {
        my @a_ = @_;
        my $l_ = scalar(@a_);
        my @ret_ = ();

        if ($l_ > 0 || $l_ % 2 == 0) {
                my $i_ = 0;
                my $a_ = 0;
                my $sumX_ = 0;
                my $b_ = 0;
                my $c_ = 0;
                my $d_ = 0;
                my $e_ = 0;
                my $f_ = 0;
                my $m_ = 0;
                my $n_ = $l_/2;
                my $yi_ = 0;

                while ($i_ < $l_) {
                        $a_ += $a_[$i_]*$a_[$i_+1];
                        $c_ += $a_[$i_]*$a_[$i_];
                        $sumX_ += $a_[$i_];
                        $e_ += $a_[$i_+1];
                        $i_+=2;
                }

                $a_ = $a_ * $n_;
                $c_ = $c_ * $n_;
                $b_ = $sumX_ * $e_;
                $d_ = $sumX_ * $sumX_;

                $m_ = ($a_ - $b_)/($c_ - $d_);
                $f_ = $sumX_ * $m_;
                $yi_ = ($e_ - $f_)/$n_;

                push @ret_, $m_, $yi_;
        }

        return @ret_;
}

@XY = slope(@XY);
print "SLOPE:$XY[0] Y-INTERCEPT:$XY[1]\n";
