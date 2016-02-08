#!/usr/bin/perl

use Time::Local;
use File::Basename;
use strict;
my $SP_CMD = "$ENV{HOME}/etlsupp/bin/get_sp_list_items.pl";
my $SP_UPDT = 0;
my $SP_ITEM_CNT = -1;
my $CMP_UPDT = 0;
my $EXIT = 1;

unless (scalar(@ARGV == 3)) {
	print STDERR "Usage: $0 URL LIST_TITLE FILE\n";
	print STDERR "\tUpdate file from SharePoint if older than list time stamps\n";
	exit($EXIT);
}

if (-f $ARGV[2]) {
	unless (-w $ARGV[2]) {
		print STDERR "File $ARGV[2] is not writable!!!\n";
		exit($EXIT);
	}

	my @stat_ = stat($ARGV[2]);

	$CMP_UPDT = $stat_[9];
}


foreach (qx($SP_CMD -meta @ARGV[0..1])) {
	if (m!d:(Created|LastItemDeletedDate|LastItemModifiedDate)\047\s+=>\s+\047([^\047]+)!) {
		my $ts_ = $2;

		if ($ts_ =~ m!^\[*(\d+)[\.\-](\d+)[\.\-](\d+)[\ T:](\d+)[\.\:](\d+)[\.\:](\d+)Z!) {
			my $t_ = timegm($6, $5, $4, $3, $2-1, $1);

			$SP_UPDT = $t_ if $t_ > $SP_UPDT;
		}
	}

	if (m!d:ItemCount\047\s*=>\s*\047(\d+)!) {
		$SP_ITEM_CNT = $1;
	}
}

unless ($SP_UPDT) {
	print STDERR "Cannot get timestamps from SP @ARGV[0..1]!!!\n";
	exit($EXIT);
}

if ($SP_ITEM_CNT < 0) {
	print STDERR "Cannot get item count from SP @ARGV[0..1]!!!\n";
	exit($EXIT);
}

if ($SP_UPDT > $CMP_UPDT) {
	my $tmp_ = dirname($ARGV[2]) . "/$$-" . basename($ARGV[2]);

	open(FILE, ">$tmp_") or die "Wopen $tmp_ failed : $!";

	foreach (qx($SP_CMD -query '\$top=$SP_ITEM_CNT' @ARGV[0..1])) {
		$EXIT = 0 if m!\$VAR1!;

		print FILE;
	}
	close(FILE);

	rename($tmp_, $ARGV[2]) or die "Rename $tmp_ to $ARGV[2] failed : $!";
}
elsif ($CMP_UPDT) {
	$EXIT = 0;
}

exit($EXIT);
