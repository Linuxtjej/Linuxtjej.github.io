#!/usr/bin/perl

use warnings;
use strict;
use JSON;
use Getopt::Long;
use IO::File;
use POSIX qw(strftime);
use Data::Dumper;

my $lang = 'sv';
my $type = 'full';
my $json = 'cv.json';

unless (
    GetOptions(
        "lang=s" => \$lang,
        "type=s" => \$type,
        "json=s" => \$json
    )
    )
{
    print STDERR "Invalid command line option.\n";
    exit 2;
}

# set full BCP 47 language codes for pandoc
my $lang_bcp47;
if ( $lang eq 'sv' ) {
    $lang_bcp47 = 'sv-SE';
}
elsif ( $lang eq 'en' ) {
    $lang_bcp47 = 'en-GB';
}
else {
    print STDERR "Invalid language code $lang.\n";
    exit 3;
}

sub read_json {
    local $/;
    open( my $fh, '<', $_[0] );
    return decode_json(<$fh>);
}

sub range {
    my ( $start, $end ) = @_;
    if ( $start && $start =~ m/^(\d{4})/ ) {
        my $range = $1;
        if ($end) {
            if ( $end =~ m/^(\d{4})/ ) {
                if ( $range eq $1 ) {
                    return $range;
                }
                else {
                    return "$range--$1";
                }
            }
            else {
                die "Invalid end date: $end";
            }
        }
        else {
            return "$range--";
        }
    }
}

sub indent {
    my ( $string, $first, $indent ) = @_;
    $first  = ':   ' unless ($first);
    $indent = '    ' unless ($indent);
    my @lines = split /\n/, $string;
    for my $i ( 0 .. $#lines ) {
        next unless ( $lines[$i] );
        $lines[$i] = ( $i == 0 ? $first : $indent ) . $lines[$i];
    }
    return join( "\n", @lines ) . "\n";
}

# Format description in a nice way (reuse code)
sub description {
    my $item = shift;
    my $s    = '';
    if ( $item->{descriptions}->{$lang} ) {
        $s .= "- $_\n" foreach ( @{ $item->{descriptions}->{$lang} } );
    }
    elsif ( $item->{description}->{$lang} ) {
        $s .= "$item->{description}->{$lang}\n";
    }
    return $s;
}

# Previous positions
sub previous_positions {
    my ( $cv, $fh ) = @_;
    print $fh "# $cv->{positions_heading}->{$lang}\n\n";
    foreach my $position ( sort { $b->{start_date} cmp $a->{start_date} } @{ $cv->{positions} } ) {

        # check if this entry should be printed
        next unless ( $type eq 'full' || ( $position->{type} && grep( /^$type$/, @{ $position->{type} } ) ) );

        # date
        print $fh range( $position->{start_date}, $position->{end_date} ), "\n";

        my $s = '';

        # position & employer
        $s .= "**$position->{title}->{$lang}**, $position->{employer}->{$lang}" if ( $position->{title} );

        # location (if it exists)
        $s .= ", $position->{location}" if ( $position->{location} );
        $s .= ".\n\n" if ($s);

        # description (if there is one)
        $s .= description($position);

        # print indented
        print $fh indent($s), "\n";
    }

}

# Education
sub education {
    my ( $cv, $fh, $listing ) = @_;
    print $fh "# $cv->{education_heading}->{$lang}\n\n";
    foreach my $education ( sort { $b->{end_date} cmp $a->{end_date} } @{ $cv->{education} } ) {

        # This entry should be printed if (1) $type equals any JSON type or
        # (2) $type="full" and there is no JSON type OR there is no "limit"
        # type in JSON.
        if ( $education->{type} && grep( /^$type$/, @{ $education->{type} } )
            || ( $type eq "full" && ( !$education->{type} || grep( /^limit$/, @{ $education->{type} } ) ) ) )
        {
            print STDERR "$education->{title}->{$lang} should be printed\n";
        }
        else {
            print STDERR "$education->{title}->{$lang} should NOT be printed\n";
            next;
        }

        # another exclusion criteria is if a class is specified (this is really, really ugly logic)
        if ( $listing && $education->{listing} && $education->{listing} eq $listing ) {
            print STDERR "$education->{title}->{$lang} should be printed (listing)\n";
        }
        else {
            print STDERR "$education->{title}->{$lang} should NOT be printed (listing)\n";
            next;
        }

        # check if this entry should be printed
        #next unless ( ($type eq 'full' && $education->{type} && grep( /^limit$/, @{ $education->{type} } )) || ( $education->{type} && grep( /^$type$/, @{ $education->{type} } ) ) );

        # date
        my $year = $education->{end_date};
        $year =~ s/-.*//;
        print $fh "$year\n";

        # title and school
        my $s = '';
        $s .= "**$education->{title}->{$lang}**, $education->{school}->{$lang}";

        # location (if it exists)
        $s .= ", $education->{location}" if ( $education->{location} );
        $s .= ".\n\n" if ($s);

        # description (if there is one)
        $s .= description($education);

        # print indented
        print $fh indent($s), "\n";
    }

}

# Education
sub items {
    my ( $items_type, $cv, $fh, %opt ) = @_;

    $opt{sort_key} = "start_date" unless ( $opt{sort_key} );

    my $heading_done;

    # Items
    foreach my $item ( sort { $b->{ $opt{sort_key} } cmp $a->{ $opt{sort_key} } } @{ $cv->{$items_type} } ) {

        # This entry should be printed if (1) $type equals any JSON type or
        # (2) $type="full" and there is no JSON type OR there is no "limit"
        # type in JSON.
        next
            unless ( $item->{type} && grep( /^$type$/, @{ $item->{type} } )
            || ( $type eq "full" && !$item->{meta} ) );

        # Heading
        unless ($heading_done) {
            print $fh "# ", $cv->{ $items_type . "_heading" }->{$lang}, "\n\n";
            $heading_done = 1;
        }

        # date (year or range)
        my $year_or_range;
        my ( $start, $end ) = ( $item->{start_date}, $item->{end_date} );

        # use year part only
        if ( $start && $start =~ m/^(\d{4})/ ) {
            $start = $1;
        }
        if ( $end && $end =~ m/^(\d{4})/ ) {
            $end = $1;
        }
        if ( $start && $end ) {
            if ( $start eq $end ) {
                $year_or_range = "$end";
            }
            else {
                $year_or_range = "$start--$end";
            }
        }
        elsif ($end) {
            $year_or_range = $end;
        }
        elsif ($start) {
            $year_or_range = "$start--";
        }
        else {
            $year_or_range = "NO DATE";
        }
        print $fh "$year_or_range\n";

        # title and school
        my $s = '';
        $s .= "**$item->{title}->{$lang}**, $item->{$opt{second}}->{$lang}" if ( $item->{title} );

        # location (if it exists)
        $s .= ", $item->{location}" if ( $item->{location} );
        $s .= ".\n\n" if ($s);

        # description (if there is one)
        $s .= description($item);

        # print indented
        print $fh indent($s), "\n";
    }

}

# Language skills
sub language_skills {
    my ( $cv, $fh ) = @_;
    print $fh "# $cv->{languages_heading}->{$lang}\n\n";
    foreach my $language ( @{ $cv->{languages} } ) {
        print $fh "$language->{lang}->{$lang}\n";
        print $fh ":   $language->{level}->{$lang}.\n\n";
    }
}

### MAIN LOOP ###

# Read CV as JSON
my $cv = read_json("cv.json");

# Open output and ensure UTF-8
my $fh = *STDOUT;
$fh->binmode(':utf8');

# YAML block
print $fh "---\n";
print $fh "title: $cv->{title}->{$lang}\n";
print $fh "author: $cv->{author}\n";
print $fh "date: ", strftime( "%Y-%m-%d", localtime ), "\n";
print $fh "lang: $lang_bcp47\n";
print $fh "...\n\n";

# Preamble
print $fh $cv->{preamble}->{all}->{$lang}   if ( $cv->{preamble}->{all}->{$lang} );
print $fh $cv->{preamble}->{$type}->{$lang} if ( $cv->{preamble}->{$type}->{$lang} );

# Education
items( "education", $cv, $fh, second => 'school', sort_key => 'end_date', year => 1 );

# Previous positions
items( "positions", $cv, $fh, second => 'employer' );

# Other Education
items( "other_education", $cv, $fh, second => 'school', sort_key => 'end_date' );

# Language skills
language_skills( $cv, $fh );
