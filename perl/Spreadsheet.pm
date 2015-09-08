package Spreadsheet;

# use Spreadsheet;
#
# my @NUMBER_FORMAT = Spreadsheet::NUMBER_FORMAT();
# my $SPREADSHEET = Spreadsheet->new();
#
# $SPREADSHEET->author('bozo@clown.com');
# $SPREADSHEET->company('www.clown.com
');
#
# $SPREADSHEET->header('Column 1 Row 1', 'Column 2 Row 1', 'Column 3 Row 1');
# $SPREADSHEET->types(qw(String Number DateTime));
# $SPREADSHEET->styles('','Currency','Long Date');
#
# $SPREADSHEET->add('World', 13, '2012-03-12T10:12:14Z');
# $SPREADSHEET->add('Wide', 14, '2005-11-09T23:14:06Z');
# $SPREADSHEET->add('Web', 15, '2006-10-08T13:10:05Z');
#                OR
# push @{$SPREADSHEET->rows()}, ['World', 13, '2012-03-12T10:12:14Z'];
# push @{$SPREADSHEET->rows()}, ['Wide', 14, '2005-11-09T23:14:06Z'];
# push @{$SPREADSHEET->rows()}, ['Web', 15, '2006-10-08T13:10:05Z'];
#
# print $SPREADSHEET->xml();

use strict;

my $NUMBER_FORMAT = {
'General' => 's22',
'General Number' => 's23',
'General Date' => 's24',
'Long Date' => 's25',
'Medium Date' => 's26',
'Short Date' => 's27',
'Long Time' => 's28',
'Medium Time' => 's29',
'Short Time' => 's30',
'Currency' => 's31',
'Euro Currency' => 's32',
'Fixed' => 's33',
'Standard' => 's34',
'Percent' => 's35',
'Scientific' => 's36',
'Yes/No' => 's37',
'True/False' => 's38',
'On/Off' => 's39'
};

my $WORKBOOK = <<'WORKBOOK';
<?xml version="1.0" encoding="UTF-8"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
        xmlns:o="urn:schemas-microsoft-com:office:office"
        xmlns:x="urn:schemas-microsoft-com:office:excel"
        xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
        xmlns:html="http://www.w3.org/TR/REC-html40
">
        <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
                <Author>!!author!!</Author>
                <Created>!!created!!</Created>
                <Company>!!company!!</Company>
        </DocumentProperties>
        <ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">
                <ProtectStructure>False</ProtectStructure>
                <ProtectWindows>False</ProtectWindows>
        </ExcelWorkbook>
        <Styles>
                <Style ss:ID="Default" ss:Name="Normal">
                        <Alignment ss:Vertical="Bottom"/>
                        <Borders/>
                        <Font/>
                        <Interior/>
                        <NumberFormat/>
                        <Protection/>
                </Style>
                <Style ss:ID="s21">
                        <Font x:Family="Swiss" ss:Bold="1" />
                </Style>
!!styles!!
        </Styles>
        <Worksheet ss:Name="Sheet1">
!!rows!!
                <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
                        <ProtectObjects>False</ProtectObjects>
                        <ProtectScenarios>False</ProtectScenarios>
                </WorksheetOptions>
        </Worksheet>
</Workbook>
WORKBOOK
    ;

sub new {
    my $class_  = shift;
    my $self_ = {
	AUTHOR  => undef,
	COMPANY => undef,
	XML => undef,
	HEADER => [],
	TYPES => [],
	STYLES => [],
	ROWS => [],
    };

    my @gmtime_ = gmtime();
    my $gmtime_ = sprintf("%02d", $gmtime_[5]+1900)
	. '-' . sprintf("%02d", $gmtime_[4]+1)
	. '-' . sprintf("%02d", $gmtime_[3])
	. 'T' . sprintf("%02d", $gmtime_[2])
	. ':' . sprintf("%02d", $gmtime_[1])
	. ':' . sprintf("%02d", $gmtime_[0]);

    my $styles_ = "";

    foreach my $k_ (sort keys %$NUMBER_FORMAT)
    {
        $styles_ .= "\t\t" . '<Style ss:ID="' . $NUMBER_FORMAT->{$k_}
	. '"><NumberFormat ss:Format="'
	    . $k_ . '"/></Style>' . "\n";
    }

    $self_->{XML} = $WORKBOOK;
    $self_->{XML} =~ s/!!created!!/$gmtime_/;
    $self_->{XML} =~ s/!!styles!!/$styles_/;

    my $closure_ = sub {
        my $field = shift;

        if (@_) {
            $self_->{$field} = shift;
        }

        return $self_->{$field};
    };
    
    bless($closure_, $class_);
    return $closure_;
}

sub NUMBER_FORMAT {
    return sort keys %$NUMBER_FORMAT;
}

sub author {
    &{ $_[0] }("AUTHOR",  @_[ 1 .. $#_ ] );
}

sub company {
    &{ $_[0] }("COMPANY",   @_[ 1 .. $#_ ] );
}

sub rows {
    &{ $_[0] }("ROWS", @_[ 1 .. $#_ ] );
}

sub header {
    &{ $_[0] }("HEADER", [ @_[ 1 .. $#_ ] ] );
}

sub types {
    &{ $_[0] }("TYPES",  [ @_[ 1 .. $#_ ] ] );
}

sub styles {
    &{ $_[0] }("STYLES", [ @_[ 1 .. $#_ ] ] );
}

sub add {
    my $rows_ = &{ $_[0] }("ROWS");

    push @$rows_, [ @_[ 1 .. $#_ ] ];
}

sub xml {
    my $xml_ = &{ $_[0] }("XML", @_[ 1 .. $#_ ] );
    my $author_ = &{ $_[0] }("AUTHOR");
    my $company_ = &{ $_[0] }("COMPANY");
    my $rows_ = '';
    my $maxClm_ = 0;
    my $maxRow_ = 0;

    $xml_ =~ s/!!author!!/$author_/;
    $xml_ =~ s/!!company!!/$company_/;

    my @hdr_ = @{&{ $_[0] }("HEADER")};
    my @styles_;

    if (scalar(@hdr_))
    {
         foreach (@hdr_)
         {
             push @styles_, 's21';
             $maxClm_++;
         }

         $rows_ .= makeRow([@hdr_], [], [@styles_]);
         $maxRow_++;
    }

    @styles_ = ();

    foreach (@{&{ $_[0] }("STYLES")})
    {
        push @styles_, $NUMBER_FORMAT->{$_} || '';
    }

    foreach my $aref_ (@{&{ $_[0] }("ROWS")})
    {
        my @a_ = @$aref_;

         if (scalar(@a_) > $maxClm_)
         {
             $maxClm_ = scalar(@a_);
         }

        $rows_ .= makeRow($aref_, &{ $_[0] }("TYPES"), [@styles_]);
        $maxRow_++;
    }

    if ($rows_)
    {
         $rows_ = "\t\t" . '<Table ss:ExpandedColumnCount="' . $maxClm_ . '"'
                  . ' ss:ExpandedRowCount="' . $maxRow_ . '" x:FullColumns="1" x:FullRows="1">' . "\n"
                       . $rows_
                       . "\t\t</Table>";
    }

    $xml_ =~ s/!!rows!!/$rows_/;
    $xml_ =~ s/\n/\r\n/g;

    return $xml_;
}

sub makeRow {
    my $row_ = shift;
    my $types_ = shift;
    my $styles_ = shift;
    my @row_ = @$row_;
    my @types_ = @$types_;
    my @styles_ = @$styles_;

    $row_ = "\t\t\t" . '<Row>';

    foreach my $i_ (0..$#row_)
    {
        my $type_ = $types_[$i_] || 'String';
        my $style_ = $styles_[$i_] || '';
        my $datum_ = $row_[$i_];

        $datum_ =~ s/\</\&lt\;/g;
        $datum_ =~ s/\>/\&gt\;/g;
        $datum_ =~ s/\&/\&amp\;/g;

        $style_ = ' ss:StyleID="' . $style_ . '"' if $style_;

         $row_ .= "\n\t\t\t\t<Cell$style_>\n"
             . "\t\t\t\t\t" . '<Data ss:Type="' . $type_ . '">' . $datum_ . '</Data>' . "\n"
             . "\t\t\t\t</Cell>\n";
    }
    $row_ .= "\t\t\t</Row>\n";

    return $row_;
}

1;
