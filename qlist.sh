#!/bin/sh
#===============================================================================
#
#          FILE:  qlist.wrapper.sh
#
#         USAGE:  ./qlist.wrapper.sh
#
#   DESCRIPTION:  Listuje zaswartość pakietu z możliwością wyszczególnienia plików pod względem manuali, dokumentacja, info, plików binarnych
#				Nakładka na program qlist z pakietu app-portage/portage-utils
# 				Jeśli za opcjami wystąpi jakiś wzorzec to bedzie on przeszukiwany pod względem obecności w nazwie plików.
#
#       OPTIONS:  package -b -m -d -i -e -h | szukany_wzorzec
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Piotr Rogoża (RP), rogoza.piotr@wp.eu
#       COMPANY:  dracoRP
#       VERSION:  1.3
#       CREATED:  03.09.2008 09:52:11 CEST
#      REVISION:  ---
#===============================================================================
NAME=qlist
FULLNAME="qlist wrapper"
#comment to not use lspack script to find all matches package
USELSPACKTOFIND=1
#comment to not use all matches packages to list contents
USELSPACK=1
#did not inform about the package not found
QUIET=1
GREP="grep --color=auto"
short_usage(){ #{{{
	echo -e "$NAME [package] -b -m -d -i -e -l -p -o -h -g patern"
} #}}}
usage(){ #{{{
	echo -e "\nDefault script $NAME lists package"
	echo "-b list binary files"
	echo "-m list manual's files"
	echo "-d list documentation's files"
	echo "-i list info's files"
	echo "-e list configuration files"
	echo "-l list locales"
	echo "-p list pictures, icons etc."
	echo "-o list other files not belong to earlier listed options"
	echo "-a list all packages pass to pattern, only debian"
	echo "-g search in files' contents (xargs grep)"
	echo "-h this help"
}	# ----------  end of function usage  ----------}}}
#{{{ Stałe dla regexa
BIN='bin/\|program/'
DOC='doc/'
INFO='info/'
MAN='man/'
ETC='etc/'
LOCALE='locale/'
PIC='\.png\|\.xpm\|\.svg\|icons/\|\.jpg'
ALL="$BIN\|$DOC\|$INFO\|$MAN\|$ETC\|$LOCALE\|$PIC"
#tutaj będą lądować powyższe zmienne w zależności od parametrów skryptu
REGEX=''
#szukane wyrażenie w wylistowanych plikach
SEARCH=''
#}}}
#{{{ Sprawdzenie parametrów
if [ $# -eq 0 ]; then
	short_usage
	exit
fi
#rozbicie parametrów na pojedyncze opcje i przepisanie do $*
PARAM="bmdielpoahgs:"
set -- `getopt $PARAM $*`
#{{{ wyłuskanie nazwy pakietu z lini polceń
#PACKAGE=`echo $* | sed -e 's/\ *-[0-9a-zA-Z]\+\ */\ /g' -e 's/^\ \+//g' -e 's/\ \+/\ /g' | awk '{print $2}'` #nazwa pakietu podana w lini poleceń
#SEARCH=`echo $* | sed -e 's/\ *-[0-9a-zA-Z]\+\ */\ /g' -e 's/^\ \+//g' -e 's/\ \+/\ /g' | awk '{print $3}'` #co ma wyszukać w plikach pakietu, zawsze jako drugie wyrażenie po nazwie pakietu
OPCJE=$(echo $* | awk -F'--' '{print $1}')
PACKAGE=$(echo $* | awk -F'--' '{print $2}' | awk '{print $1}')
SEARCH=$(echo $* | awk -F'--' '{print $2}' | awk '{print $2}')
#}}}
while getopts $PARAM OPT; do
		case $OPT in
			b)	bflag=1;;
			m)	mflag=1;;
			d)	dflag=1;;
			i)	iflag=1;;
			e)	eflag=1;;
			l)	lflag=1;;
			p)	pflag=1;;
			o)	oflag=1;;
			a) 	aflag=1;;
			g) 	gflag=1;;
			h)	short_usage; usage
			exit;;
			?)	echo "Unrecognized options, try -h"
			exit 1
		esac #case 
done #while
if [ -z "$PACKAGE" ]; then
	short_usage
	exit
fi
#}}}
#{{{ ustalenie względem czego mam listować pakiet
if [ -n "${bflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${BIN}"; fi
if [ -n "${mflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${MAN}"; fi
if [ -n "${dflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${DOC}"; fi
if [ -n "${iflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${INFO}"; fi
if [ -n "${eflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${ETC}"; fi
if [ -n "${lflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${LOCALE}"; fi
if [ -n "${pflag}" ]; then REGEX="${REGEX}${REGEX:+\|}${PIC}"; fi
#}}}
OS=`whichos`
case $OS in
	gentoo) #{{{
	#if [ -n "$nflag" ]; then #nie podano opcji po czym ma szukać: man, locale, doc itp.
	if [ -n "$oflag" ]; then
		if [ -n "$PACKAGE" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
			qlist $PACKAGE | grep -v "$ALL" | $GREP "$SEARCH"
		elif [ -n "$PACKAGE" -a -z "$SEARCH" ]; then #wyszukaj pakietu
			qlist $PACKAGE | grep -v "$ALL"
		fi
	else
		if [ -n "$PACKAGE" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
			qlist $PACKAGE | $GREP "$REGEX" | $GREP "$SEARCH"
		elif [ -n "$PACKAGE" -a -z "$SEARCH" ]; then  #wyszukaj pakietu
			qlist $PACKAGE | $GREP "$REGEX"
		fi
	fi
	;; #}}}
	debian) #{{{
	#wszystkie pakiety o wzorcu *$PACKAGE*
	if [ -n "$aflag" ]; then
		PACKAGE=`dpkg -l "*${PACKAGE}*" | grep '^ii' | awk '{print $2}'`
	fi
	for i in $PACKAGE; do
		echo -e "\n\033[1;32m$i\033[0m"
		if [ -n "$oflag" ]; then  #Wyszukiwanie w reszcie 
			if [ -n "$i" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
				dpkg -L $i | grep -v "$ALL" | $GREP "$SEARCH"
			elif [ -n "$i" -a -z "$SEARCH" ]; then #wyszukaj pakietu
				dpkg -L $i | grep -v "$ALL"
			fi
		else
			if [ -n "$i" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
				dpkg -L $i | $GREP "$REGEX" | $GREP "$SEARCH"
			elif [ -n "$i" -a -z "$SEARCH" ]; then  #wyszukaj pakietu
				dpkg -L $i | $GREP "$REGEX"
			fi
		fi
	done
	;; #}}}
	archlinux) #{{{
	PACKAGE=${PACKAGE#*/}
	pacman -Qq $PACKAGE &>/dev/null
	if (( $? )); then
		if [ -n "$USELSPACKTOFIND" -a -x "$(which lspack 2>/dev/null)" ]; then
			test -z "$QUIET" && echo -e "Package '$PACKAGE' not found, I will try to use script lspack to find all matches packages:\n"
			if [ -n "$USELSPACK" ]; then
				#wyszukaj wszystkie pasujace i listuj ich zawartość
				PACKAGES=$(lspack $PACKAGE)
				for i in $PACKAGES; do
					$0 $i $OPCJE ${SEARCH:+$SEARCH}
				done
			else
				echo -e "Package '$PACKAGE' not found, I will try to use script lspack to find all matches packages:\n"
				lspack $PACKAGE
			fi
		else
			echo "Package '$PACKAGE' not found, try script lspack to find all matches packages"
		fi
		exit
	else
		if [ -n "$oflag" ]; then
			if [ -n "$PACKAGE" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
				pacman -Ql $PACKAGE | awk '{print $2}' | grep -v '\/$' | $GREP -v "$ALL" | $GREP "$SEARCH"
			elif [ -n "$PACKAGE" -a -z "$SEARCH" ]; then #wyszukaj pakietu
				pacman -Ql $PACKAGE | awk '{print $2}' | grep -v '\/$' | $GREP -v "$ALL"
			fi
		else
			if [ -n "$PACKAGE" -a -n "$SEARCH" ]; then #wyszukaj pakietu i słowa w nazwach plików
				pacman -Ql $PACKAGE | awk '{print $2}'	| grep -v '\/$' | $GREP "$REGEX" | $GREP "$SEARCH"
			elif [ -n "$PACKAGE" -a -z "$SEARCH" ]; then  #wyszukaj pakietu
				pacman -Ql $PACKAGE | awk '{print $2}'	| grep -v '\/$' | $GREP "$REGEX"
			fi
		fi
	fi
	;; #}}}
	*)
	echo "Not supported yet"
esac
exit 0
