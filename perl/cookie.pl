#!/usr/bin/perl

use POSIX qw(strftime);
use strict;
#
# Set cookie to expire 10 days from now
#
my $COOKIE_VAL=qx(md5sum $0); chomp $COOKIE_VAL; $COOKIE_VAL =~ s!\s+.*!!;
my @SWIZZLE_REGEX = map { qr($_) } qw(& > < ' ");
my @SWIZZLE_REPL = qw(&amp; &gt; &lt; &apos; &quot;);
my $COOKIE_EXPIRES = strftime "%A, %d-%b-%Y %H:%M:%S GMT", gmtime(time + 10*86400);

print<<EOF
Set-Cookie: MyCookie=$COOKIE_VAL;expires=$COOKIE_EXPIRES
Content-type: text/html

<!DOCTYPE html
	PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<HTML xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
<TITLE>Cookie Jar</TITLE>
<STYLE type="text/css">
	
	<!--/* <![CDATA[ */
	table {
			font-family: verdana,arial,sans-serif;
			font-size:11px;
			color:#333333;
			border-width: 1px;
			border-color: #3A3A3A;
			border-collapse: collapse;
	}
	table th {
			white-space: nowrap;
			border-width: 1px;
			padding: 8px;
			border-style: solid;
			border-color: #3A3A3A;
			background-color: #B3B3B3;
	}
	table td {
			white-space: nowrap;
			border-width: 1px;
			padding: 8px;
			border-style: solid;
			border-color: #3A3A3A;
			background-color: #ffffff;
	}
	
	
	/* ]]> */-->
</STYLE>
<META http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
</HEAD>
<BODY>
<TABLE>
<TR><TH>ENV_KEY</TH><TH>ENV_VALUE</TH></TR>
EOF
;

$ENV{COOKIE} = $COOKIE_VAL;

foreach my $k_ (sort keys %ENV) {
	foreach my $i_ (0..$#SWIZZLE_REGEX) {
		$ENV{$k_} =~ s!$SWIZZLE_REGEX[$i_]!$SWIZZLE_REPL[$i_]!g;
	}
	print "<TR><TD>$k_</TD><TD>$ENV{$k_}</TD></TR>\n";
#	print "$k_='$ENV{$k_}'\n";
}

print <<EOF
</TABLE>
EOF
;

if ($ENV{REQUEST_METHOD} eq 'POST') {
	my $buffer_;

	print "<h3>POST FOLLOWS</h3>\n";
	print "<pre>\n";

	read(STDIN, $buffer_, $ENV{'CONTENT_LENGTH'});
	print $buffer_;

	print "\n</pre>\n";
}
print <<EOF
</BODY>
</HTML>
EOF
;
