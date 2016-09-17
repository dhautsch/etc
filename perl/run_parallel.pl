#!/usr/bin/perl

use File::Basename;
use Getopt::Long;
use lib "$ENV{HOME}/etlsupp/lib/perl";
use Fargs;
use strict;
my $DIR_TO_REMOVE;
my $CMD_LIST;
my $PROG_BNAME = basename($0);
our $VAR1;
my $TIME = time;
my %OPTS;

END { qx(rm -rf $DIR_TO_REMOVE) if $DIR_TO_REMOVE && -d $DIR_TO_REMOVE };

$OPTS{help}++ unless GetOptions(\%OPTS, qw(help tmpdir=s parallelism=i));
$OPTS{help}++ unless @ARGV;

if ($OPTS{help}) {
	print STDERR "Usage : $0 [-tmpdir TMP_DIR -parallelism INT] cmd0 .. cmdN\n";
	print STDERR "\tRun commands in parallel\n";
	print STDERR "\t-tmpdir TMP_DIR : use TMP_DIR to create working folder, default to /tmp.\n";
	print STDERR "\t-parallelism INT : set parallelism, default to 20.\n";
	exit(1);
}

$OPTS{tmpdir} = '/tmp' unless $OPTS{tmpdir};
$OPTS{parallelism} = 20 unless $OPTS{parallelism};

$OPTS{tmpdir} = "$OPTS{tmpdir}/dir-$$-" . basename($0);

mkdir($OPTS{tmpdir}) or die "Mkdir $OPTS{tmpdir} : $!";

foreach my $cmd_ (@ARGV) {
	unless (-x $cmd_) {
		print STDERR "File $cmd_ is not executable!!!\n";
		exit(1);
	}
}

$CMD_LIST = [@ARGV];

my $FARGS = Fargs->new( {
	command => sub {
		my $p_ = shift;
		my $bname_ = basename($p_);
		my $rand_ = int(rand(1000));
		my $tmp_ = "$OPTS{tmpdir}/output-$rand_-$TIME-$bname_.tmp";

		chdir($OPTS{tmpdir});

		qx($p_ > $tmp_ 2>&1);

		my $ec_ = $? >> 8;

		qx(echo $ec_ > $OPTS{tmpdir}/exit-$rand_.txt);

		my $t_ = time - $TIME;

		rename($tmp_, "$OPTS{tmpdir}/output-$rand_-$t_-$bname_.txt");
	},
	n => $OPTS{parallelism},
	input => $CMD_LIST
} ) or die "Unable to create new Fargs object";

$FARGS->run;

foreach my $p_ (glob("$OPTS{tmpdir}/output-*.txt")) {
	$p_ =~ m!$OPTS{tmpdir}/output\-(\d+)\-(\d+)\-(\S+)\.txt!;

	my $rand_ = $1;
	my $t_ = $2;
	my $bname_ = $3;
	my $exitFile_ = "$OPTS{tmpdir}/exit-$rand_.txt";

	open(IN, $p_) or die "Ropen $p_ : $!";
	while (<IN>) {
		print "$PROG_BNAME $bname_ $_";
	}
	close IN;

	open(IN, $exitFile_) or die "Ropen $exitFile_ : $!";
	while (<IN>) {
		chomp;
		print "$PROG_BNAME $bname_ EXIT $_.\n";
	}
	close IN;

	print "$PROG_BNAME $bname_ ELAPSED $t_ SECONDS.\n";
}

$DIR_TO_REMOVE = $OPTS{tmpdir};

exit(0);
