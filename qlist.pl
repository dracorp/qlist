#!/usr/bin/env perl
#===============================================================================
#       AUTHOR: Piotr Rogoza (dracorp), piotr.r.public@gmail.com
#         DATE: $Date: Wed Jan 21 18:48:59 2015 +0100 $
#     REVISION: $Revision: 21 $
#           ID: $Id: qlist.pl 21 Wed Jan 21 18:48:59 2015 +0100 Piotr Rogoza $
#===============================================================================

use strict;
use warnings;

use English '-no_match_vars';
use Carp;                               # to replace die & warn by croak & carp

use Getopt::Long;
Getopt::Long::Configure('bundling');    # grouping options
use Readonly;
use Term::ANSIColor;

# About the program
my $NAME        = 'qlist';
my $AUTHOR      = 'Piotr Rogoza';
our $VERSION    = 1.6.0;

# Global read-only variables
Readonly my $SPACE => q{ };
Readonly my $TAB   => qq{\t};

# Startup options
my (%options);
#{{{ Subroutines
sub usage { #{{{2
#===  FUNCTION  ================================================================
#         NAME: usage
#      PURPOSE: Display POD usage for the program
#===============================================================================
    system("pod2usage $PROGRAM_NAME");
} # end of sub usage }}}
sub help { #{{{2
#===  FUNCTION  ================================================================
#         NAME: help
#      PURPOSE: Display POD help for the program and exit with 0
#===============================================================================
    system("pod2text $PROGRAM_NAME");
    exit 0;
} # end of sub help }}}
sub filter_list { #{{{2
    #===  FUNCTION  ================================================================
    #         NAME:  filter_list
    #  DESCRIPTION:  Filters array acording with built-in patterns
    #===============================================================================
    my ( $pattern, $list_files_ref ) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak qq{Expected references to array\n};
    }

    #-------------------------------------------------------------------------------
    #  Built-in patterns
    #  Modify if you think fit it
    # -------------------------------------------------------------------------------
    my $binary  = qr{s?bin/|program/};
    my $man     = qr{man/?};
    my $doc     = qr{doc/};
    my $info    = qr{info/};
    my $etc     = qr{etc/};
    my $locale  = qr{locale/};
    my $picture = qr{\.png|\.xpm|\.svg|icons/|\.jpe?g|pixmaps/};
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
    } # end else [ if ( $options{other} )]
    if ($regex) {
        if ( $options{other} ) {

            # filters list basis of option other, everything else which not pass to built-in patterns
            @{$list_files_ref} = grep { !/$regex/msx } @{$list_files_ref};
        }
        else {

            # filters list basis of built-in patterns
            @{$list_files_ref} = grep {/$regex/msx} @{$list_files_ref};
        }
    } # end if ($regex)
    if ( $pattern and not $options{grep} ) {

        # if given pattern to find and no given -g option
        @{$list_files_ref} = grep {/$pattern/} @{$list_files_ref};
    } # end if ( $pattern and not ...)

    # remove empty directories unless given --all option
    if ( !$options{all} ) {
        remove_empty_directories($list_files_ref);
    }

    return;
} # end sub filtelist_files_ref }}}
sub print_list { #{{{2
    #===  FUNCTION  ================================================================
    #         NAME:  print_list
    #  DESCRIPTION:  Prints list with optional colors
    #===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak q{Expected references to array}, "\n";
    }
    for my $file ( @{$list_files_ref} ) {

        print color 'bold white' if $options{color};
        print $file, "\n";
        print color 'reset' if $options{color};
    }
    return;
} # end print_list }}}
sub generate_list_aix { #{{{2
#===  FUNCTION  ================================================================
#         NAME: generate_list_aix
#   PARAMETERS: package name
#      RETURNS: ????
#  DESCRIPTION: Generate list of files that belong to a package for AIX systems
#===============================================================================
    my ($package) = @_;

    if ( !$package ) {
        usage;
        exit 1;
    }
    my $list_files_ref = [];

    #rpm
    system "rpm -q $package > /dev/null 2>&1";
    if ( $? >> 8 != 0 ) {
        die "The package $package not found.\n";
    }
    open my ($fh), q{-|}, "rpm -ql $package"
        or croak qq{Cann't execute rpm: $ERRNO};
    @{$list_files_ref} = <$fh>;
    close $fh or croak qq{Cann't close rpm: $ERRNO};
    #lslpp
} # end of sub generate_list_aix }}}
sub generate_list_arch { #{{{2
#===  FUNCTION  ================================================================
#         NAME: generate_list_arch
#   PARAMETERS: package naem
#      RETURNS: ref to list
#  DESCRIPTION: Generate list of files that belong to a package for ArchLinux systems
#===============================================================================

    my ($package) = @_;
    if ( !$package ) {
        usage;
        exit 1;
    }
    my $list_files_ref = [];

    # remove leadeing 'local/' from name
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
        # remove package's name and spaces
        $filename =~ s{^\S+\s+}{}xms;
    }
    return $list_files_ref;
} # end generate_list_arch }}}
sub generate_list_debian { #{{{2
#===  FUNCTION  ================================================================
#         NAME: generate_list_debian
#   PARAMETERS: package naem
#      RETURNS: ref to list
#  DESCRIPTION: Generate list of files that belong to a package for Debian systems
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
    # remove first element equal '/.'
    shift @{$list_files_ref};
    @{$list_files_ref} = map { my $tmp = $_; chomp $tmp; $tmp } @{$list_files_ref};
    return $list_files_ref;
} # end generate_list_debian }}}
sub generate_list_linuxmint { #{{{2
#===  FUNCTION  ================================================================
#         NAME: generate_list_debian
#   PARAMETERS: package naem
#      RETURNS: ref to list
#  DESCRIPTION: Generate list of files that belong to a package for LinuxMint systems
#===============================================================================
    generate_list_debian(@_);
} # end of sub generate_list_linuxmint }}}
sub remove_empty_directories { #{{{2
#===  FUNCTION  ================================================================
#         NAME:  remove_empty_directories
#   PARAMETERS:  ref to array
#  DESCRIPTION:  Removes empty directories from list
#===============================================================================
    my ($list_files_ref) = @_;
    if ( ref $list_files_ref ne 'ARRAY' ) {
        croak qq{Expected references to array\n};
    }
    for my $count ( reverse 0 .. $#{$list_files_ref} ) {
        # chomp ${$list_files_ref}[$count];
        if ( -d ${$list_files_ref}[$count] ) {
            # remove directories from list
            splice @{$list_files_ref}, $count, 1;
        }
    }
    return;
} # end remove_empty_directories }}}
sub grep_list { #{{{2
#===  FUNCTION  ================================================================
#         NAME: grep_list
#   PARAMETERS: pattern, ref to array
#  DESCRIPTION: search in file list for a pattern
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
                } # end if ( $row =~ m{$pattern})
            }
            close $fh
                or croak q{Couldn't close the file: }, $file, "\n";
        } # end if ( -T $file && -r $file)
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
} # end sub grep_list }}}
#}}}
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
    'o|os=s'           => \$options{os},
    'h|help'           => \$options{help},
)
    or usage and exit;
#-------------------------------------------------------------------------------
#  Main program
#-------------------------------------------------------------------------------
if ( $options{help} ){
    help;
    exit;
}
unless ( @ARGV ){
    usage;
    exit;
}
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
} # end if ($rawpackage)

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
} # end if ($rawgrep_pattern)

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
} # end if ($rawpattern)

if(!$options{os}){
    require Linux::Distribution;
    Linux::Distribution->import(qw(distribution_name));
}
# Take distribution name from command line
my $distribution_name;
# sub from Linux::Distribution
my $distribution_sub = \&{'distribution_name'};
if ( $options{os} ){
    $distribution_name = lc $options{os};
}
# or find
elsif ( exists &$distribution_sub ){
    $distribution_name = &$distribution_sub;
}

if ( !$distribution_name ) {
    print q{I don't know this system}, "\n";
    exit 1;
}
$distribution_sub = \&{'generate_list_' . $distribution_name};
my $list_files       = [];                      # ref of array, list of files belong to package

if ( exists &$distribution_sub ) {
    $list_files = &$distribution_sub($package);
}
else {
    print q{I'm sorry but this system isn't supported}, "\n";
    exit 1;
}

if ( @{$list_files} > 0 ) {

    # filters list by built-in pattern
    filter_list( $pattern, $list_files );

    # search in content
    if ( $options{grep} ) {
        grep_list( $grep_pattern, $list_files );
    }
    else {
        print_list($list_files);
    }
} # end if ( @{$list_files} > ...)

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

As in Gentoo: You can give only fragment name of package and search in all matched

=head1 AUTHOR

Piotr Rogoza <piotr.r.public@gmail.com>

=cut
