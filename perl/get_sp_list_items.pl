#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use File::Basename;
use strict;

my %PROPS;
my $SHAREPOINT_CONN_PROP = 'sharepoint_conn';
my $PROXY_PROP = 'proxy.url';
my $TRAILING_WS = '\s*$';
my $SHAREPOINT_HOST;
my $SCRIPT_DIR = dirname($0); $SCRIPT_DIR = qx(cd $SCRIPT_DIR && pwd); chomp $SCRIPT_DIR;
my $TMP_DIR;
my $GET_LIST_RESPONSE;
my $GET_DIGEST_RESPONSE;
my $CURL_OUT;
my $CURL_CNT = 0;
my %OPTS;
my $EXIT = 1;
my $VAR1;

END { qx(/bin/rm -rf $TMP_DIR) if -d $TMP_DIR && ! ( $OPTS{keeptmp} || $OPTS{usetmp} ); exit($EXIT) };

$OPTS{help}++ unless GetOptions(\%OPTS, qw(usetmp=s keeptmp help xml json digest create update delete getuserbyid data=s id=i meta verbose query=s example));

if ($OPTS{example}) {
    while (<DATA>) {
        print;
    }
    exit($EXIT);
}

unless ($OPTS{help}) {
    my $i_ = 0;

    foreach my $opt_ (qw(digest meta create update delete getuserbyid)) {
        $i_++ if $OPTS{$opt_};
    }

    if ($i_ > 1) {
        $OPTS{help}++;
    }
    elsif ($i_ < 1) { # get list items
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ unless scalar(@ARGV) == 2;
    }
    elsif ($OPTS{create}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ unless $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ unless scalar(@ARGV) == 2;
    }
    elsif ($OPTS{update}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ unless $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ unless scalar(@ARGV) == 2;
    }
    elsif ($OPTS{delete}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ unless scalar(@ARGV) == 2;
    }
    elsif ($OPTS{meta}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ unless scalar(@ARGV) == 2;
    }
    elsif ($OPTS{digest}) {
        $OPTS{help}++ if $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ if $OPTS{json};
        $OPTS{help}++ if $OPTS{xml};
        $OPTS{help}++ unless scalar(@ARGV) == 1;
    }
    elsif ($OPTS{getuserbyid}) {
        $OPTS{help}++ unless $OPTS{id};
        $OPTS{help}++ if $OPTS{data};
        $OPTS{help}++ if $OPTS{query};
        $OPTS{help}++ unless scalar(@ARGV) == 1;
    }
}

if ($OPTS{help}) {
    print STDERR "Usage :\n";
    print STDERR "\t$0 -help : print this message.\n";
    print STDERR "\t$0 -example : show example code.\n";
    print STDERR "\t$0 [-verbose -xml|-json] -meta <URL> <LIST_TITLE> : get list metadata instead of items.\n";
    print STDERR "\t$0 [-verbose -xml|-json  -query <QUERY>] <URL> <LIST_TITLE> : get list items.\n";
    print STDERR "\t$0 [-verbose -xml|-json] -create -data <DATA> <URL> <LIST_TITLE>\n";
    print STDERR "\t$0 [-verbose -xml|-json] -update -id <ID> -data <DATA> <URL> <LIST_TITLE>\n";
    print STDERR "\t$0 [-verbose -xml|-json] -delete -id <ID> <URL> <LIST_TITLE>\n";
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
    exit($EXIT);
}

$TMP_DIR = $OPTS{usetmp} || sprintf("$ENV{HOME}/tmp-%d-%d-%s", time, $$, basename($0));
$GET_LIST_RESPONSE = "$TMP_DIR/GetListResponse.txt";
$GET_DIGEST_RESPONSE = "$TMP_DIR/GetDigestResponse.txt";

$Data::Dumper::Sortkeys++;

if ($OPTS{digest}) {
    delete $ENV{SHAREPOINT_CONN_COOKIE};
    delete $ENV{SHAREPOINT_CONN_FORM_DIGEST};
}

my $URL = swizzleForHTTP($ARGV[0]);

if ($OPTS{getuserbyid}) {
    $URL .= swizzleForHTTP("/_api/web/GetUserById($OPTS{id})");
}
else {
    $URL .= swizzleForHTTP("/_api/lists/getByTitle('$ARGV[1]')");
    $URL .= "/items" unless $OPTS{meta};
    $URL .= swizzleForHTTP("($OPTS{id})") if $OPTS{id};
    $URL .= '?' if $OPTS{query};
    $URL .= swizzleForHTTP($OPTS{query}) if $OPTS{query};
}

$OPTS{request} = 'POST' if $OPTS{create};
$OPTS{request} = 'MERGE' if $OPTS{update};
$OPTS{request} = 'DELETE' if $OPTS{delete};

if ($URL =~ m!https*://([^:/]+)!) {
        $SHAREPOINT_HOST = $1;
}
else {
    print STDERR "Cannot determine sharepoint host !!\n";
    exit($EXIT);
}

unless ($ENV{SHAREPOINT_CONN} && $ENV{SHAREPOINT_PROXY}) {
    if (open(CFG, $ENV{CONFIG_PROPS} || "$ENV{HOME}/etlsupp/config.properties")) {
        while (<CFG>) {
            if (m!^($SHAREPOINT_CONN_PROP|$PROXY_PROP)=(\S+)!) {
                $PROPS{$1} = $2;
            }

            last if scalar(keys %PROPS) == 2;
        }
        close CFG;
        
        if (scalar(keys %PROPS) != 2) {
            print STDERR "CANNOT FIND PROPS IN CFG!!\n";
            exit($EXIT);
        }
    }
    else {
        print STDERR "CANNOT OPEN CFG!!\n";
        exit($EXIT);
    }
}

$PROPS{$PROXY_PROP} = $ENV{SHAREPOINT_PROXY} if $ENV{SHAREPOINT_PROXY};

if ($ENV{SHAREPOINT_CONN}) {
    $PROPS{$SHAREPOINT_CONN_PROP} = $ENV{SHAREPOINT_CONN};
}
else {
    $PROPS{$SHAREPOINT_CONN_PROP} = qx($ENV{HOME}/etlsupp/bin/decrypt $PROPS{$SHAREPOINT_CONN_PROP});
}

if ($PROPS{$SHAREPOINT_CONN_PROP} =~ m!^(\w+)\\(\w+)\@(\S+)!) {
    $ENV{SP_USER} = $2 . '@' . lc($1) . '.com';
    $ENV{SP_PASS} = $3;
}
else {
    print STDERR "FORMAT $SHAREPOINT_CONN_PROP EXPECTING DOMAIN\\USER\@PASS !!\n";
    exit($EXIT);
}

unless ($PROPS{$SHAREPOINT_CONN_PROP}) {
    print STDERR "CANNOT DECRYPT PW!!\n";
    exit($EXIT);
}

if ($URL =~ m!sharepoint\.com!) {
    unless ($PROPS{$PROXY_PROP}) {
        print STDERR "$PROXY_PROP NOT SET!!\n";
        exit($EXIT);
    }
}

$PROPS{CURL_MAX_TIME} = 30;
$PROPS{NTLM} = '--ntlm';

qx(mkdir -p $TMP_DIR) unless $OPTS{usetmp};

chdir($TMP_DIR) or die "chdir $TMP_DIR : $!";

writeNETRC();

if ($URL =~ m!sharepoint\.com!) {
    $PROPS{NTLM} = '--proxy-anyauth';

    map { delete $ENV{$_} } qw(HTTPS_PROXY HTTP_PROXY);

    if ($PROPS{$PROXY_PROP} =~ m!https!) {
        $ENV{HTTPS_PROXY} = $PROPS{$PROXY_PROP};
    }
    else {
        $ENV{HTTP_PROXY} = $PROPS{$PROXY_PROP};
    }

    if ($ENV{SHAREPOINT_CONN_COOKIE}) {
        $PROPS{Cookie} = $ENV{SHAREPOINT_CONN_COOKIE};
    }
    else {
        my $samlData_ = "$TMP_DIR/SAML.dat";

        writeSAMLData(data => $samlData_
                      , site => $SHAREPOINT_HOST
                      , username => $ENV{SP_USER}
                      , password => swizzleXML($ENV{SP_PASS}));

        my $samlResp_ = "$TMP_DIR/GetSAMLResponse.txt";

        $CURL_OUT = curl(data => '@' . $samlData_
                         , cipher => 'AES256-SHA'
                         , resp_file => $samlResp_
                         , header => { accept => 'application/atom+xml;charset=utf-8' }
                         , url => 'https://login.microsoftonline.com/extSTS.srf');
        
        $samlResp_ = qx(cat $samlResp_);

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
                $PROPS{CookieExpires} = deswizzleXML($1);
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
                             , header => { HOST =>  $SHAREPOINT_HOST }
                             , url => "-L https://$SHAREPOINT_HOST/_forms/default.aspx?wa=wsignin1.0");

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

            $PROPS{Cookie} = "rtFa=$cookies_{rtFa};FedAuth=$cookies_{FedAuth}" if $PROPS{NTLM};
        }
    }
}

if ($PROPS{NTLM}) {
    if ($ENV{SHAREPOINT_CONN_FORM_DIGEST}) {
        $PROPS{FormDigestValue} = $ENV{SHAREPOINT_CONN_FORM_DIGEST};
    }
    else {
        my %h_;

        if ($PROPS{Cookie}) {
            %h_ = (data => "''"
                   , cipher => 'AES256-SHA'
                   , resp_file => $GET_DIGEST_RESPONSE
                   , header => { accept => 'application/atom+xml;charset=utf-8', Cookie => $PROPS{Cookie} }
                   , url => swizzleForHTTP($ARGV[0] . '/_api/contextinfo')
                );
        }
        else {
            %h_ = (data => '{}'
                   , resp_file => $GET_DIGEST_RESPONSE
                   , header => { qw(accept application/atom+xml;charset=utf-8) }
                   , url => swizzleForHTTP($ARGV[0] . '/_api/contextinfo')
                );
        }

        $CURL_OUT = curl(%h_);

        foreach (qx(cat $GET_DIGEST_RESPONSE)) {
            chomp;

            foreach my $t_ (qw(FormDigestValue FormDigestTimeoutSeconds)) {
                if (m!<d:($t_)[^>]*>(.*)</d:$t_[^>]*>!) {
                    $PROPS{$1} = $2;
                    $PROPS{$t_} = time + $PROPS{$t_} - 600 if $t_ eq 'FormDigestTimeoutSeconds';
                }
            }
        }

        foreach (qw(FormDigestValue FormDigestTimeoutSeconds)) {
            unless ($PROPS{$_}) {
                saveError("UNABLE TO GET DIGEST !!");
                delete $PROPS{NTLM};
            }
        }
    }
}

if ($PROPS{NTLM}) {
    unless ($OPTS{digest}) {
        my %CURL = ( resp_file => $GET_LIST_RESPONSE, url => $URL);

        if ($PROPS{Cookie}) {
            $CURL{cipher} = 'AES256-SHA';
            $CURL{header}{Authorization} = "Bearer $PROPS{FormDigestValue}";
            $CURL{header}{Cookie} = $PROPS{Cookie};
        }
        else {
            $CURL{header}{'X-RequestDigest'} = $PROPS{FormDigestValue};
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

            map { $h_{$_} = $PROPS{$_} if $PROPS{$_} } qw(FormDigestValue FormDigestTimeoutSeconds Cookie CookieExpires);

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

    $netrc_ = "machine $SHAREPOINT_HOST login $PROPS{$SHAREPOINT_CONN_PROP}\n";
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
    print KSH "umask 002\n\n";
    print KSH "/usr/bin/curl -v --max-time $PROPS{CURL_MAX_TIME} -n $PROPS{NTLM} \\\n";
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

__DATA__
#
# Following is example code - don@hautsch.com
#

get_sp_list_items.pl \
        -create -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" | \
        get_sp_list_items.pl -create -data @- \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
        -create -data "@create_data.txt" \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
        -update -id $ID -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" | \
        get_sp_list_items.pl -update -id $ID -data @- \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
        -update -id $ID -data "@update_data.txt" \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
        -delete -id $ID \
        http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl -meta http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl -query '$top=5' http://sharepoint/eso-sites/etlinfraeng/etl Bogus

#!/usr/bin/python
#
# Use Popen in python 2.6
#

import sys
import os
import subprocess
import json

CMD = os.getenv("HOME") + "/etlsupp/bin/get_sp_list_items.pl"
SP_LIST = "Our_Servers"
URL = "http://sharepoint/eso-sites/etlinfraeng/etl"

PROCESS = subprocess.Popen([CMD, "-json", "-meta", URL, SP_LIST], stdout=subprocess.PIPE)
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

PROCESS = subprocess.Popen([CMD, "-json", "-query", "$top=" + str(q['d']['ItemCount']), URL, SP_LIST], stdout=subprocess.PIPE)
OUTPUT, UNUSED_ERR = PROCESS.communicate()
RET_CODE = PROCESS.poll()

if RET_CODE == 0 :
    q = json.loads(OUTPUT)

    for o in q['d']['results'] :
        print str(o['ID']) + ',' + o['Title'] + ',' + o['KERNEL_NAME']


#!/usr/bin/perl

use strict;
my $CMD = "$ENV{HOME}/etlsupp/bin/get_sp_list_items.pl";
my $SP_LIST = "Our_Servers";
my $URL = "http://sharepoint/eso-sites/etlinfraeng/etl";
my $VAR1 = qx($CMD -meta $URL $SP_LIST);
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
