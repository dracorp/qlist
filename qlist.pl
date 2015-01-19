#!/usr/bin/env perl
#===============================================================================
#         FILE:  qlist.pl
#
#        USAGE:  ./qlist.pl package pattern [options]
#
#   DESCRIPTION: Lists content of package and filters with buil-in input pattern.
#               Based on qlist from Gentoo package app-portage/portage-utils
#
#       AUTHOR: Piotr Rogoża (dracorp), piotr.r.public@gmail.com
#           Id: $Id$
#         Date: $Date$
#     Revision: $Revision$
#===============================================================================

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;


use strict;
use warnings;
use v5.10;

use English '-no_match_vars';
use Carp;                               # to replace die & warn by croak & carp

use Linux::Distribution qw(distribution_name);
use Getopt::Long;
Getopt::Long::Configure('bundling');    # grouping options
use Readonly;
use Term::ANSIColor;

# About the program
my $NAME   = 'qlist';
my $AUTHOR = 'Piotr Rogoża';
my $EMAIL  = 'piotr.r.public@gmail.com';

our $VERSION = 1.6.0;

# Global read-only variables
Readonly my $SPACE => q{ };
Readonly my $TAB   => qq{\t};

sub error {
    my ($ERROR) = @_;
    say "$PROGRAM_NAME $ERROR";
    say "Try `$PROGRAM_NAME --help' for more information.";
    exit 1;
}
# Startup options
my (%options);
GetOptions(
    'b|bin'            => \$options{binary},     # list binary
    'm|man'            => \$options{man},        # list pages' man
    'd|doc'            => \$options{doc},        # list doc
    'i|info'           => \$options{info},       # list pages' info
    'e|etc'            => \$options{etc},        # list /etc
    'l|locale'         => \$options{locale},     # list locales
    'p|picture'        => \$options{picture},    # list pictures
    'o|other'          => \$options{other},      # list other, not matched to above
    'g|grep=s'         => \$options{grep},       # search in contents of files
    'no-color|nocolor' => \$options{nocolor},    # do not color matched
    'c|color'          => \$options{color},      # colors matched
    'case'             => \$options{case},       # do not ignore case letter
    'all'              => \$options{all},        # print all, by default omit directories
    'h|help'           => \&help
) or die("Error in command line arguments. Try $PROGRAM_NAME --help");
#{{{  Functions
sub max_length_str {                             #{{{
    my ($array_ref) = @_;
    my $max_length = 0;
    foreach my $string ( @{$array_ref} ) {
        if ( length $string > $max_length ) {
            $max_length = length $string;
        }
    }
    return $max_length;
} ## end sub max_length_str }}}

sub usage {
    system("pod2usage $PROGRAM_NAME");
}

sub help {
    system("pod2text $PROGRAM_NAME");
    exit 0;
}

sub filter_list {    #{{{
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
        $regex = $binary . q{|} . $man . q{|} . $doc . q{|} . $info . q{|} . $etc . q{|} . $locale . q{|} . $picture;
    }
    else {
        if ( $options{binary} ) {
            $regex = $regex ? $regex . q{|} . $binary : $binary;
        }
        if ( $options{man} ) {
            $regex = $regex ? $regex . q{|} . $man : $man;
        }
        if ( $options{doc} ) {
            $regex = $regex ? $regex . q{|} . $doc : $doc;
        }
        if ( $options{info} ) {
            $regex = $regex ? $regex . q{|} . $info : $info;
        }
        if ( $options{etc} ) {
            $regex = $regex ? $regex . q{|} . $etc : $etc;
        }
        if ( $options{locale} ) {
            $regex = $regex ? $regex . q{|} . $locale : $locale;
        }
        if ( $options{picture} ) {
            $regex = $regex ? $regex . q{|} . $picture : $picture;
        }
    } ## end else [ if ( $options{other} )]
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
    } ## end if ($regex)
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
    } ## end if ( $pattern and not ...)

    # usuń puste katalogi chyba, że podano opcję --all
    if ( !$options{all} ) {
        remove_empty_directories($list_files_ref);
    }

    return;
} ## end sub filtelist_files_ref }}}

sub print_list {    #{{{
    #===  FUNCTION  ================================================================
    #         NAME:  print_list
    #  DESCRIPTION:  Drukuje na ekranie tablicę, ewentualnie dodaje kolory itp
    #===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak q{Expected references to array}, "\n";
    }
    for my $file ( @{$list_files_ref} ) {

        print color 'bold white' if $options{color};
        print $file;
        print color 'reset' if $options{color};
    }
    return;
} ## end print_list }}}

sub generate_list_arch {    #{{{
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
    if ( !$package ) {
        usage;
        exit 1;
    }
    my $list_files_ref = [];

    #usuń początkowe np. local/ z nazwy
    $package =~ s/^.*\///xms;
    system "/usr/bin/pacman -Qq $package > /dev/null 2>&1";
    if ( $? >> 8 != 0 ) {
        die "The package $package not found. Try use e.g. 'lspack $package' to search package\n";
    }
    open my ($fh), q{-|}, "/usr/bin/pacman -Ql $package"
        or croak qq{Cann't execute pacman: $ERRNO};
    @{$list_files_ref} = <$fh>;
    close $fh or croak qq{Cann't close pacman: $ERRNO};
    for my $filename ( @{$list_files_ref} ) {
        chomp $filename;
        $filename =~ s{^\S+\s+}{}xms;    # usuwa nazwę pakietu i spację
    }
    return $list_files_ref;
} ## end generate_list_arch }}}

sub generate_list_debian {               #{{{
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
    if ( !$package ) {
        die q{Packge dot defined}, "\n";
    }
    my $list_files_ref = [];
    system "/usr/bin/dpkg-query -W $package > /dev/null 2>&1";
    if ( $? >> 8 != 0 ) {
        die "Package $package not found. Try use lspack $package\n";
    }
    open my ($fh), q{-|}, "/usr/bin/dpkg -L $package"
        or croak qq{Cann't execute dpkg: $ERRNO\n};
    @{$list_files_ref} = <$fh>;
    close $fh or croak qq{Cann't close program dpkg: $ERRNO\n};
    shift @{$list_files_ref};    # usuń pierwszy element, równy '/.'
    @{$list_files_ref} = map { my $tmp = $_; chomp $tmp; $tmp } @{$list_files_ref};
    return $list_files_ref;
} ## end generate_list_debian }}}

sub generate_list_linuxmint {    #{{{
    generate_list_debian(@_);
}    #}}}

sub remove_empty_directories {    #{{{
    #===  FUNCTION  ================================================================
    #         NAME:  remove_empty_directories
    #   PARAMETERS:  odwołanie do tablicy
    #  DESCRIPTION:  usuwa puste katalogi z listy chyba że podano opcję --all
    #===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak qq{Expected references to array\n};
    }
    for my $count ( reverse 0 .. $#{$list_files_ref} ) {    # lecimy od końca

        #        chomp ${$list_files_ref}[$count];
        if ( -d ${$list_files_ref}[$count] ) {              # usuń z listy katalogi jeśli nie podano opcji --all
            splice @{$list_files_ref}, $count, 1;
        }
        else {
            ${$list_files_ref}[$count] .= "\n";
        }
    }
    return;
} ## end remove_empty_directories }}}

sub grep_list {                                             #{{{
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
        croak q{Wrong call sub grep_list, excepted form: pattern, file}, "\n";
    }
    if ( !ref $input_file_ref eq 'ARRAY' ) {
        croak q{Excepted ref to array as second parametr}, "\n";
    }
    my ($max_length_filename,    # max length of filename, for formated display
        $max_length_number,      # max length of number of row with matched pattern,
        $result,                 # ref to hash with results
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
                } ## end if ( $row =~ m{$pattern})
            }
            close $fh
                or croak q{Couldn't close the file: }, $file, "\n";
        } ## end if ( -T $file && -r $file)
    }
    my @files = keys %{$result};
    $max_length_filename++;    # for space
    $max_length_number++;      # for space and char '+'
    foreach my $filename ( keys %{$result} ) {
        foreach my $number_line ( keys %{ $result->{$filename} } ) {
            print color 'bold white' if $options{color};
            printf "%-$max_length_filename" . 's', "$filename";
            print color 'green' if $options{color};
            printf "%-$max_length_number" . 's', "+$number_line";
            print color 'reset' if $options{color};
            print $SPACE, $result->{$filename}->{$number_line}, "\n";
        }
    }
    return;
} ## end sub grep_list }}}
#}}}
#  Main program
my ( $package, $pattern, $grep_pattern );

# get name of package and optional pattern to filter list
my ( $rawpackage, $rawpattern ) = @ARGV;

# get grep_pattern
my $rawgrep_pattern;
$rawgrep_pattern = $options{grep} if $options{grep};

# untainted $package, $pattern and $grep_pattern
if ($rawpackage) {
    ($package) = $rawpackage =~ m{^[/\w._-]+}gxms;
    if ( !$package ) {
        print q{Package isn't defined or name you entered isn't allowed}, "\n";
        exit 1;
    }
} ## end if ($rawpackage)

if ($rawgrep_pattern) {
    ($grep_pattern) = $rawgrep_pattern =~ m{^[%_~\#\/\\|\w\s._-]+}gxms;
    if ( $options{case} ) {
        $grep_pattern = eval { qr{$grep_pattern}oxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
    else {
        $grep_pattern = eval { qr{$grep_pattern}ioxms; };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }
} ## end if ($rawgrep_pattern)

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
} ## end if ($rawpattern)

my $distribution_name = distribution_name;
if ( !$distribution_name ) {
    print q{I don't know this system}, "\n";
    exit 1;
}
my $distribution_sub = 'generate_list_' . $distribution_name;
my $list_files       = [];                                      # ref of array, list of files belong to package

if ( exists &$distribution_sub ) {
    {
        no strict 'refs';
        $list_files = &$distribution_sub($package);
    }
} ## end if ( exists &$distribution_sub)
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
} ## end if ( @{$list_files} > ...)

__END__

=pod

=encoding utf8

=head1 NAME

qlist - lists content of package

=head1 SYNOPSIS

B<qlist> [package] [pattern]
[B<-b|--bin>]
[B<-m|--man>]
[B<-d|--doc>]
[B<-i|--info>]
[B<-e|--etc>]
[B<-l|--locale>]
[B<-p|--picture>]
[B<-o|--other>]
[B<--all>]
[B<--case>]
[B<-g|--grep> I<pattern>]

[B<--no-color|--nocolor>]
[B<--color>]
[B<-h|--help>]

=head1 DESCRIPTION

I<qlist> lists content of a package on many Operating Systems. Originally was simple wrapper on I<qlist> program from Gentoo.
At the moment program lists content of a package and filter according with built-in or given pattern.
Built-in pattern become active through program's options. Options can group.

=head1 OPTIONS

=over 4

=item B<-b>, B<--bin>

Prints 'binary' files for pathes I<'s?bin/'>

=item B<-m>, B<--man>

Prints man pages, matched to I<'man/'>

=item B<-d>, B<--doc>

Prints documentation, matched to I<'doc/'>

=item B<-i>, B<--info>

Prints info pages, matched to I<'info/'>

=item B<-l>, B<--locale>

Prints locale's files, matched to I<'locale/'>

=item B<-p>, B<--picture>

Prints files ending on: .png .xpm .svg .icons .jpg and matched to 'picture'

=item B<-o>, B<--other>

Prints all files not matched to above patterns

=item B<-g> I<pattern>, B<--grep> I<patter>

Searches pattern in content of package's files, only ASCII

=item B<--no-color>, B<--nocolor>

Disable color

=item B<--color>

Surround the matched strings with  escape  sequences  to  display  them  in  color on the terminal.

=item B<--all>

By default program omit empty directories, with this option prints all.

=item B<--case>

Do not ignore case letter for patterns: package and grep.

=item B<-h>, B<--color>

Prints this help

=back

=head1 EXAMPLES

To display content of mc package:

    qlist mc

To search 'charset' pattern:

    qlist mc charset

To display installed man pages:

    qlist mc -m

=head1 SUPPORTED OS

I<qlist> was tested on Debian, Gentoo and Archlinux.

=head1 LICENSE AND COPYRIGHT

Program is distributed as-is

=head1 TODO

As in Gentoo: Pod gentoo wystarczy podać fragment nazwy pakietu i domyślnie wyszuka wśród wszystkich pasujących.

=head1 AUTHOR

Piotr Rogoża <piotr.r.public@gmail.com>

=cut
