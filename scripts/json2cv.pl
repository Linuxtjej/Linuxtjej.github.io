#!/usr/bin/perl

use warnings;
use strict;
use JSON;
use Getopt::Long;
use IO::File;
use POSIX qw(strftime);
use Data::Dumper;

my $lang            = 'sv';
my $type            = 'full';
my $json            = 'cv.json';
my $importance      = 2;
my $education_first = 0;

unless (
    GetOptions(
        "lang=s"          => \$lang,
        "type=s"          => \$type,
        "json=s"          => \$json,
        "importance=i"    => \$importance,
        "ecucation-first" => \$education_first
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

# Print items
sub items {
    my ( $items_type, $cv, $fh, %opt ) = @_;

    $opt{sort_key} = "start_date" unless ( $opt{sort_key} );
    $opt{second}   = "employer"   unless ( $opt{second} );

    my $heading_done;

    # Items
    foreach my $item ( sort { $b->{ $opt{sort_key} } cmp $a->{ $opt{sort_key} } } @{ $cv->{$items_type} } ) {

        # This entry should be printed if (1) $type equals any JSON type or
        # (2) $type="full" and there is no JSON type OR there is no "meta" in
        # JSON. And, for both 1 and 2, (3) importance is not set or lower than
        # threshold.
        next
            unless ( ( $item->{type} && grep( /^$type$/, @{ $item->{type} } ) || ( $type eq "full" && !$item->{meta} ) ) )
            && ( !$item->{importance} || $item->{importance} <= $importance );

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

        # title and employer/school
        my $s = '';
        $s .= "**$item->{title}->{$lang}**" if ( $item->{title} );
        $s .= ", $item->{$opt{second}}->{$lang}" if ( $item->{ $opt{second} } );

        # location (if it exists)
        $s .= ", $item->{location}" if ( $item->{location} );

        # # importance
        # $s .= " ($item->{importance})" if ( $item->{importance} );

        # end first line
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
if ( $cv->{title}->{$type}->{$lang} ) {
    print $fh "title: $cv->{title}->{$type}->{$lang}\n";
}
else {
    print $fh "title: $cv->{title}->{default}->{$lang}\n";
}
print $fh "author: $cv->{author}\n";
print $fh "date: ", strftime( "%Y-%m-%d", localtime ), "\n";
print $fh "lang: $lang_bcp47\n";
print $fh "...\n\n";

# Preamble
print $fh $cv->{preamble}->{all}->{$lang}   if ( $cv->{preamble}->{all}->{$lang} );
print $fh $cv->{preamble}->{$type}->{$lang} if ( $cv->{preamble}->{$type}->{$lang} );

# Education and previous positions
if ($education_first) {
    items( "education", $cv, $fh, second => 'school', sort_key => 'end_date', year => 1 );
    items( "positions", $cv, $fh, second => 'employer' );
}

# Previous positions and education
else {
    items( "positions", $cv, $fh, second => 'employer' );
    items( "education", $cv, $fh, second => 'school', sort_key => 'end_date', year => 1 );
}

# Other Education
items( "other_education", $cv, $fh, second => 'school', sort_key => 'end_date' );

# Other stuff
items( "other", $cv, $fh, second => 'subtitle' );

# Language skills
language_skills( $cv, $fh );
