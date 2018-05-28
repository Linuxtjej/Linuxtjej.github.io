#!/usr/bin/perl

use warnings;
use strict;
use JSON;
use Getopt::Long;
use IO::File;
use POSIX qw(strftime);
use File::Slurp;
use Data::Dumper;

my $lang                   = 'sv';
my $cvtype                 = 'full';
my $json                   = 'data/cv.json';
my $importance             = 2;
my $education_first        = 0;
my $job_descriptions       = 1;
my $education_descriptions = 1;
my $contact                = 0;
my $personal               = 0;

unless (
    GetOptions(
        "lang=s"          => \$lang,
        "type=s"          => \$cvtype,
        "json=s"          => \$json,
        "importance=i"    => \$importance,
        "ecucation-first" => \$education_first,
        "contact"         => \$contact,
        "personal"        => \$personal
    )
    )
{
    print STDERR "Invalid command line option.\n";
    exit 2;
}

# academic cv is special in several respects
if ( $cvtype eq 'academic' ) {
    $education_first        = 1;
    $education_descriptions = 0;
    $job_descriptions       = 0;
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
    open( my $fh, '<', $_[0] ) || die "Could not open $_[0]";
    return decode_json(<$fh>);
}

sub indent_par {
    my ( $array_ref, $first, $indent ) = @_;
    $first  = ':   ' unless ($first);
    $indent = '    ' unless ($indent);
    for my $i ( 0 .. $#$array_ref ) {
        next unless ( $array_ref->[$i] );
        $array_ref->[$i] = ( $i == 0 ? $first : $indent ) . $array_ref->[$i];
    }
    return $array_ref;
}

# A generalized function for writing items
sub itemize {
    my ( $cv, %opt ) = @_;

    my $level       = $opt{level}        ? $opt{level}             : 1;
    my $sort_key    = $cv->{sort_key}    ? $cv->{sort_key}         : $opt{sort_key};
    my $term_field  = $cv->{term_field}  ? $cv->{term_field}       : $opt{term_field};
    my $type        = $opt{type}         ? $opt{type}              : $cvtype;
    my @field_order = $cv->{field_order} ? @{ $cv->{field_order} } : @{ $opt{field_order} };

    my $list_type = 'default';
    if ( $cv->{list_type} ) {
        $list_type = $cv->{list_type};
    }
    elsif ( $opt{list_type} ) {
        $list_type = $opt{list_type};
    }

    # collect into string
    my $s = '';

    # flag for tracking printing of heading
    my $heading_done;

    # sort items in original JSON data structure - since JSON is only read,
    # never written, it can be allowed
    if ($sort_key) {
        @{ $cv->{items} } = sort { $b->{$sort_key} cmp $a->{$sort_key} } @{ $cv->{items} };
    }

    # items
    foreach my $item ( @{ $cv->{items} } ) {

        # This entry should be printed if (1) $mytype equals any JSON type or
        # (2) $mytype="full" and there is no JSON type OR there is no "meta" in
        # JSON. And, for both 1 and 2, (3) importance is not set or lower than
        # threshold.
        #
        # There is, however, still a bug here, because profile shouldn't be
        # printed in 'full' type. Oh, well. I just solve it by reducing
        # importance for now.
        next
            unless ( $opt{all}
            || ( ( $item->{type} && grep( /^$type$/, @{ $item->{type} } ) || ( $type eq "full" && !$item->{meta} ) ) )
            && ( !$item->{importance} || $item->{importance} <= $importance ) );

        # heading
        unless ($heading_done) {
            my $heading = $cv->{heading}->{$type}->{$lang} ? $cv->{heading}->{$type}->{$lang} : $cv->{heading}->{default}->{$lang};
            if ($heading) {
                $s .= "#" x $level . " $heading\n\n";
            }
            $heading_done = 1;
        }

        # recurse if this is also a list
        if ( $item->{items} ) {
            $s .= itemize(
                $item,
                level          => $level + 1,
                field_order    => \@field_order,
                list_type      => $list_type,
                term_field     => $term_field,
                all            => $opt{all},
                no_description => $opt{no_description}
            );
        }
        else {
            my @par;

            # first paragraph is composed of specified fields, first element is bold
            my @tmp = grep $_, map { $item->{$_}->{$lang} } @field_order;
            if ( scalar @tmp > 1 ) {
                $tmp[0] = "**$tmp[0]**";
                push @par, join( ", ", @tmp ) . ".";
            }
            elsif ( scalar @tmp == 1 ) {
                push @par, @tmp;
            }

            # description
            unless ( $opt{no_description} ) {
                if ( $item->{descriptions}->{$lang} ) {
                    push @par, "" if (@par);
                    push @par, "- $_" foreach ( @{ $item->{descriptions}->{$lang} } );
                }
                elsif ( $item->{description}->{$lang} ) {
                    push @par, "" if (@par);
                    push @par, "$item->{description}->{$lang}";
                }
            }

            # plain list
            if ( $list_type eq 'plain' ) {
                $s .= join( "\n\n", @par ) . "\n\n";
            }

            # itemized list
            elsif ( $list_type eq 'itemize' ) {
                indent_par( \@par, "  * ", "    " );
                $s .= join( "\n", @par ) . "\n";
            }

            # definition list
            elsif ( $list_type eq 'definition' ) {
                indent_par( \@par, ":   ", "    " );
                $s .= $item->{$term_field}->{$lang} . "\n";
                $s .= join( "\n", @par ) . "\n\n";
            }

            # a "dated" list (this is the default)
            else {

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

                # create range or something
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

                indent_par( \@par, ":   ", "    " );

                $s .= $year_or_range . "\n";
                $s .= join( "\n", @par ) . "\n\n";
            }

        }

    }

    # add extra newline for (compact) itemized lists
    $s .= "\n" if ( $list_type eq 'itemize' );

    return $s;
}

### MAIN LOOP ###

# Read CV as JSON
my $cv = read_json($json);

# Open output and ensure UTF-8
my $fh = *STDOUT;
$fh->binmode(':utf8');

# YAML block
print $fh "---\n";
if ( $cv->{title}->{$cvtype}->{$lang} ) {
    print $fh "title: $cv->{title}->{$cvtype}->{$lang}\n";
}
else {
    print $fh "title: $cv->{title}->{default}->{$lang}\n";
}
print $fh "author: $cv->{author}\n";

# print $fh "date: ", strftime( "%Y-%m-%d", localtime ), "\n";
print $fh "lang: $lang_bcp47\n";
print $fh "...\n\n";

# Preamble
print $fh $cv->{preamble}->{all}->{$lang} if ( $cv->{preamble}->{all}->{$lang} );
print $fh $cv->{preamble}->{$cvtype}->{$lang} if ( $cv->{preamble}->{$cvtype}->{$lang} );

print $fh itemize( $cv->{personal}, all => 1 ) if ($personal);

if ( $cvtype eq 'academic' ) {
    print $fh itemize( $cv->{education},       no_description => 1 );
    print $fh itemize( $cv->{positions},       no_description => 1 );
    print $fh itemize( $cv->{publications},    all            => 1 );
    print $fh itemize( $cv->{teaching},        all            => 1 );
    print $fh itemize( $cv->{skills},          all            => 1 );
    print $fh itemize( $cv->{languages},       all            => 1 );
    print $fh itemize( $cv->{positions},       type           => 'academic_other' );
    print $fh itemize( $cv->{other_education}, no_description => 1 );
}
else {
    print $fh itemize( $cv->{profile} );
    print $fh itemize( $cv->{positions} );
    print $fh itemize( $cv->{education} );
    print $fh itemize( $cv->{other_education} );
    print $fh itemize( $cv->{other} );
    print $fh itemize( $cv->{languages}, all => 1 );
}

print $fh itemize( $cv->{contact}, all => 1 ) if ($contact);
