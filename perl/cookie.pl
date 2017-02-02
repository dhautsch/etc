#!/usr/bin/perl

use strict;
#
# Set cookie to expire in a week at noon gmt
#
my $COOKIE_VAL=qx(md5sum $0); $COOKIE_VAL =~ s!\s+.*!!;
my @SWIZZLE_REGEX = map { qr($_) } qw(& > < ' ");
my @SWIZZLE_REPL = qw(&amp; &gt; &lt; &apos; &quot;);

print<<EOF
Set-Cookie: MyCookie=$COOKIE_VAL; expires=Thu Dec 31 12:00:00 2037
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
	print "<tr><td>$k_</td><td>$ENV{$k_}</td></tr>\n";
#	print "$k_='$ENV{$k_}'\n";
}

print <<EOF
</TABLE>
</BODY>
</HTML>
EOF
;
