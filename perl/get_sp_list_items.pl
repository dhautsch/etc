#!/usr/bin/perl
# 
#
# # Following is example code - don@hautsch.com
#
# use Data::Dumper;
# use strict;
# 
# my @array_ = getMeta(qw(http://sharepoint/eso-sites/etlinfraeng/etl bogusTasks));
# print Dumper(\@array_); # Should see error message
# 
# @array_ = getMeta(qw(http://sharepoint/eso-sites/etlinfraeng/etl Tasks));
# print Dumper(\@array_);
# 
# @array_ = getItems(qw(http://sharepoint/eso-sites/etlinfraeng/etl Tasks));
# print Dumper(\@array_);
# 
# sub getMeta {
# 	my $url_ = shift;
# 	my $list_ = shift;
# 	my @items_;
# 
# 	if ($url_ && $list_) {
# 		my $VAR1 = qx(./get_sp_list_items.pl -meta $url_ $list_);
# 
# 		if ($VAR1) {
# 			eval $VAR1;
# 			@items_ = @$VAR1;
# 		}
# 	}
# }
# 
# sub getItems {
# 	my $url_ = shift;
# 	my $list_ = shift;
# 	my @items_;
# 
# 	if ($url_ && $list_) {
# 		my $VAR1 = qx(./get_sp_list_items.pl $url_ $list_);
# 
# 		if ($VAR1) {
# 			eval $VAR1;
# 			@items_ = @$VAR1;
# 		}
# 	}
# }



use Getopt::Long;
use Data::Dumper;
use File::Basename;
use lib "$ENV{HOME}/etlsupp/lib/perl";
use ETLSuppUtils;
use strict;

my %PROPS = readProps("$ENV{HOME}/etlsupp/config.properties");
my $SHAREPOINT_CONN_PROP = 'com.fanniemae.a22.sharepoint_conn';
my $TMP_DIR = getTmpDirName();
my $GET_LIST_RESPONSE_XML = "$TMP_DIR/GetListResponse.xml";
my $HTML_HEADER = "'Accept: application/atom+xml; charset=utf-8'";
my $SHAREPOINT_HOST;
my $NETRC = "$TMP_DIR/.netrc";
my $CURL_KSH = "$TMP_DIR/curl.ksh";
my %OPTS;
my $EXIT = 1;

END { whackTmpDirList(); exit($EXIT) };

$OPTS{help}++ unless GetOptions(\%OPTS, qw(help xml meta verbose));

$OPTS{help}++ unless @ARGV == 2;

if ($OPTS{help}) {
	print STDERR "Usage : $0 [-help -meta -verbose] <URL> <LIST_TITLE>\n";
	print STDERR "\t-help : print this message.\n";
	print STDERR "\t-meta : print list metadata instead of items.\n";
	print STDERR "\t-verbose : print curl output to STDERR.\n";
	print STDERR "\t-xml : output xml.\n";
	exit($EXIT);
}

$ARGV[1] =~ s! !%20!g;

my $URL = "'$ARGV[0]/_api/lists/getbytitle%28%27$ARGV[1]%27%29";

$URL .= '/items' unless $OPTS{meta};
$URL .= "'";

if ($URL =~ m!http://([^:/]+)!) {
	$SHAREPOINT_HOST = $1;
}
else {
	print STDERR "Cannot determine sharepoint host !!\n";
	exit($EXIT);
}

if (silentRunCmd("mkdir -p $TMP_DIR")) {
	print STDERR "Cannot mkdir $TMP_DIR!!\n";
	exit($EXIT);
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
	print KSH "exec curl -v -n --ntlm -o $GET_LIST_RESPONSE_XML --header $HTML_HEADER $URL\n";
	close KSH;
	chmod(0700, $CURL_KSH) or die "chmod $CURL_KSH : $!";

	foreach (qx($CURL_KSH 2>&1)) {
		print STDERR if $OPTS{verbose};

		if (m!HTTP/1.1 200 OK!) {
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

		while ($s_ =~ m!(<content|</content>)!g) {
			push @pos_, pos($s_);
		}

		while (scalar(@pos_)) {
			my $x_ = shift @pos_;
			my $y_ = shift @pos_;
			my $prop_ = substr($s_, $x_, $y_ - $x_);
			my %h_;

			$prop_ =~ s!^.*<m:properties>!!;
			$prop_ =~ s!</m:properties>.*!!;

			while ($prop_ =~ m!(<[^>]+>[^<]+</[^>]+>)!g) {
				my $e_ = $1;

				if ($e_ =~ m!(<[^>]+>)([^<]+)(<[^>]+>)!) {
					my $v_ = $2;
					my $k_ = $1;

					$k_ =~ s![<>]!!g;
					$k_ =~ s!\s.*!!g;

					$h_{$k_} = $v_;
				}
			}

			push @data_, { %h_ };
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
}

exit($EXIT);
