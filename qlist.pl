#!/usr/bin/env perl
#===============================================================================
#
#         FILE:  qlist.pl
#
#        USAGE:  ./qlist.pl
#
#   DESCRIPTION:  Listuje zaswartość pakietu z możliwością wyszczególnienia plików pod względem manuali, dokumentacja, info, plików binarnych
#				Nakładka na program qlist z pakietu app-portage/portage-utils
# 				Jeśli za opcjami wystąpi jakiś wzorzec to bedzie on przeszukiwany pod względem obecności w nazwie plików.
#
#      OPTIONS:  [package][pattern] [-b|-m|-d|-i|-e|-l|-p|-o] [-g|--no-color|-h|--all]
# REQUIREMENTS:  perl
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Piotr Rogoża (piecia), rogoza.piotr@gmail.com
#      COMPANY:  dracoRP
#      VERSION:  1.4
#      CREATED:  29.04.2011 10:38:15
#     MODIFIED:  09.06.2011 22:45:51
#     REVISION:  2
#    CHANGELOG:
# 	 1.5.1 25.10.2011
# 	 Zmiany kosmetyczne kodu
#    1.4.1 13.06.2011 13:09:22
# dodałem funkcję remove_empty_directories usuwającą puste katalogi z listy
# dodałem opcję --all
#    1.4 09.06.2011 22:45:51
# przepisałem program w perlu
# wypełnianie listy jest uzależnione od systemu operacyjnego, w założeniu funkcja wypełniająca listę nazywa się tak samo jak OS
# filtrowanie, drukowanie listy jest niezależne od systemu
# można albo wyświetlać listę wg. kryteriów albo szukać w zawartości
# dodałem opcję --no-color
# dodałem opcję -g
#===============================================================================

use strict;
use warnings;
#require 5.010;
use v5.10;

use Getopt::Long;
Getopt::Long::Configure('bundling');            # grupowanie opcji programu
#use encoding 'utf8';
use English '-no_match_vars';
use Linux::Distribution qw(distribution_name);
use Carp;                                       # to replace die & warn by croak & carp
use Readonly;
use Term::ANSIColor;

#-------------------------------------------------------------------------------
# O programie - About the program
#-------------------------------------------------------------------------------
my $NAME        = 'qlist';
my $AUTHOR      = 'Piotr Rogoża';
my $EMAIL       = 'rogoza.piotr@gmail.com';
our $VERSION    = 1.5.1;

#{{{ Don't modify below variables !!!
#---------------------------------------------------------------------------
# Startup parameters and global variables
#---------------------------------------------------------------------------
local $ENV{PATH} = '/usr/bin';                  # untainted PATH

# Global read-only variables
Readonly my $SPACE => q{ };
Readonly my $TAB   => qq{\t};

# hash opcji startowych, nazwa systemu, lista plików należących do pakietu,
# tablica @list na początku jest wypełniania nazwami plików należącymi do pakietu, w zaleożności od systemu są wywoływane różne polecenia
# następnie jest filtrowana względem wzorca 'pattern' i wbudowanych wzorców
# i na końcu wyświetlana
my (%options);

# Startup options
GetOptions(
    'b'                => \$options{binary},    # list binary
    'm'                => \$options{man},       # list pages' man
    'd'                => \$options{doc},       # list doc
    'i'                => \$options{info},      # list pages' info
    'e'                => \$options{etc},       # list /etc
    'l'                => \$options{locale},    # list locales
    'p'                => \$options{picture},   # list pictures
    'o'                => \$options{other},     # list other, not matched to above
    'g=s'              => \$options{grep},      # search in contents of files
    'no-color|nocolor' => \$options{nocolor},   # nie podświetlaj dopasowania
    'case'             => \$options{case},
    'all'              => \$options{all},       # wyświetlaj wszystko, domyślnie pomija katalogi
    'h|help'           => \&help
);

#}}}
#{{{  Functions
sub max_length_str { #{{{
    my ($array_ref) = @_;
    my $max_length = 0;
    foreach my $string ( @{$array_ref} ){
        if ( length $string > $max_length ){
            $max_length = length $string;
        }
    }
    return $max_length;
} ## --- end of sub max_length_str }}}

sub help { #{{{
    print "Usage: $NAME [package]|[pattern] -b -m -d -i -e -l -p -o -h -g \n";
    print
        "By default script $NAME lists package. If the pattern is defined then list is filtred to it\n";
    print "Built-in pattern:\n";
    print "\t-b list binary files\n";
    print "\t-m list manual's files\n";
    print "\t-d list documentation's files\n";
    print "\t-i list info's files\n";
    print "\t-e list configuration files\n";
    print "\t-l list locales\n";
    print "\t-p list pictures, icons etc.\n";
    print "\t-o list other files not belong to earlier listed options\n\n";
    print "There are other options:\n";
    print "\t-g search in files' content (use grep), works only with ASCII files\n";
    print "\t--no-color - do not color line matched to pattern\n";
    print"\t--all - by default, the program skips empty directories. This option displays all.\n";
    print "\t-h print this help\n";
    exit 0;
} ## --- end of help }}}

sub filter_list { #{{{
    #===  FUNCTION  ================================================================
    #         NAME:  filter_list
    #  DESCRIPTION:  Filtruje tablicę zgodnie z parametrami zadanymi na starcie
    #===============================================================================
    my ( $pattern, $list_files_ref ) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak qq{Expected references to array\n};
    }

    #-------------------------------------------------------------------------------
    #  Wbudowane wzorce - built-in patterns
    #  Modyfikuj jeśli uważasz za stosowne - Modify if you think fit
    # -------------------------------------------------------------------------------
    my $binary  = 'bin/|program/';
    my $man     = 'man/?';
    my $doc     = 'doc/';
    my $info    = 'info/';
    my $etc     = 'etc/';
    my $locale  = 'locale/';
    my $picture = '\.png|\.xpm|\.svg|icons/|\.jpg|pixmaps/';
    my $regex;

    if ( $options{other} ) {
        $regex
            = $binary . q{|}
            . $man . q{|}
            . $doc . q{|}
            . $info . q{|}
            . $etc . q{|}
            . $locale . q{|}
            . $picture;
    }
    else {
        if ( $options{binary} ) {
            $regex= $regex ? $regex . q{|} . $binary : $binary;
        }
        if ( $options{man} ) {
            $regex= $regex ? $regex . q{|} . $man : $man;
        }
        if ( $options{doc} ) {
            $regex= $regex ? $regex . q{|} . $doc : $doc;
        }
        if ( $options{info} ) {
            $regex= $regex ? $regex . q{|} . $info : $info;
        }
        if ( $options{etc} ) {
            $regex= $regex ? $regex . q{|} . $etc : $etc;
        }
        if ( $options{locale} ) {
            $regex= $regex ? $regex . q{|} . $locale : $locale;
        }
        if ( $options{picture} ) {
            $regex= $regex ? $regex . q{|} . $picture : $picture;
        }
    }
    if ($regex) {

        # jeśli podano opcję wyszukiwania o przefiltruj listę
        if ( $options{other} ) {

            # przefiltruj listę w oparciu o opcję other, czyli reszta która nie pasuje do wbudowanych wzorców
            @{$list_files_ref} = grep { !/$regex/msx } @{$list_files_ref};
        }
        else {

            # przefiltruj listę w oparciu o wbudowane wzorce
            @{$list_files_ref} = grep {/$regex/msx} @{$list_files_ref};
        }
    }
    if ( $pattern and not $options{grep} ) {

        #jeśli podano wzorzec do wyszukania i nie podano opcji -g to wyszukaj wzorzec w liście
        @{$list_files_ref} = grep {/$pattern/} @{$list_files_ref};

        #        if ( not defined $options{nocolor} ) {
        #            #kolorowanie listy jeśli nie podano opcji --no-color
        #            #zamień każdy patter na pokolorowany pattern w $_ i umieść nowy $_ w list_files_ref
        #            for my $file ( @{$list_files_ref} ) {
        #                $file =~ s/$pattern/$colors{red}$pattern$colors{nocolor}/;
        #            }
        #        }
    }

    # usuń puste katalogi chyba, że podano opcję --all
    if ( !$options{all} ) {
        remove_empty_directories($list_files_ref);
    }

    return;
} ## --- end of sub filtelist_files_ref }}}

sub print_list { #{{{
    #===  FUNCTION  ================================================================
    #         NAME:  print_list
    #  DESCRIPTION:  Drukuje na ekranie tablicę, ewentualnie dodaje kolory itp
    #===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak q{Expected references to array}, "\n";
    }
    for my $file ( @{$list_files_ref} ) {

        print color 'bold white' if !$options{nocolor};
        print $file;
        print color 'reset' if !$options{nocolor};
    }
    return;
} ## --- end of print_list }}}

sub generate_list_arch { #{{{

    #===  FUNCTION  ================================================================
    #         NAME: generate_list_arch
    #      PURPOSE:
    #   PARAMETERS: ????
    #      RETURNS: ????
    #  DESCRIPTION: ????
    #       THROWS: no exceptions
    #     COMMENTS: none
    #     SEE ALSO: n/a
    #===============================================================================

    my ($package) = @_;
    if ( !$package ){
        croak q{Packge not defined}, "\n";
    }
    my $list_files_ref = [];

    #usuń początkowe np. local/ z nazwy
    $package =~ s/^.*\///xms;
    system "/usr/bin/pacman -Qq $package &>/dev/null";
    if ( $CHILD_ERROR != 0 ) {
        print"The package $package not found. Try use e.g. 'lspack $package' to search package\n";
        exit 1;
    }
    open my ($fh), q{-|}, "/usr/bin/pacman -Ql $package"
        or croak qq{Cann't execute pacman: $ERRNO};
    @{$list_files_ref} = <$fh>;
    close $fh or croak qq{Cann't close pacman: $ERRNO};
    for my $filename ( @{$list_files_ref} ) {
        chomp $filename;
        $filename =~ s{^\S+\s+}{}xms;            # usuwa nazwę pakietu i spację
    }
    return $list_files_ref;
} ## --- end of generate_list_arch }}}

sub generate_list_debian { #{{{

    #===  FUNCTION  ================================================================
    #         NAME: generate_list_debian
    #      PURPOSE:
    #   PARAMETERS: ????
    #      RETURNS: ????
    #  DESCRIPTION: ????
    #       THROWS: no exceptions
    #     COMMENTS: none
    #     SEE ALSO: n/a
    #===============================================================================

    my ($package) = @_;
    if ( !$package ){
        croak q{Packge dot defined}, "\n";
    }
    my $list_files_ref = [];
    system "/usr/bin/dpkg -l $package &>/dev/null";
    if ( $CHILD_ERROR != 0 ) {
        print "Package $package not found. Try use lspack $package\n";
        exit 1;
    }
    open my ($fh), q{-|}, "/usr/bin/dpkg -L $package"
        or croak qq{Cann't execute dpkg: $ERRNO\n};
    @{$list_files_ref} = <$fh>;
    close $fh or croak qq{Cann't close program dpkg: $ERRNO\n};
    shift @{$list_files_ref};                            # usuń pierwszy element, równy '/.'
    @{$list_files_ref} = map { my $tmp = $_; chomp $$tmp; $tmp } @{$list_files_ref};
    return $list_files_ref;
} ## --- end of generate_list_debian }}}

sub remove_empty_directories { #{{{

    #===  FUNCTION  ================================================================
    #         NAME:  remove_empty_directories
    #   PARAMETERS:  odwołanie do tablicy
    #  DESCRIPTION:  usuwa puste katalogi z listy chyba że podano opcję --all
    #===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak qq{Expected references to array\n};
    }
    for my $count ( reverse 0 .. $#{$list_files_ref} ) { # lecimy od końca

        #        chomp ${$list_files_ref}[$count];
        if ( -d ${$list_files_ref}[$count] )
        {           # usuń z listy katalogi jeśli nie podano opcji --all
            splice @{$list_files_ref}, $count, 1;
        }
        else {
            ${$list_files_ref}[$count] .= "\n";
        }
    }
    return;
} ## --- end of remove_empty_directories }}}

sub grep_list { #{{{

    #===  FUNCTION  ================================================================
    #         NAME: grep_list
    #      PURPOSE:
    #   PARAMETERS: pattern, ref to array of files
    #      RETURNS: none
    #  DESCRIPTION: search in file list for a pattern
    #       THROWS: no exceptions
    #     COMMENTS: none
    #     SEE ALSO: n/a
    #===============================================================================
    my ( $pattern, $input_file_ref ) = @_;
    if ( !$pattern || !$input_file_ref ) {
        croak q{Wrong call sub grep_list, excepted form: pattern, file},"\n";
    }
    if ( !ref $input_file_ref eq 'ARRAY' ) {
        croak q{Excepted ref to array as second parametr}, "\n";
    }
    my ($max_length_filename,                   # max length of filename, for formated display
        $max_length_number,                     # max length of number of row with matched pattern,
        $result,                                # ref to hash with results
    );
    ( $max_length_number, $max_length_filename ) = ( 0, 0 );

    foreach my $file ( @{$input_file_ref} ) {
        chomp $file;
        if ( -T $file && -r $file ) {
            open my ($fh), q{<}, $file 
                or croak q{Couldn't open the file: }, $file, "\n";
            while ( my $row = <$fh> ) {
                if ( $row =~ m{$pattern} ) {
                    if ( length $file > $max_length_filename ) {
                        $max_length_filename = length $file;
                    }
                    if ( length $INPUT_LINE_NUMBER > $max_length_number ) {
                        $max_length_number = length $INPUT_LINE_NUMBER;
                    }
                    chomp $row;
                    $result->{$file}->{$INPUT_LINE_NUMBER} = $row;
                }
            }
            close $fh 
                or croak q{Couldn't close the file: }, $file, "\n";
        }
    }
    my @files = keys %{$result};
    $max_length_filename++;                     # for space
    $max_length_number++;                       # for space and char '+'
    foreach my $filename ( keys %{$result} ) {
        foreach my $number_line ( keys %{ $result->{$filename} } ) {
            print color 'bold white' if !$options{nocolor};
            printf "%-$max_length_filename" . 's', "$filename";
            print color 'green' if !$options{nocolor};
            printf "%-$max_length_number" . 's',   "+$number_line";
            print color 'reset' if !$options{nocolor};
            print $SPACE, $result->{$filename}->{$number_line}, "\n";
        }
    }
    return;
} ## --- end of sub grep_list }}}

#}}}
#---------------------------------------------------------------------------
#  Main program
#---------------------------------------------------------------------------
my ( $package, $pattern, $grep_pattern );

# get name of package and optional pattern to filter list
my ( $rawpackage, $rawpattern ) = @ARGV;

# get grep_pattern
my $rawgrep_pattern = $options{grep} if $options{grep};

# untainted $package, $pattern and $grep_pattern
if ($rawpackage) {
    ($package) = $rawpackage =~ m{^[/\w._-]+}gxms;
    if ( !$package ) {
        print q{Package isn't defined or name you entered isn't allowed}, "\n";
        exit 1;
    }
}

if ($rawgrep_pattern) {
    ($grep_pattern) = $rawgrep_pattern =~ m{^[_~\#\/\\|\w\s._-]+}gxms;
    if ( $options{case} ) {
        $grep_pattern = eval { qr{$grep_pattern}oxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
    else {
        $grep_pattern = eval { qr{$grep_pattern}ioxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
}

if ($rawpattern) {
    ($pattern) = $rawpattern =~ m{^[~\\/|\w._-]+}gxms;
    if ( $options{case} ) {
        $pattern = eval { qr{$pattern}oxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
    else {
        $pattern = eval { qr{$pattern}ioxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
}

my $distribution_name = distribution_name;
if (!$distribution_name){
    print q{I don't know this system}, "\n";
    exit;
}
my $distribution_sub =  'generate_list_' . $distribution_name;
my $list_files = [];                            # ref of array, list of files belong to package
if ( exists &$distribution_sub ){
    {
        no strict 'refs';
        $list_files = &$distribution_sub($package);
    }
}
else {
    print q{I'm sorry but this system isn't supported}, "\n";
    exit;
}
if ( @{$list_files} > 0 ) {

    # filtrowanie listy wg. np. wbudowanych wzorców i wyszukiwanego wzorca
    filter_list( $pattern, $list_files );

    # szukanie w zawartości i drukowanie lub same drukowanie na ekranie
    if ( $options{grep} ) {
        grep_list( $grep_pattern, $list_files );
    }
    else {
        print_list($list_files);
    }
}
