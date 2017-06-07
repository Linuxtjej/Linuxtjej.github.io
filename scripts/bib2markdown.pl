#!/usr/bin/perl 

use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;
use JSON;
use open OUT => ':utf8';
use Encode;
use utf8;

sub try_paths {
    foreach (@_) {
        return $_ if ( -d $_ );
    }
}

my $CSLPATH = try_paths( "$ENV{HOME}/.csl", "$ENV{HOME}/Dropbox/Litteratur/CSL", "$ENV{HOME}/doc/bibliography/CSL" );
my $BIBPATH = try_paths("data");

my @bib;
my $csl       = "apa";
my $locale    = "sv-SE";
my $verbose   = 0;
my $no_pandoc = 0;
my $json      = 'data/cv.json';
my @sections  = qw(articles phdthesis conferences);

GetOptions(
    "bibliography=s" => \@bib,
    "csl=s"          => \$csl,
    "language=s"     => \$locale,
    "verbose"        => \$verbose,
    "json=s"         => \$json,
    "no-pandoc"      => \$no_pandoc,
) || die "cli error";

@bib = ("$BIBPATH/publications.bib") unless (@bib);

my $lang = $locale;
$lang =~ s/-.*//;

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

# read JSON
my $cv;
{
    local $/;
    open( my $fh, '<', $json ) || die "Could not open $_[0]";
    $cv = decode_json(<$fh>);
}

@sections = @ARGV if (@ARGV);

my $pandoc_opts = join " ", map {"--bibliography=$_"} @bib;
$pandoc_opts .= " --csl=$csl -M locale=$locale";

my $publications = encode( 'UTF-8', "# $cv->{publications_heading}->{$lang}\n\n" );

foreach my $section (@sections) {
    print STDERR "section $section...\n" if ($verbose);    # debugging output

    # open pipe through pandoc
    my $pid;
    unless ($no_pandoc) {
        $pid = open3( \*PANDOC, \*MARKDOWN, \*ERR, "pandoc -t markdown-citations --no-wrap $pandoc_opts" )
            || die "open3() fail";
    }
    else {
        *PANDOC = *STDOUT;
    }

    # begin YAML block in pandoc pipe
    print PANDOC "---\n";
    print PANDOC "nocite: |\n";

    # search through all bibliography files
    foreach my $bib (@bib) {
        print STDERR "searching $bib\n" if ($verbose);
        open( BIB, "<$bib" ) || die "File $bib not found";
        local $/ = undef;
        my $data = <BIB>;
        close BIB;
        while ( $data =~ m/\@\w+\{\s*(\w+)\s*,([^@]*)/g ) {
            my ( $key, $data ) = ( $1, $2 );

            #print STDERR "key=$key data=$data\n";
            if ( $data =~ m/section\s*=\s*\{$section\}/s ) {
                print PANDOC "  \@$key,\n";
                print STDERR "found $key\n" if ($verbose);
            }
        }
    }

    # end yaml block
    print PANDOC "...\n";

    # take care of pandoc output
    unless ($no_pandoc) {
        close PANDOC;

        $publications .= "## " . encode( 'UTF-8', $cv->{ "publications_" . $section . "_heading" }->{$lang} ). "\n\n";

        binmode MARKDOWN, ":utf8";

        while (<MARKDOWN>) {
            next if ( m/^</ || m/^\s*$/ );
            s/Hämtad från/Tillgänglig på/;
            s/Retrieved from/Available at/;
            s/[“”]/"/g;
            $publications .= "$_\n";
        }

        close MARKDOWN;
        close ERR;

        waitpid( $pid, 0 );
    }
}

print $publications;
