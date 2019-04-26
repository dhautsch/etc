#!/usr/bin/perl
#
# Use this as a template for a daemon
#

use Data::Dumper;
use Socket;
use Carp;
use File::Basename;
use Getopt::Long;
use strict;

my $UNAME = qx(uname); chomp $UNAME;

sub ps {
    my @ret_;
    my $cmd_ = 'ps --columns=2000 -ef 2>&1';

    if ($UNAME eq 'SunOS') {
        $ENV{COLUMNS} = 2000;
        $cmd_ = 'ps -ef 2>&1';
    }

    foreach (qx($cmd_)) {
        if (m!/usr/bin/perl\s+(\-d\s+)*$0\s+\-start!) {
            s!^\s+!!;
            push @ret_, $_;
        }
    }

    return @ret_;
}

my $HOST = qx(uname -n); chomp $HOST;
my $TOP = dirname($0);
my %OPTS;

unless ($TOP =~ m!^/!) {
    print STDERR "Use full path to invoke $0, exiting...\n";
    exit(2);
}

$OPTS{help}++ unless GetOptions(\%OPTS, 'ps', 'stop', 'restart', 'start');

$OPTS{CNT} = scalar(keys %OPTS);
$OPTS{help}++ if $OPTS{CNT} > 1;
$OPTS{help}++ unless $OPTS{CNT};

if ($OPTS{help}) {
    print STDERR "Usage: $0 (-ps|-stop|-start|-restart)\n";
    print STDERR "\t-ps  : show running process.\n";
    print STDERR "\t-stop  : stop running process.\n";
    print STDERR "\t-start : start the process.\n";
    print STDERR "\t-restart : stop and start the process.\n";
    exit(2);
}

$OPTS{stop}++ if $OPTS{restart};

$OPTS{LOG} = $ARGV[0] ? $ARGV[0] : '/dev/null';

if ($OPTS{stop} || $OPTS{ps}) {
    my @ps_ = ps();

    if (scalar(@ps_)) {
        if ($OPTS{ps}) {
            map { print STDERR "$HOST $_" } @ps_;
            exit(0);
        }

        foreach my $ps_ (@ps_) {
            my @a_ = split(/\s+/, $ps_);

            print STDERR "$HOST killng (pid=$a_[1]) $ps_";

            if (kill(15, $a_[1])) {
            }
            else {
                print STDERR "$HOST failed to kill $ps_";
                exit(1);
            }
        }

        exit(0) if $OPTS{stop} && ! $OPTS{restart};
    }
    else {
        print STDERR "$HOST $0 not running!!!\n";
        exit(0) unless $OPTS{restart};
    }
}

if (scalar(ps()) > 1) {
    print STDERR "$HOST $0 already running, exiting...\n";
    exit(0);
}

my $PID = $$;
my $RQST_ID;
my $RQST_IP;
my $RQST_PORT;
my $TS;
my $TMP;
my $RQST;
my $OUT;
my $EOL = "\015\012";
my $DOER = dirname($0) . "/doer_" . basename($0);
my $IDOER;
our ($VAR1);

eval scalar(qx($DOER));

my %PROP = %$VAR1;

unless ($PROP{HOST_ALIAS} && $PROP{LOGNAME_PAT} && $PROP{GET_PATTERN} && $PROP{PORT} =~ /^(\d+)$/) {
    print STDERR "CHECK CFG!!!\n";
    exit(2);
}

chdir($TOP) or die "Chdir $TOP : $!";

unless ($ENV{HTTP_MPSTAT_SKIP_NOHUP}) {
    my $cmd_ = "nohup $0 -start < /dev/null > $OPTS{LOG} 2>&1 &";

    print STDERR "$HOST $cmd_\n";
    $ENV{HTTP_MPSTAT_SKIP_NOHUP} = $$;
    exec($cmd_);
    exit(2);
}

sub spawn;  # forward declaration
sub rqstHandler;
sub ts;
sub logmsg;
sub REAPER;

map { unlink($_) } glob("http-$PROP{HOST_ALIAS}-*");

socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'))    || die "socket: $!";
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "setsockopt: $!";
bind(SERVER, sockaddr_in($PROP{PORT}, INADDR_ANY)) || die "bind: $!";
listen(SERVER, SOMAXCONN) || die "listen: $!";

logmsg "$0 started on port $PROP{PORT}";

my $PADDR;
use POSIX ":sys_wait_h";
use Errno;

$SIG{CHLD} = \&REAPER;

while(1) {
    $PADDR = accept(CLIENT, SERVER) || do {
        # try again if accept() returned because a signal was received
        next if $!{EINTR};
        die "accept: $!";
    };

    $TS = ts();

    my ($port_, $iaddr_) = sockaddr_in($PADDR);

    $RQST_PORT = $port_;

    $RQST_IP = inet_ntoa($iaddr_);

    $RQST_ID = gethostbyaddr($iaddr_, AF_INET);

    $RQST_ID =~ s!\..*!!; # trim off domain

    $RQST_ID = "$RQST_ID\[$TS-$RQST_IP]:$RQST_PORT";

    if ($ENV{HTTP_MPSTAT_SKIP_SPAWN}) {
	rqstHandler();
    }
    else {
	spawn \&rqstHandler;
    }

    close CLIENT;
}

sub rqstHandler {
    $|=1;

    my $httpStat_ = "404 Not Found";
    my $ct_;
    my $validRqst_;
    my $ctKey_;
    my $l_ = 0;
    my $out_;
    my $logMsg_= "$RQST_ID \042\042 $httpStat_";
    my $cnt_ = 0;
    my $authorization_;
    my $p_ = "$TOP/http-$PROP{HOST_ALIAS}-$TS-$RQST_IP-$RQST_PORT-$$";

    $RQST = "$p_-rqst";

    # open(RQST, ">$RQST") or die "Wopen $RQST : $!";
    
    {
	my $while_ = sprintf("$p_-while%02d", $cnt_);
	open(XX, ">$while_"); close XX;
	chmod(0600, $while_);
    }

    while (<CLIENT>) {
	$cnt_++;

	if ($cnt_ == 1) {
	    if (m!^(GET\s+/($PROP{GET_PATTERN}))!) {
		$validRqst_ = $1;
		$ctKey_ = $2;
		$ctKey_ = $1 if $ctKey_ =~ m!^([^/]+)!;
	    } elsif (m!^(\S+\s+\S+)!) {
		$logMsg_= "$RQST_ID \042$1\042 $httpStat_";
	    }
	}
	
	$authorization_ = $1 if m!^Authorization:\s*Basic\s*(\S+)!;

	open(RQST, ">>$RQST");
	chmod(0600, $RQST) if $cnt_ == 1;
	print RQST;
	close RQST;

	rename(sprintf("$p_-while%02d", $cnt_-1), sprintf("$p_-while%02d", $cnt_));

	last if m!^\s!;
    }

    rename(sprintf("$p_-while%02d", $cnt_), $cnt_ ? "$p_-whilezz" : "$p_-whileyy");

    # close RQST;

    if ($validRqst_) {
	if ($authorization_) {
	    $IDOER = "$p_-auth";

	    open(IDOER, ">$IDOER") or die "Wopen $IDOER : $!";
	    chmod(0600, $IDOER);
	    print IDOER Dumper({AUTH => $authorization_});
	    close IDOER;

	    $authorization_ = undef unless scalar(qx($DOER $IDOER)) =~ m!^$authorization_!;
	}

	unless ($authorization_) {
	    $httpStat_ = "401 Unauthorized";
	    $logMsg_ = "$RQST_ID \042$validRqst_\042 $httpStat_";
	}
	else {
	    $IDOER = "$p_-doer";
	    $TMP = "$p_-tmp";

	    open(IDOER, ">$IDOER") or die "Wopen $IDOER : $!";
	    chmod(0600, $IDOER);
	    print IDOER Dumper({
		GET => $validRqst_,
		PORT => $PROP{PORT},
		TMP => $TMP,
		PID => $PID});
	    close IDOER;

	    qx($DOER $IDOER);
	    if (-f $TMP) {
		$httpStat_ = "200 OK";
		$logMsg_ = "$RQST_ID \042$validRqst_\042 $httpStat_";
		$ct_ = $VAR1->{CONTENT_TYPE}{$ctKey_};

		#
		# Linux seems to not be syncing to disk properly but the following
		# causes the sync and returns the file size
		#
		foreach (qx(wc -c $TMP)) {
		    s!^\s+!!;
		    my @a_ = split;
		    $l_ = $a_[0];
		}
	    }
	}
    }

    $OUT = "$p_-out";
    open(OUT, ">$OUT") or die "Wopen $OUT : $!";
    chmod(0600, $OUT);
    print OUT "HTTP/1.1 $httpStat_$EOL";

    if ($validRqst_ && ! $authorization_) {
	print OUT "WWW-Authenticate: Basic realm=\"$PROP{BASIC_AUTH_REALM}\"$EOL";
    }

    print OUT "Server: $0$EOL"; 

    my $dt_ = qx(date -u +"Date: %a, %d %b %Y %T GMT"); chomp $dt_;
    print OUT "$dt_$EOL";
    print OUT "Connection: close$EOL";
    print OUT "Content-type: $ct_$EOL" if $ct_;
    print OUT "Content-Length: $l_$EOL$EOL";

    if ($ct_) {
	open(TMP, $TMP) or die "Ropen $TMP : $!";
	while (<TMP>) {
	    print OUT;
	}
	close TMP;
    }
    print OUT $EOL if $ct_;
    close OUT;

    open(OUT, $OUT) or die "Ropen $OUT : $!";
    while (<OUT>) {
	print CLIENT;
    }
    close OUT;

    unless (-f "$TOP/keep_http_out.txt") {
	map { unlink($_) } glob("$p_-*");

	my $t_ = time;

	foreach my $p_ (glob("http-$PROP{HOST_ALIAS}-*")
			, glob("$PROP{LOGNAME_PAT}*.err")) {
	    my @a_ = stat($p_);

	    unlink($p_) if ($t_ - $a_[9]) > 300*60;
	}

	foreach my $p_ (glob("*.tmp"), glob("*.log")) {
	    my @a_ = stat($p_);

	    unlink($p_) if ($t_ - $a_[9]) > 21*86400;
	}
    }

    logmsg $logMsg_;

    #               while ( <> ) { }; # NO OPERATION, waiting for client to close
};


sub spawn {
    my $coderef = shift;

    unless (@_ == 0 && $coderef && ref($coderef) eq 'CODE') {
        confess "usage: spawn CODEREF";
    }

    my $pid_;

    if (! defined($pid_ = fork)) {
        logmsg "cannot fork: $!";
        return;
    } 
    elsif ($pid_) {
        logmsg "begat $pid_" if $ENV{DEBUG_REAPER};
        return; # I'm the parent
    }
    # else I'm the child -- go spawn
    open(STDIN,  "<&CLIENT")   || die "can't dup client to stdin";
    open(STDOUT, ">&CLIENT")   || die "can't dup client to stdout";
    ## open(STDERR, ">&STDOUT") || die "can't dup stdout to stderr";
    exit &$coderef();
}

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

sub logmsg {
    my $ts_ = ts();

    print STDERR "$$:$ts_ @_\n";
}

sub REAPER {
    local $!;   # don't let waitpid() overwrite current error

    while ((my $pid_ = waitpid(-1,WNOHANG)) > 0 && WIFEXITED($?)) {
        logmsg "reaped $pid_" . ($? ? " with exit $?" : '') if $ENV{DEBUG_REAPER};
    }

    $SIG{CHLD} = \&REAPER;  # loathe sysV
}
