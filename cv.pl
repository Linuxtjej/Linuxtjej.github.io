#!/usr/bin/perl

use warnings;
use strict;
use JSON;
use Getopt::Long;
use Data::Dumper;

binmode STDOUT, ":utf8";

my $lang = 'sv';
my $type = 'full';
my $json = 'cv.json';

unless (
    GetOptions(
        "lang=s" => \$lang,
        "type=s" => \$type
    )
    )
{
    print STDERR "Invalid command line option.\n";
    exit 2;
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

my $cv = read_json("cv.json");

# Previous positions
print "# $cv->{positions_heading}->{$lang}\n\n";
foreach my $position ( sort { $b->{start_date} cmp $a->{start_date} } @{ $cv->{positions} } ) {

    # check if this entry should be printed
    next unless  ($type eq 'full' || ($position->{type} && grep( /^$type$/, @{$position->{type}})));

    # date
    print range( $position->{start_date}, $position->{end_date} ), "\n";

    # position & employer
    print ":   **$position->{title}->{$lang}**, $position->{employer}->{$lang}";

    # location (if it exists)
    print ", $position->{location}" if ( $position->{location} );
    print ".\n";

    # description (if there is one)
    if ($position->{descriptions}->{$lang}) {
        print "\n";
        print "    \\footnotesize\n\n";
        print "    * $_\n" foreach (@{$position->{descriptions}->{$lang}});
        print "\n    \\normalsize\n";
    }
    elsif ($position->{description}->{$lang}) {
        print "\n    * $position->{description}->{$lang}\n";
    }

    # newline
    print "\n";
}
