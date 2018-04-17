#!/usr/bin/perl

use Fcntl qw(:flock SEEK_SET);
use File::Basename;
use strict;

my $TOP = dirname($0); $TOP = qx(cd $TOP && pwd); chomp $TOP;
my $BNAME = basename($0); 
my $DAT = "$TOP/$BNAME.dat";
my $LOCK = "$TOP/$BNAME.lck";
my $TMP = "$TOP/$$-$BNAME.tmp";
my $TIME = time;
my $TIME_TO_UPDATE = 60;

END { unlink($TMP) };

sub utcZStr {
  my $t_ = shift || time;
  my @t_ = gmtime($t_);

  return sprintf("%4d-%02d-%02dT%02d:%02d:%02dZ", $t_[5]+1900, $t_[4]+1, $t_[3], $t_[2], $t_[1], $t_[0]);
}
  
sub debugMsg {
	print STDERR utcZStr() . " $s_\n"
}

sub myFileLock {
	my $dat_ = shift;
	my $lck_ = shift;
	my $ret_ = undef;

  open(my $fh_, ">$lck_") or die "Wopen $lck_ : $!";
	debugMsg("REQUESTING LOCK");
  flock($fh_, LOCK_EX) or die "Flock $lck_ : $!";
	debugMsg("GOT LOCK");
	seek($fh_, 0, SEEK_SET) or die "Cannot seek - $!";
	print $fh_ "$$\n";

	if (-f $dat_) {
		my @stat_ = stat($dat_);
		my $t_ = $TIME - $TIME_TO_UPDATE;

		if ($stat_[9] < $t_) {
			$ret_ = $fh_;
		}
		else {
			debugMsg("USE CACHED $DAT");
			close($fh_);
		}
	}
	else {
		$ret_ = $fh_;
	}

	return $ret_;
}

sub myFileUnlock {
        my ($fh_) = @_;

        if ($fh_) {
                flock($fh_, LOCK_UN) or die "Cannot unlock - $!";
                close($fh_);
        }
}

$LOCK = myFileLock($DAT, $LOCK);

if ($LOCK) {
	my $sleep_ = 15;
	debugMsg("SLEEPING($sleep_)...");
	sleep($sleep_);
	my $s_ = utcZStr() . " Hello world $$\n";
	open(TMP, ">$TMP") or die "Wopen $TMP : $!";
	print TMP $s_;
	close(TMP);
	debugMsg("UPDATED FILE $DAT\n\t$s_");
	rename($TMP, $DAT);
	myFileUnlock($LOCK);
}
else {
	open(DAT, $DAT);
	while (<DAT>) {
		print "\t$_";
	}	
	close(DAT);
}
