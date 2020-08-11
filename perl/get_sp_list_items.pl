#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use File::Basename;
use sigtrap qw/handler normal_signal_handler normal-signals/;
use FindBin;
use lib "$FindBin::Bin/lib/perl";
use JSON;
use strict;

my %PROPS;
my $WHOAMI = qx(whoami); chomp $WHOAMI;
my $SHAREPOINT_CONN_PROP = 'sharepoint_conn';
my $SHAREPOINT_URL_PROP = 'sharepoint.url';
my $PROXY_PROP = 'proxy.url';
my $PROXY_AUTH_REQ_PROP = 'proxy.auth.required';
my $TRAILING_WS = '\s*$';
my $SCRIPT_DIR = dirname($0); $SCRIPT_DIR = qx(cd $SCRIPT_DIR && pwd); chomp $SCRIPT_DIR;
my $TMP_DIR;
my $GET_LIST_RESPONSE;
my $GET_DIGEST_RESPONSE;
my $CURL_OUT;
my $CURL_CNT = 0;
my %OPTS;
my $DECRYPT = "$SCRIPT_DIR/decrypt";
my $SP_DIGEST = "/tmp/$WHOAMI-sp_digest.json";
my @DIGEST_KEYS = qw(
    SHAREPOINT_CONN_COOKIE
    SHAREPOINT_CONN_EXPIRES
    SHAREPOINT_CONN_ENCRYPTED
    SHAREPOINT_CONN_FORM_DIGEST_VALUE
    SHAREPOINT_CONN_FORM_DIGEST_TIMEOUT
    SHAREPOINT_HOST
    SHAREPOINT_PROXY_SITE
    SHAREPOINT_SITE
    );
my $DIGEST_KEYS_PAT = join('|', @DIGEST_KEYS);
my $SP_DIGEST_OBJ;
my $DEBUG_SP_LI;
my @CONFIG_FILES = ( "$SCRIPT_DIR/config.properties" , "$ENV{HOME}/config.properties" );
my $TIME = time;
my $EXIT = 1;
my $VAR1;

sub normal_signal_handler { qx(/bin/rm -rf $TMP_DIR) if -d $TMP_DIR && ! ( $OPTS{keeptmp} || $OPTS{usetmp} ) };

END { normal_signal_handler(); exit($EXIT) };

$OPTS{help}++ unless GetOptions(\%OPTS, qw(usetmp=s keeptmp help xml json digest create update delete versions getuserbyid data=s id=i meta verbose query=s example));

unless ($OPTS{help}) {
    my $i_ = 0;

    if ($OPTS{example}) {
	while (<DATA>) {
	    print;
	}
	exit($EXIT = 0);
    }

    foreach my $opt_ (qw(digest meta create update delete versions getuserbyid)) {
        $i_++ if $OPTS{$opt_};
    }

    unless ($OPTS{help} || $i_ > 1) {
    }

    if ($i_ > 1) {
        $OPTS{help}++;
    }
    elsif ($i_ < 1) { # get list items
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
    }
    elsif ($OPTS{create}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ unless $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }
    elsif ($OPTS{update}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ unless $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }
    elsif ($OPTS{delete}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }
    elsif ($OPTS{versions}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }
    elsif ($OPTS{meta}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }
    elsif ($OPTS{digest}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ if $OPTS{json};
        $OPTS{help}++ if $OPTS{xml};
    }
    elsif ($OPTS{getuserbyid}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
    }

    unless ($OPTS{help}) {
        unshift @CONFIG_FILES, $ENV{CONFIG_PROPS} if $ENV{CONFIG_PROPS};

	foreach my $config_ (@CONFIG_FILES) {
	    if (open(CFG, $config_)) {
		while (<CFG>) {
		    if (m!^($SHAREPOINT_CONN_PROP)=(\S+)!) {
			$PROPS{SHAREPOINT_CONN_ENCRYPTED} = $2;
		    }
		    elsif (m!^($SHAREPOINT_URL_PROP)=(\S+)!) {
			$PROPS{SHAREPOINT_SITE} = $2;
		    }
		    elsif (m!^($PROXY_PROP)=(\S+)!) {
			$PROPS{SHAREPOINT_PROXY_SITE} = $2;
		    }
		    elsif (m!^($PROXY_AUTH_REQ_PROP)=(\S+)!) {
			$PROPS{SHAREPOINT_PROXY_AUTH_REQ} = $2;
		    }
		}
		close CFG;

		last;
	    }
	}

	if (-r $SP_DIGEST) {
	    my $json_;
	    $json_ = qx(cat $SP_DIGEST);
	    $VAR1 = JSON->new->allow_nonref->decode($json_);
	
	    if ($VAR1->{SHAREPOINT_CONN_FORM_DIGEST_TIMEOUT} > $TIME) {
		$VAR1->{COMMENT} = "REUSED $SP_DIGEST " . scalar(qx(ls -l $SP_DIGEST));

		foreach (keys %$VAR1) {
		    $PROPS{$_} = $VAR1->{$_} if $VAR1->{$_} && m!^($DIGEST_KEYS_PAT)!;
		}

		$SP_DIGEST_OBJ = $VAR1;
	    }
	}

    }

    foreach (qw(SHAREPOINT_SITE)) {
	if ($OPTS{digest} || $OPTS{getuserbyid}) {
	    if (scalar(@ARGV) == 1) {
		$ENV{$_} = $ARGV[0];
	    }
	    elsif (scalar(@ARGV) == 0) {
		$ENV{$_} = $PROPS{$_} if $PROPS{$_} && ! $ENV{$_};
	    }
	    else {
		$OPTS{help}++;
	    }
	}
	elsif (scalar(@ARGV) == 2) {
	    $ENV{$_} = $ARGV[1];
	}
	elsif (scalar(@ARGV) == 1) {
	    $ENV{$_} = $PROPS{$_} if $PROPS{$_} && ! $ENV{$_};
	}
	else {
	    $OPTS{help}++;
	}

	if ($ENV{$_} =~ m!https*://([^:/]+)!) {
	    $ENV{SHAREPOINT_HOST} = $1;
	}
	else {
	    print STDERR "FAIL - CANNOT DETERMINE $_\n";
	    $OPTS{help}++;
	}

    }

    unless ($OPTS{help}) {
	foreach (@DIGEST_KEYS) {
	    $ENV{$_} = $PROPS{$_} if $PROPS{$_} && ! $ENV{$_};
	}
    }

}

if ($OPTS{help}) {
    print STDERR "Usage :\n";
    print STDERR "\t$0 -help : print this message.\n";
    print STDERR "\t$0 -example : show example code.\n";
    print STDERR "\t$0 [-verbose -xml|-json] -meta <LIST_TITLE> [<SP_SITE>]: get list metadata instead of items.\n";
    print STDERR "\t$0 [-verbose -xml|-json  -query <QUERY>] <LIST_TITLE> [<SP_SITE>] : get list items.\n";
    print STDERR "\t$0 [-verbose -xml|-json] -create -data <DATA> <LIST_TITLE> [<SP_SITE>]\n";
    print STDERR "\t$0 [-verbose -xml|-json] -update -id <ID> -data <DATA> <LIST_TITLE> [<SP_SITE>]\n";
    print STDERR "\t$0 [-verbose -xml|-json] -delete -id <ID> <LIST_TITLE> [<SP_SITE>]\n";
    print STDERR "\t$0 [-verbose -xml|-json] -versions -id <ID> <LIST_TITLE> [<SP_SITE>]\n";
    print STDERR "\t$0 [-verbose] -digest <URL> : get digest.\n";
    print STDERR "\t$0 [-verbose] -getuserbyid -id <ID> <URL> : get user.\n";
    print STDERR "\t-verbose : print curl output to STDERR.\n";
    print STDERR "\t-query <QUERY> : GET query parameter.\n";
    print STDERR "\t-xml : output xml.\n";
    print STDERR "\t-json : output json.\n";
    print STDERR "\t-data <DATA> : required for -create and -update.\n";
    print STDERR "\t\tData can be a JSON struct or a file containing JSON.\n";
    print STDERR "\t\tIf using a file then supply the \@path, that is a @\n";
    print STDERR "\t\tbefore the filename. See curl man page.\n";
    print STDERR "\t-id <ID> : Integer required for -delete -update and -getuserbyid.\n";
    print STDERR "\t<SP_SITE> : Optional if ENV{SHAREPOINT_SITE} set.\n";
    exit($EXIT);
}

$TMP_DIR = $OPTS{usetmp} || sprintf("/tmp/%d-%d-%s", time, $$, $WHOAMI);
$GET_LIST_RESPONSE = "$TMP_DIR/GetListResponse.txt";
$GET_DIGEST_RESPONSE = "$TMP_DIR/GetDigestResponse.txt";

$DEBUG_SP_LI = JSON->new->allow_nonref->decode($ENV{DEBUG_SP_LI}) if $ENV{DEBUG_SP_LI};

$Data::Dumper::Sortkeys++;

if ($OPTS{digest}) {
    if ($SP_DIGEST_OBJ) {
	print Dumper($SP_DIGEST_OBJ);
	exit($EXIT = 0);
    }

    unlink ($SP_DIGEST);

    delete $ENV{SHAREPOINT_CONN_COOKIE};
    delete $ENV{SHAREPOINT_CONN_FORM_DIGEST_VALUE};
}
else {
    $VAR1 = qx($0 -digest $ENV{SHAREPOINT_SITE});
    eval $VAR1;

    if ($VAR1) {
	foreach (@DIGEST_KEYS) {
	    $ENV{$_} = $VAR1->{$_} if $VAR1->{$_} && ! $ENV{$_};
	}

	if ($DEBUG_SP_LI) {
	    print STDERR "#\n# Dumping MAPS\n#\n";
	    print Dumper({ ENV => \%ENV, DIGEST => $VAR1, OPTS => \%OPTS, PROPS => \%PROPS });
	}
    }
}

my $URL = swizzleForHTTP($ENV{SHAREPOINT_SITE});

if ($OPTS{getuserbyid}) {
    $URL .= swizzleForHTTP("/_api/web/GetUserById($OPTS{id})");
}
elsif ($OPTS{versions}) {
    $URL .= swizzleForHTTP("/_api/web/Lists/getbytitle('$ARGV[0]')/items($OPTS{id})/versions");
}
else {
    $URL .= swizzleForHTTP("/_api/lists/getByTitle('$ARGV[0]')");
    $URL .= "/items" unless $OPTS{meta};
    $URL .= swizzleForHTTP("($OPTS{id})") if $OPTS{id};
    $URL .= '?' if $OPTS{query};
    $URL .= swizzleForHTTP($OPTS{query}) if $OPTS{query};
}

$OPTS{request} = 'POST' if $OPTS{create};
$OPTS{request} = 'MERGE' if $OPTS{update};
$OPTS{request} = 'DELETE' if $OPTS{delete};

unless ($OPTS{usetmp}) {
    mkdir($TMP_DIR) or die "mkdir $TMP_DIR : $!";
    chmod(0700, $TMP_DIR) or die "chmod $TMP_DIR : $!";
}

chdir($TMP_DIR) or die "chdir $TMP_DIR : $!";

$PROPS{NTLM} = "--max-time 30";
if ($URL =~ m!sharepoint\.com!) {
    if ($ENV{SHAREPOINT_PROXY_AUTH_REQ}) {
	$PROPS{NTLM} .= ' -n --proxy-anyauth';
	writeNETRC();
    }
}
else {
    $PROPS{NTLM} .= ' -n --ntlm';
    writeNETRC();
}

if ($URL =~ m!sharepoint\.com!) {
    map { delete $ENV{$_} } qw(HTTPS_PROXY HTTP_PROXY);

    if ($ENV{SHAREPOINT_PROXY_SITE} =~ m!https!) {
        $ENV{HTTPS_PROXY} = $ENV{SHAREPOINT_PROXY_SITE};
    }
    elsif ($ENV{SHAREPOINT_PROXY_SITE})  {
        $ENV{HTTP_PROXY} = $ENV{SHAREPOINT_PROXY_SITE};
    }

    unless ($ENV{SHAREPOINT_CONN_COOKIE}) {
        my $samlData_ = "$TMP_DIR/SAML.dat";

	decryptConnStr();

	foreach (qw(SHAREPOINT_CONN_DECRYPTED)) {
	    if ($ENV{$_} =~ m!^(\w+)\\(\w+)\@(\S+)!) {
		writeSAMLData(data => $samlData_
			      , site => $ENV{SHAREPOINT_HOST}
			      , username => $2 . '@' . lc($1) . '.com'
			      , password => swizzleXML($3));
	    }
	    else {
		print STDERR "FORMAT $_ EXPECTING DOMAIN\\USER\@PASS !!\n";
		exit($EXIT);
	    }
	}

        my $samlResp_ = "$TMP_DIR/GetSAMLResponse.txt";

        $CURL_OUT = curl(data => '@' . $samlData_
                         , cipher => 'AES256-SHA'
                         , resp_file => $samlResp_
                         , header => { accept => 'application/atom+xml;charset=utf-8' }
                         , url => 'https://login.microsoftonline.com/extSTS.srf');
        
        $samlResp_ = qx(cat $samlResp_);

	print STDERR "#\n# Getting SAML response\n#\n" if $DEBUG_SP_LI;

        if ($samlResp_ =~ m!<wst:RequestSecurityTokenResponse[^>]*>(.*)</wst:RequestSecurityTokenResponse>!) {
            my $reqSecTokenResp_ = $1;

            if ($reqSecTokenResp_ =~ m!<wsse:BinarySecurityToken[^>]*>(.*)</wsse:BinarySecurityToken!) {
                $samlResp_ = deswizzleXML($1);
            }
            else {
                saveError("UNABLE TO GET wsse:BinarySecurityToken !!");
                delete $PROPS{NTLM};
            }

            if ($reqSecTokenResp_ =~ m!<wsu:Expires[^>]*>(.*)</wsu:Expires!) {
                $ENV{SHAREPOINT_CONN_EXPIRES} = deswizzleXML($1);
            }
            else {
                saveError("UNABLE TO GET wsu:Expires !!");
                delete $PROPS{NTLM};
            }
        }
        else {
            saveError("UNABLE TO GET wst:RequestSecurityTokenResponse !!");
            delete $PROPS{NTLM};
        }

        if ($PROPS{NTLM}) {
            my %cookies_ = ( file => "$TMP_DIR/Cookies.txt" );

            $CURL_OUT = curl(data => "'$samlResp_'"
                             , cipher => 'AES256-SHA'
                             , resp_file => '/dev/null'
                             , cookies => $cookies_{file}
                             , header => { HOST =>  $ENV{SHAREPOINT_HOST} }
                             , url => "-L https://$ENV{SHAREPOINT_HOST}/_forms/default.aspx?wa=wsignin1.0");

	    print STDERR "#\n# Getting FED cookies\n#\n" if $DEBUG_SP_LI;

            foreach (qx(cat $cookies_{file})) {
                chomp;
                $cookies_{$1} = $2 if m!(rtFa|FedAuth)\s+(\S+)!;
            }

            foreach (qw(rtFa FedAuth)) {
                unless ($cookies_{$_}) {
                    saveError("UNABLE TO GET COOKIES!!");
                    delete $PROPS{NTLM};
                }
            }

            $ENV{SHAREPOINT_CONN_COOKIE} = "rtFa=$cookies_{rtFa};FedAuth=$cookies_{FedAuth}" if $PROPS{NTLM};
        }
    }
}

if ($PROPS{NTLM}) {
    unless ($ENV{SHAREPOINT_CONN_FORM_DIGEST_VALUE}) {
        my %h_;

        if ($ENV{SHAREPOINT_CONN_COOKIE}) {
            %h_ = (data => "''"
                   , cipher => 'AES256-SHA'
                   , resp_file => $GET_DIGEST_RESPONSE
                   , header => { accept => 'application/atom+xml;charset=utf-8', Cookie => $ENV{SHAREPOINT_CONN_COOKIE} }
                   , url => swizzleForHTTP("$ENV{SHAREPOINT_SITE}/_api/contextinfo")
                );
        }
        else {
            %h_ = (data => '{}'
                   , resp_file => $GET_DIGEST_RESPONSE
                   , header => { qw(accept application/atom+xml;charset=utf-8) }
                   , url => swizzleForHTTP("$ENV{SHAREPOINT_SITE}/_api/contextinfo")
                );
        }

        $CURL_OUT = curl(%h_);

	print STDERR "#\n# Getting FORM DIGEST\n#\n" if $DEBUG_SP_LI;

        foreach (qx(cat $GET_DIGEST_RESPONSE)) {
            chomp;

            foreach my $t_ (qw(FormDigestValue FormDigestTimeoutSeconds)) {
                if (m!<d:($t_)[^>]*>(.*)</d:$t_[^>]*>!) {
		    if ($t_ eq 'FormDigestTimeoutSeconds') {
			$ENV{SHAREPOINT_CONN_FORM_DIGEST_TIMEOUT} = time + $2 - 600;
		    }
		    else {
			$ENV{SHAREPOINT_CONN_FORM_DIGEST_VALUE} = $2;
		    }
                }
            }
        }

        foreach (qw(SHAREPOINT_CONN_FORM_DIGEST_TIMEOUT SHAREPOINT_CONN_FORM_DIGEST_VALUE)) {
            unless ($ENV{$_}) {
                saveError("UNABLE TO GET $_ !!");
                delete $PROPS{NTLM};
            }
        }
    }
}

if ($PROPS{NTLM}) {
    unless ($OPTS{digest}) {
        my %CURL = ( resp_file => $GET_LIST_RESPONSE, url => $URL);

        if ($ENV{SHAREPOINT_CONN_COOKIE}) {
            $CURL{cipher} = 'AES256-SHA';
            $CURL{header}{Authorization} = "Bearer $ENV{SHAREPOINT_CONN_FORM_DIGEST_VALUE}";
            $CURL{header}{Cookie} = $ENV{SHAREPOINT_CONN_COOKIE};
        }
        else {
            $CURL{header}{'X-RequestDigest'} = $ENV{SHAREPOINT_CONN_FORM_DIGEST_VALUE};
        }

        $CURL{request} = $OPTS{request} if $OPTS{request};

        if ($OPTS{json}) {
            $CURL{header}{accept} = 'application/json;odata=verbose';
        }
        else {
            $CURL{header}{accept} = 'application/atom+xml;charset=utf-8';
        }

        if ($OPTS{create} || $OPTS{update} || $OPTS{delete}) {
            $CURL{header}{'content-type'} = 'application/json;odata=verbose';
            $CURL{header}{'IF-MATCH'} = '*';
        }

        if ($OPTS{data}) {
            $CURL{data} = $OPTS{data};

            unless ($CURL{data} =~ m!^\@\-$!) {
                my $tmpPostData_ = "$TMP_DIR/CMD-POST-$$.dat";

                if ($CURL{data} =~ m!^\@!) {
                    my $p_ = $CURL{data};
                    
                    $p_ =~ s!^\@!!;

                    if (-f $p_) {
                        qx(cp $p_ $tmpPostData_);
                        $CURL{data} = '@' . "$tmpPostData_";
                    }
                    else {
                        saveError("NOT FOUND $p_ !!");
                        delete $PROPS{NTLM};
                    }
                }
                else {
                    if (open(TMP_POST_DATA, ">$tmpPostData_")) {
                        print TMP_POST_DATA $CURL{data};
                        close TMP_POST_DATA;
                        $CURL{data} = '@' . "$tmpPostData_";
                    }
                    else {
                        saveError("WRITE FAILED TO $tmpPostData_ !!");
                        delete $PROPS{NTLM};
                    }
                }
            }
        }

        $CURL_OUT = curl(%CURL) if $PROPS{NTLM};
    }

    if ($PROPS{NTLM}) {
        foreach (qx(cat $CURL_OUT)) {
            if (m!(HTTP/1.1\s+(\d)\d+.*)!) {
                $EXIT = ($2 == 2 ? 0 : 1);
                $PROPS{HTTPStatus} = $1;
                $PROPS{HTTPStatus} =~ s!$TRAILING_WS!!;
            }
        }

        if ($OPTS{digest}) {
            my %h_;

	    foreach (@DIGEST_KEYS) {
		$h_{$_} = $ENV{$_} if $ENV{$_};
	    }

	    my $tmp_ = "$TMP_DIR/sp_digest.json";

	    if (open(SP_DIGEST, ">$tmp_") && chmod(0600, $tmp_)) {
		print SP_DIGEST JSON->new->utf8(1)->pretty(1)->encode(\%h_);
		close SP_DIGEST;

		rename($tmp_, $SP_DIGEST);

		$h_{COMMENT} = "CREATED $SP_DIGEST " . scalar(qx(ls -l $SP_DIGEST));
	    }

            print Dumper(\%h_);
        }
        elsif (-f $GET_LIST_RESPONSE && ($OPTS{xml} || $OPTS{json})) {
            print qx(cat $GET_LIST_RESPONSE);
        }
        elsif ($EXIT == 0 && ($OPTS{update} || $OPTS{delete}) && ! $OPTS{xml}) {
            print Dumper([{     'd:ID' => $OPTS{id},
                                    'd:Id' => $OPTS{id},
                                    'REST_ACTION' => ($OPTS{update} ? 'update' : 'delete'),
                                    'HTTP_STATUS' => $PROPS{HTTPStatus} }]);
        }
        elsif (-f $GET_LIST_RESPONSE) {
            my $aref_ = convertXMLToPerlHash($GET_LIST_RESPONSE);

            print Dumper($aref_) if scalar(@$aref_);
        }
    }
}

unless ($OPTS{usetmp}) {
    my $d_ = "$ENV{HOME}/FAIL_GET_SP_LIST_ITEMS";

    if ($EXIT && -d $d_) {
        rename($TMP_DIR, "$d_/" . basename($TMP_DIR));
    }
}

exit($EXIT);

sub saveError {
    if ($_[0]) {
        open(ERR, ">>$TMP_DIR/Error.txt");
        print ERR $_[0];
        close ERR;
        print STDERR $_[0];
    }
}

sub convertXMLToPerlHash {
    my $p_ = shift;
    my $s_ = qx(cat $p_);
    my @pos_;
    my @data_;
    my $badXML_;
    my $tag_ = 'm:properties';

    while ($s_ =~ m!(<content|</content>)!g) {
        push @pos_, pos($s_);
    }

    while (scalar(@pos_)) {
        next if $badXML_;

        my $x_ = shift @pos_;
        my $y_ = shift @pos_;
        my $prop_ = substr($s_, $x_, $y_ - $x_);
        my %h_;

        if ($prop_ =~ s!^.*<$tag_[^>]*>!!s && $prop_ =~ s!</$tag_>.*!!s) {
            my $i_;

            while ($prop_) {
                if ($prop_ =~ m!^<([^>]+)>!) {
                    my $m_ = $1;
                    my @a_ = split(/\s+/, $m_);
                    my $e_ = $a_[0];

                    if ($e_) {
                        if ($prop_ =~ s!^<${e_}[^/>]*/>!!) {
                            $h_{$e_} = undef;
                        }
                        elsif ($prop_ =~ s!^<${e_}[^>]*>(.*)\</$e_\>!!s) {
                            my $m_ = $1;

                            $h_{$e_} = $m_;
                        }
                        else {
                            $badXML_ = $prop_;
                        }
                    }
                    else {
                        $badXML_ = $prop_;
                    }
                }
                else {
                    $badXML_ = $prop_;
                }

                $i_++;
                $badXML_ = $prop_ if $i_ > 100;
                $prop_ = undef if $badXML_;
            }

            if ($badXML_) {
                push @data_, { 'm:error' => $badXML_ };
            }
            else {
                push @data_, { %h_ };
            }
        }
    }

    unless (scalar(@data_)) {
        my %h_;

        if ($s_ =~ m!<(m:error)[^>]+>!) {
            $h_{$1} = $s_;

            push @data_, { %h_ };
        }
    }

    return \@data_;
}

sub deswizzleXML {
    my $ret_ = shift;

    if ($ret_) {
        $ret_ =~ s/&amp;/&/sg;
        $ret_ =~ s/&lt;/</sg;
        $ret_ =~ s/&gt;/>/sg;
        $ret_ =~ s/&quot;/"/sg;
    }

    return $ret_;
}

sub swizzleXML {
    my $ret_ = shift;

    if ($ret_) {
        $ret_ =~ s/&/&amp;/sg;
        $ret_ =~ s/</&lt;/sg;
        $ret_ =~ s/>/&gt;/sg;
        $ret_ =~ s/"/&quot;/sg;
    }

    return $ret_;
}

sub writeNETRC {
    my $netrc_ = "$TMP_DIR/.netrc";
    
    open(NETRC, ">$netrc_") or die "Wopen $netrc_ : $!";
    chmod(0600, $netrc_) or die "chmod $netrc_ : $!";

    decryptConnStr();

    $netrc_ = "machine $ENV{SHAREPOINT_HOST} login $ENV{SHAREPOINT_CONN_DECRYPTED}\n";
    $netrc_ =~ s!\@! password !;

    print NETRC $netrc_;
    close NETRC;
}

sub writeSAMLData {
    my %h_ = @_;

    open(SAML, ">$h_{data}") or die "Wopen $h_{data} : $!";
    chmod(0600, $h_{data})   or die "chmod $h_{data} : $!";

    print SAML "<s:Envelope xmlns:s='http://www.w3.org/2003/05/soap-envelope'
      xmlns:a='http://www.w3.org/2005/08/addressing'
      xmlns:u='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'>
  <s:Header>
    <a:Action s:mustUnderstand='1'>http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</a:Action>
    <a:ReplyTo>
      <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
    </a:ReplyTo>
    <a:To s:mustUnderstand='1'>https://login.microsoftonline.com/extSTS.srf</a:To>
    <o:Security s:mustUnderstand='1'
       xmlns:o='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'>
      <o:UsernameToken>
        <o:Username>$h_{username}</o:Username>
        <o:Password>$h_{password}</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <t:RequestSecurityToken xmlns:t='http://schemas.xmlsoap.org/ws/2005/02/trust'>
      <wsp:AppliesTo xmlns:wsp='http://schemas.xmlsoap.org/ws/2004/09/policy'>
        <a:EndpointReference>
          <a:Address>$h_{site}</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
      <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
      <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
    </t:RequestSecurityToken>
  </s:Body>
</s:Envelope>";

    close SAML;
}

sub curl {
    $CURL_CNT++;

    my %h_ = @_;
    my $curlKsh_ = "$TMP_DIR/$CURL_CNT-curl.ksh";
    my $curlOut_ = "$TMP_DIR/$CURL_CNT-curl_out.txt";

    open(KSH, ">$curlKsh_") or die "Wopen $curlKsh_ : $!";
    chmod(0700, $curlKsh_)  or die "chmod $curlKsh_ : $!";

    print KSH "#!/usr/bin/ksh\n\n";
    print KSH "export HOME=$TMP_DIR\n\n";
    print KSH "export http_proxy=$ENV{HTTP_PROXY}\n\n" if $ENV{HTTP_PROXY};
    print KSH "export HTTPS_PROXY=$ENV{HTTPS_PROXY}\n\n" if $ENV{HTTPS_PROXY};
    print KSH "umask 007\n\n";
    print KSH "/usr/bin/curl -v $PROPS{NTLM} \\\n";
    print KSH " -o $h_{resp_file}     \\\n" if $h_{resp_file};
    print KSH " -c $h_{cookies}       \\\n" if $h_{cookies};
    print KSH " -X $h_{request}       \\\n" if $h_{request};
    print KSH " --data $h_{data}      \\\n" if $h_{data};
    print KSH " --ciphers $h_{cipher} \\\n" if $h_{cipher};
    map { print KSH " -H '$_:$h_{header}{$_}' \\\n" } keys %{$h_{header}};
    print KSH " $h_{url}\n";

    close KSH;

    qx($curlKsh_ > $curlOut_ 2>&1);

    return $curlOut_;
}

sub swizzleForHTTP {
    my $ret_ = shift;

    if ($ret_) {
        $ret_ =~ s!\ !%20!g;
        $ret_ =~ s!\!!%21!g;
        $ret_ =~ s!\"!%22!g;
        $ret_ =~ s!\#!%23!g;
        $ret_ =~ s!\$!%24!g;
        $ret_ =~ s!\&!%26!g;
        $ret_ =~ s!\'!%27!g;
        $ret_ =~ s!\(!%28!g;
        $ret_ =~ s!\)!%29!g;
        $ret_ =~ s!\*!%2A!g;
        $ret_ =~ s!\;!%3B!g;
        $ret_ =~ s!\<!%3C!g;
        $ret_ =~ s!\>!%3E!g;
        $ret_ =~ s!\?!%3F!g;
    }

    return $ret_;
}

sub findFileInDirs {
    my $file_ = shift;
    my $ret_;

    foreach (@_) {
	my $p_ = "$_/$file_";
	
	if (-r $p_) {
	    $ret_ = $p_;
	    last;
	}
    }

    return $ret_;
}

sub decryptConnStr {
    unless ($ENV{SHAREPOINT_CONN_DECRYPTED}) {
	if ($ENV{SHAREPOINT_CONN_ENCRYPTED}) {
	    $ENV{SHAREPOINT_CONN_DECRYPTED} = qx($DECRYPT $ENV{SHAREPOINT_CONN_ENCRYPTED});
	}

	unless ($ENV{SHAREPOINT_CONN_DECRYPTED}) {
	    print STDERR "CANNOT DECRYPT PW!!\n";
	    exit($EXIT);
	}
    }
}

__DATA__
get_sp_list_items.pl \
        -create -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" \
        Bogus [SP_SITE]

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" | \
        get_sp_list_items.pl -create -data @- Bogus [SP_SITE]

get_sp_list_items.pl \
        -create -data "@create_data.txt" Bogus [SP_SITE]

get_sp_list_items.pl \
        -update -id $ID -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" \
        Bogus [SP_SITE]

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" | \
        get_sp_list_items.pl -update -id $ID -data @- Bogus [SP_SITE]

get_sp_list_items.pl \
        -update -id $ID -data "@update_data.txt" Bogus [SP_SITE]

get_sp_list_items.pl -delete -id $ID Bogus [SP_SITE]

get_sp_list_items.pl -meta Bogus [SP_SITE]

get_sp_list_items.pl Bogus [SP_SITE]

get_sp_list_items.pl -query '$top=5' Bogus [SP_SITE]

get_sp_list_items.pl -query '$filter=ID eq 3' Bogus [SP_SITE]

get_sp_list_items.pl -query "\$filter=startswith(Title,'Updated')" Bogus [SP_SITE]

get_sp_list_items.pl -query "\$filter=substringof('dated',Title)" Bogus [SP_SITE]


#!/usr/bin/python
#
# Use Popen in python 2.6
#

import sys
import os
import subprocess
import json

CMD = os.getenv("HOME") + "/bin/get_sp_list_items.pl"
SP_LIST = "Servers"
URL = "https://yoyodyne.sharepoint.com/sites/etl"

PROCESS = subprocess.Popen([CMD, "-json", "-meta", SP_LIST, URL], stdout=subprocess.PIPE)
OUTPUT, UNUSED_ERR = PROCESS.communicate()
RET_CODE = PROCESS.poll()

#sys.exit(0)

if RET_CODE == 0 :
    q = json.loads(OUTPUT)
    print SP_LIST + ' Created=' + q['d']['Created']
    print SP_LIST + ' LastItemDeletedDate=' + q['d']['LastItemDeletedDate']
    print SP_LIST + ' LastItemModifiedDate=' + q['d']['LastItemModifiedDate']
    print SP_LIST + ' ItemCount=' + str(q['d']['ItemCount'])
else :
    sys.exit(1)

PROCESS = subprocess.Popen([CMD, "-json", "-query", "$top=" + str(q['d']['ItemCount']), SP_LIST, URL], stdout=subprocess.PIPE)
OUTPUT, UNUSED_ERR = PROCESS.communicate()
RET_CODE = PROCESS.poll()

if RET_CODE == 0 :
    q = json.loads(OUTPUT)

    for o in q['d']['results'] :
        print str(o['ID']) + ',' + o['Title'] + ',' + o['KERNEL_NAME']


#!/usr/bin/perl

use strict;
my $CMD = "$ENV{HOME}/bin/get_sp_list_items.pl";
my $SP_LIST = "Servers";
my $URL = "https://yoyodyne.sharepoint.com/sites/etl";
my $VAR1 = qx($CMD -meta $SP_LIST $URL);
my $TOP = '$top=';

if ($VAR1) {
        eval $VAR1;

        print "$SP_LIST Created=", $VAR1->[0]{'d:Created'}, "\n";
        print "$SP_LIST LastItemDeletedDate=",  $VAR1->[0]{'d:LastItemDeletedDate'}, "\n";
        print "$SP_LIST LastItemModifiedDate=",  + $VAR1->[0]{'d:LastItemModifiedDate'}, "\n";
        print "$SP_LIST ItemCount=", $VAR1->[0]{'d:ItemCount'}, "\n";

        $TOP .= $VAR1->[0]{'d:ItemCount'};
}
else {
        exit(1);
}

$VAR1 = qx($CMD -query '$TOP' $URL $SP_LIST);

if ($VAR1) {
        eval $VAR1;
        foreach my $href_ (@$VAR1) {
                print $href_->{'d:ID'}, ',', $href_->{'d:Title'}, ',', $href_->{'d:KERNEL_NAME'}, "\n";
        }
}
