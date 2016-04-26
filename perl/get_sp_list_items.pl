#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use File::Basename;
use lib "$ENV{HOME}/etlsupp/lib/perl";
use ETLSuppUtils;
use strict;

my %PROPS = readProps("$ENV{HOME}/etlsupp/config.properties");
my $SHAREPOINT_CONN_PROP = 'com.fanniemae.a22.sharepoint_conn';
my $TRAILING_WS = '\s*$';
my $SHAREPOINT_HOST;
my $TMP_DIR;
my $GET_LIST_RESPONSE_XML;
my $NETRC;
my $CURL_KSH;
my %OPTS;
my $EXIT = 1;

END { whackTmpDirList() unless $OPTS{keeptmp} || $OPTS{usetmp}; exit($EXIT) };

$OPTS{help}++ unless GetOptions(\%OPTS, qw(usetmp=s keeptmp help xml digest create=s update=s delete=s data=s id=i meta verbose query=s example));

if ($OPTS{example}) {
	while (<DATA>) {
		print;
	}
	exit($EXIT);
}

unless ($OPTS{help}) {
	my $i_ = 0;

	foreach my $opt_ (qw(digest meta create update delete)) {
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
	elsif ($OPTS{digest}) {
		$OPTS{help}++ if $OPTS{id};
		$OPTS{help}++ if $OPTS{data};
		$OPTS{help}++ if $OPTS{query};
		$OPTS{help}++ unless scalar(@ARGV) == 1;
	}
	elsif ($OPTS{meta}) {
		$OPTS{help}++ if $OPTS{id};
		$OPTS{help}++ if $OPTS{data};
		$OPTS{help}++ if $OPTS{query};
		$OPTS{help}++ unless scalar(@ARGV) == 2;
	}
}

if ($OPTS{help}) {
	print STDERR "Usage :\n";
	print STDERR "\t$0 -help : print this message.\n";
	print STDERR "\t$0 -example : show example code.\n";
	print STDERR "\t$0 [-verbose -xml] -digest <URL> : get form digest needed for create, update and delete.\n";
	print STDERR "\t$0 [-verbose -xml] -meta <URL> <LIST_TITLE> : get list metadata instead of items.\n";
	print STDERR "\t$0 [-verbose -xml  -query <QUERY>] <URL> <LIST_TITLE> : get list items.\n";
	print STDERR "\t$0 [-verbose -xml] -create <DIGEST> -data <DATA> <URL> <LIST_TITLE>\n";
	print STDERR "\t$0 [-verbose -xml] -update <DIGEST> -id <ID> -data <DATA> <URL> <LIST_TITLE>\n";
	print STDERR "\t$0 [-verbose -xml] -delete <DIGEST> -id <ID> <URL> <LIST_TITLE>\n";
	print STDERR "\t-verbose : print curl output to STDERR.\n";
	print STDERR "\t-query <QUERY> : GET query parameter.\n";
	print STDERR "\t-xml : output xml.\n";
	print STDERR "\t-data <DATA> : required for -create and -update.\n";
	print STDERR "\t\tData can be a JSON struct or a file containing JSON.\n";
	print STDERR "\t\tIf using a file then supply the \@path, that is a @\n";
	print STDERR "\t\tbefore the filename. See curl man page.\n";
	print STDERR "\t-id <ID> : Integer required for -delete and -update.\n";
	exit($EXIT);
}

$TMP_DIR = $OPTS{usetmp} || getTmpDirName();
$GET_LIST_RESPONSE_XML = "$TMP_DIR/GetListResponse-$$.xml";
$NETRC = "$TMP_DIR/.netrc";
$CURL_KSH = "$TMP_DIR/curl.ksh";

my $URL = swizzleForHTTP($ARGV[0]);

if ($OPTS{digest}) {
	$URL .= '/_api/contextinfo';
	$OPTS{data} = '{}';
	$OPTS{request} = 'POST';
}
else {
	$URL .= swizzleForHTTP("/_api/lists/getByTitle('$ARGV[1]')");
	$URL .= "/items" unless $OPTS{meta};
	$URL .= swizzleForHTTP("($OPTS{id})") if $OPTS{id};
	$URL .= '?' if $OPTS{query};
	$URL .= swizzleForHTTP($OPTS{query}) if $OPTS{query};

	$OPTS{request} = 'POST' if $OPTS{create};
	$OPTS{request} = 'MERGE' if $OPTS{update};
	$OPTS{request} = 'DELETE' if $OPTS{delete};
}

if ($URL =~ m!http://([^:/]+)!) {
	$SHAREPOINT_HOST = $1;
}
else {
	print STDERR "Cannot determine sharepoint host !!\n";
	exit($EXIT);
}

unless ($OPTS{usetmp}) {
	if (silentRunCmd("mkdir -p $TMP_DIR")) {
		print STDERR "Cannot mkdir $TMP_DIR!!\n";
		exit($EXIT);
	}
}

chdir($TMP_DIR) or die "chdir $TMP_DIR : $!";

$PROPS{$SHAREPOINT_CONN_PROP} = qx($ENV{HOME}/etlsupp/java/bin/java -cp $ENV{HOME}/etlsupp/classes Blowfish $PROPS{$SHAREPOINT_CONN_PROP});
chomp $PROPS{$SHAREPOINT_CONN_PROP};
$PROPS{$SHAREPOINT_CONN_PROP} =~ s!\@! password !;

if ($PROPS{$SHAREPOINT_CONN_PROP}) {
	open(NETRC, ">$NETRC") or die "Wopen $NETRC : $!";
	close NETRC;
	chmod(0600, $NETRC) or die "chmod $NETRC : $!";

	open(NETRC, ">$NETRC") or die "Wopen $NETRC : $!";
	print NETRC "machine $SHAREPOINT_HOST login $PROPS{$SHAREPOINT_CONN_PROP}\n";
	close NETRC;

	open(KSH, ">$CURL_KSH") or die "Wopen $CURL_KSH : $!";
	print KSH "#!/usr/bin/ksh\n";
	print KSH "export HOME=$TMP_DIR\n";
	print KSH "exec curl -v -n --ntlm \\\n -o $GET_LIST_RESPONSE_XML\\\n";
	print KSH " -X $OPTS{request} \\\n" if $OPTS{request};

	print KSH " -H 'accept:application/atom+xml;charset=utf-8' \\\n";

	my $digest_ = $OPTS{create} || $OPTS{update} || $OPTS{delete};

	if ($digest_) {
		print KSH " -H 'content-type:application/json;odata=verbose' \\\n";
		print KSH " -H 'X-RequestDigest:$digest_' \\\n";
		print KSH " -H 'IF-MATCH:*' \\\n";
	}

	print KSH " --data \"$OPTS{data}\" \\\n" if $OPTS{data};

	print KSH " $URL\n";

	close KSH;

	chmod(0700, $CURL_KSH) or die "chmod $CURL_KSH : $!";

	foreach (qx($CURL_KSH 2>&1)) {
		print STDERR if $OPTS{verbose};

		if (m!(HTTP/1.1\s+2\d+.*)!) {
			$OPTS{HTTP_STATUS} = $1;
			$OPTS{HTTP_STATUS} =~ s!$TRAILING_WS!!;

			$EXIT = 0;
		}
	}

	if (-f $GET_LIST_RESPONSE_XML && $OPTS{xml}) {
		print qx(cat $GET_LIST_RESPONSE_XML);
	}
	elsif (-f $GET_LIST_RESPONSE_XML) {
		my $s_ = qx(cat $GET_LIST_RESPONSE_XML);
		my @pos_;
		my @data_;
		my $badXML_;
		my $tag_ = 'm:properties';

		if ($OPTS{digest}) {
			$s_ = "<content>$s_</content>";
			$tag_ = 'd:GetContextWebInformation';
		}

		while ($s_ =~ m!(<content|</content>)!g) {
			push @pos_, pos($s_);
		}

		while (scalar(@pos_)) {
			next if $badXML_;

			my $x_ = shift @pos_;
			my $y_ = shift @pos_;
			my $prop_ = substr($s_, $x_, $y_ - $x_);
			my %h_;

			if ($prop_ =~ s!^.*<$tag_[^>]*>!! && $prop_ =~ s!</$tag_>.*!!) {
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
							elsif ($prop_ =~ s!^<${e_}[^>]*>(.*)\</$e_\>!!) {
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

		if (scalar(@data_)) {
			$Data::Dumper::Sortkeys++;

			print Dumper(\@data_);
		}
	}
	elsif ($EXIT == 0 && ($OPTS{update} || $OPTS{delete}) && ! $OPTS{xml}) {
		print Dumper([{	'd:ID' => $OPTS{id},
				'd:Id' => $OPTS{id},
				'REST_ACTION' => ($OPTS{update} ? 'update' : 'delete'),
				'HTTP_STATUS' => $OPTS{HTTP_STATUS} }]);
	}
}

exit($EXIT);

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

DIGEST=$(./get_sp_list_items.pl \
		-digest http://sharepoint/eso-sites/etlinfraeng/etl | perl -lane 'print $1 if m!d:FormDigestValue.*\047([^\047]+)\047!')

get_sp_list_items.pl \
	-create "$DIGEST" -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'New_bogus-$$' }" | \
	get_sp_list_items.pl -create "$DIGEST" -data @- \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
	-create "$DIGEST" -data "@create_data.txt" \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
	-update "$DIGEST" -id $ID -data "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

echo "{ '__metadata': { 'type': 'SP.Data.BogusListItem' }, 'Title': 'Updated-$$' }" | \
	get_sp_list_items.pl -update "$DIGEST" -id $ID -data @- \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
	-update "$DIGEST" -id $ID -data "@update_data.txt" \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl \
	-delete "$DIGEST" -id $ID \
	http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl -meta http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl http://sharepoint/eso-sites/etlinfraeng/etl Bogus

get_sp_list_items.pl -query '$top=5' http://sharepoint/eso-sites/etlinfraeng/etl Bogus


use Data::Dumper;
use strict;

my @array_ = getMeta(qw(http://sharepoint/eso-sites/etlinfraeng/etl BogusTasks));
print Dumper(\@array_); # Should see error message if there is no BogusTasks list

@array_ = getMeta(qw(http://sharepoint/eso-sites/etlinfraeng/etl Tasks));
print Dumper(\@array_);

@array_ = getItems(qw(http://sharepoint/eso-sites/etlinfraeng/etl Tasks $top=500));
print Dumper(\@array_);

sub getMeta {
	my $url_ = shift;
	my $list_ = shift;
	my @items_;

	if ($url_ && $list_) {
		my $VAR1 = qx(get_sp_list_items.pl -meta $url_ $list_);

		if ($VAR1) {
			eval $VAR1;
			@items_ = @$VAR1;
		}
	}
	return @items_;
}

sub getItems {
	my $url_ = shift;
	my $list_ = shift;
	my $query_ = shift;
	my @items_;

	if ($url_ && $list_) {
		if ($query_) {
			$query_ = "-query '$query_'";
		}

		my $VAR1 = qx(get_sp_list_items.pl $query_ $url_ $list_);

		if ($VAR1) {
			eval $VAR1;
			@items_ = @$VAR1;
		}
	}
	return @items_;
}
