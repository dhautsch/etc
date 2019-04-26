#!/usr/bin/perl

use File::Basename;
use Data::Dumper;
use MIME::Base64;
use Getopt::Long;
use strict;

my $TOP = dirname($0);
my $PRE_WS = '^\s*';
my $TRL_WS = '\s*$';
my $TRAILING_DEC = '(\d+)$';
my $INT_PAT = "^$TRAILING_DEC";
my $EC = 0;
my $HOST = qx(uname -n); chomp $HOST;
my $HOST_ALIAS = $HOST; $HOST_ALIAS =~ s!^.*\-!!;
my $LOGNAME_PAT = "mpstat_$HOST_ALIAS";
my $TMP;
my $TMP2;

END { unlink($TMP) if $TMP && -f $TMP;
      unlink($TMP2) if $TMP2 && -f $TMP2;
      exit($EC) };

unless ($TOP =~ m!^/!) {
    $EC = 2;
}
elsif (scalar(@ARGV) < 1) {
    my %h_ = 
	(
	 CFG_FILE => "$TOP/config.properties",
	 CONTENT_TYPE => {
	     'infaps' => 'text/plain',
		 'ls' => 'text/plain',
		 'last' => 'text/plain',
		 'health' => 'text/plain',
		 'donotwatch' => 'text/plain'},
	 GET_PATTERN => 'infaps|ls|last|health/\d+|donotwatch(\?\S+)*');

    $h_{PROP_REGEX} = join('|', qw(monitor.basic_auth_realm monitor.port));
    $h_{PROP_REGEX} = qr!^($h_{PROP_REGEX})=(.*)!;

    $h_{HOST_ALIAS} = $HOST_ALIAS;
    $h_{LOGNAME_PAT} = $LOGNAME_PAT;

    open(CFG, $h_{CFG_FILE}) or die "Ropen $h_{CFG_FILE} : $!";
    while (<CFG>) {
	if (m!$h_{PROP_REGEX}!) {
	    my $k_ = $1;
	    my $v_ = $2;

	    $k_ =~ s!^.*\.!!;

	    $v_ =~ s!$PRE_WS!!;
	    $v_ =~ s!$TRL_WS!!;

	    $h_{uc($k_)} = $v_ if $v_;
	}
    }
    close CFG;

    print Dumper(\%h_);
    
    $EC = 0;
}
elsif (scalar(@ARGV) > 1) {
    $EC = 1;
}
else {
    my $VAR1 = do $ARGV[0];

    if ($VAR1->{AUTH}) {
#	my  @a_ = split(/:/, scalar(qx(echo $VAR1->{AUTH}|openssl base64 -d -A)));
	my $s_ = decode_base64($VAR1->{AUTH});

	if ($s_ =~ m!^jobo:(.*)!) {
	    $ENV{RP_USERPASS} = $1;

	    foreach (qx($TOP/jobo RP_USERPASS)) {
		print "$VAR1->{AUTH}\n" if m!^$ENV{RP_USERPASS}!;
	    }
	}
	else {
	    $ENV{RP_USERPASS_DELIM} = ':';
	    $ENV{RP_USERPASS} = $s_;

	    foreach (qx($TOP/validate_ldap_user.pl)) {
		print "$VAR1->{AUTH}\n" if m!^dn:\s+uid=!;
	    }
	}

	exit($EC);
    }

    unless ($VAR1->{GET} && $VAR1->{TMP} && $LOGNAME_PAT && $HOST && $VAR1->{PORT} && $VAR1->{PID}) {
	$EC = 3;
	exit($EC);
    }

    $TMP = $VAR1->{TMP};

    my $l_ = 0;
    my @a_;
    my $ts_ = ts();
    my $fmtLen_ = sprintf("%12.12d", $l_);

    unless (open(TMP, ">$TMP")) {
	$EC = 4;
	exit($EC);
    }

    chmod(0600, $TMP);

    if ($VAR1->{GET} =~ m!infaps|ls!) {
	my $uptime_ = qx(uptime); chomp $uptime_;

	print TMP "#\n# http_mpstat $uptime_ HTTP_PORT(PID)=$HOST:$VAR1->{PORT}($VAR1->{PID}) LEN=$fmtLen_\n#\n";
    }

    if ($VAR1->{GET} =~ m!donot!) {
	my $p_ = "../central_monitor/DONOTWATCH";

	map { print TMP } qx(cat $p_) if -f $p_;
    }
    elsif ($VAR1->{GET} =~ m!ls!) {
	map { print TMP } qx(ls -lart $TOP);
    }
    elsif ($VAR1->{GET} =~ m!last|health!) {
	my $output_;
	my $httpStatLen_ = 0;

	if ($VAR1->{GET} =~ m!$TRAILING_DEC!) {
	    $output_ = $1;
	}

	foreach (qx($TOP/infaps)) {
	    @a_ = split;

	    my $msg_ = join('@', 'infaps', $ts_, $HOST, $a_[2], $a_[3], $a_[5]) . "\n"; 
	    $httpStatLen_+=length($msg_);
	    print TMP $msg_;
	}

	my @files_ = glob("$LOGNAME_PAT*.log");

	if (scalar(@files_) > 0 && ! $output_) {
	    @files_ = ( $files_[$#files_] );
	}

	foreach (@files_) {
	    my $f_ = $_;
			
	    s!$LOGNAME_PAT.!!;
	    s!.log!!;

	    if (m!$INT_PAT!) {
		my $i_ = $1;

		if (($VAR1->{GET} =~ m!last! || $i_ > $output_)) {
		    my $errMsg_;

		    if (-f $f_) {
			$errMsg_ = qx($TOP/check_mpstat.pl $f_);
			chomp $errMsg_;

			if ($errMsg_ =~ m!^lines=(\d+),len=(\d+)!) {
			    if (open(IN, $f_)) {
				while (<IN>) {
				    print TMP;
				    $httpStatLen_+=length($_);
				}
				close IN;
			    }
			}
			else {
			    my $errFile_ = $f_;
			    
			    $errFile_ =~ s!.log!.err!;
			    
			    $errMsg_ = "garbled - $errMsg_";

			    $f_ = $errFile_ if rename($f_, $errFile_);
			}

			if ($errMsg_) {
			    $errMsg_ = "fetched\@$i_\@$HOST\@$f_\@$errMsg_\n";
			    $httpStatLen_+=length($errMsg_);
			    print TMP $errMsg_;
			}
		    }
		}
	    }
	}

	my $httpMPSTATMsg_ = join('@', 'http_mpstat', $ts_, $HOST, $VAR1->{PORT}, $VAR1->{PID}, $VAR1->{GET}, "wrote=$fmtLen_,stat=$fmtLen_") . "\n";

	$httpStatLen_ = sprintf("%12.12d", $httpStatLen_+length($httpMPSTATMsg_));
	$httpMPSTATMsg_ =~ s!$fmtLen_!$httpStatLen_!;

	print TMP $httpMPSTATMsg_;
    }
    else {
	map { print TMP } qx($TOP/infaps);
    }

    close TMP;

    #
    # Linux seems to not be syncing to disk properly but the following
    # causes the sync and returns the file size
    #
    foreach (qx(wc -c $TMP)) {
	s!^\s+!!;
	@a_ = split;
	$l_ = $a_[0];
    }


    unless (open(TMP, $TMP)) {
	$EC = 5;
	exit($EC);
    }

    $TMP2 = "$TMP~";

    unless (open(TMP2, ">$TMP2")) {
	$EC = 6;
	exit($EC);
    }

    chmod(0600, $TMP2);

    while (<TMP>) {
	if (m!^(\#\s)*http_mpstat!) {
	    my $fmtLen_ = sprintf("%12.12d", $l_);

	    s!$TRAILING_DEC!$fmtLen_!;
	}
	print TMP2;
    }

    close TMP2;
    close TMP;

    if (rename($TMP2, $TMP)) {
	$TMP = undef;
    }

    $EC = 0;
}

exit($EC);

sub ts {
    my $ts_ = shift || time;

    if ($ts_) {
        my @t_ = localtime($ts_); 
        $ts_ = sprintf("%d%2.2d%2.2d%2.2d%2.2d%2.2d", $t_[5]+1900,$t_[4]+1,$t_[3],$t_[2], $t_[1], $t_[0]);
    }
    else {
        $ts_ = undef;
    }

    return $ts_;
}
