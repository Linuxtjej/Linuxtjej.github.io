#!/usr/bin/perl 

use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;

sub try_paths {
    foreach (@_) {
        return $_ if ( -d $_ );
    }
}

my $CSLPATH = try_paths(
    "$ENV{HOME}/.csl",
    "$ENV{HOME}/Dropbox/Litteratur/CSL",
    "$ENV{HOME}/doc/bibliography/CSL"
);
my $BIBPATH = try_paths( "$ENV{HOME}/Dropbox/Litteratur",
    "$ENV{HOME}/doc/bibliography" );

my @bib;
my $csl    = "apa";
my $locale = "sv-SE";
my $verbose = 0;
my $no_pandoc = 0;

GetOptions(
    "bibliography=s" => \@bib,
    "csl=s"        => \$csl,
    "language=s"   => \$locale,
    "verbose"      => \$verbose,
    "no-pandoc"    => \$no_pandoc,
) || die "cli error";

@bib = ( "$BIBPATH/papers.bib", "$BIBPATH/books.bib" ) unless (@bib);

# find csl
unless ( -f $csl ) {
    $csl = "$CSLPATH/" . $csl;
    unless ( -f $csl ) {
        $csl = $csl . '.csl';
        unless ( -f $csl ) {
            die "Could not find CSL style $csl";
        }
    }
}

my $pattern = join '\s+', @ARGV;

if ( !$pattern ) {
    print STDERR "Nothing to search for.\n";
    exit 2;
}

$pattern = qr/$pattern/is;

my $pandoc_opts = join " ", map {"--bibliography=$_"} @bib;
$pandoc_opts .= " --csl=$csl -M locale=$locale";

my $pid;
unless ($no_pandoc) {
    $pid = open3( \*PANDOC, \*MARKDOWN, \*ERR,
    "pandoc -t markdown-citations --no-wrap $pandoc_opts" )
    || die "open3() fail";
}
else {
    *PANDOC = *STDOUT;
}

print PANDOC "---\n";
print PANDOC "nocite: |\n";

foreach my $bib (@bib) {
    print STDERR "searching $bib\n" if ($verbose);
    open( BIB, "<$bib" ) || die "File $bib not found";
    local $/ = undef;
    my $data = <BIB>;
    close BIB;
    while ( $data =~ m/\@\w+\{\s*(\w+)\s*,([^@]*)/g ) {
        my ( $key, $data ) = ( $1, $2 );
        if ( $data =~ m/$pattern/ ) {
            print PANDOC "  \@$key,\n";
            print STDERR "found $key\n" if ($verbose);
        }
    }
}

print PANDOC "...\n";
close PANDOC;

unless ($no_pandoc) {
    my $i = 1;
    while (<MARKDOWN>) {
        next if ( m/^</ || m/^\s*$/ );
        printf '%2d. ', $i++;
        print;
    }

    close MARKDOWN;
    close ERR;

    waitpid( $pid, 0 );
}