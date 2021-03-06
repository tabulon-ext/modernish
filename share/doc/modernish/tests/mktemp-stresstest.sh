#! /usr/bin/env modernish
#! use safe -k
#! use sys/dir/countfiles
#! use sys/term/putr
#! use var/loop

# Stress test for atomicity of modernish' "mktemp" implementation.
# Try to create many temp files in parallel (default 400).
# See README.md under "Modules" -> "use sys/base/mktemp" for more info.
#
# This script deliberately uses weird characters (spaces, tabs, newlines)
# in the directory and file names to test for robustness on that, too.

showusage() {
putln "\
Usage:	${ME##*/} [ -dFi ] [ -L LENGTH ] [ -n NUMBER ]
	-d: test creating directories instead of regular files
	-F: test creating FIFOs instead of regular files
	-i: don't use /dev/urandom to generate suffixes, even if available
	-l (ell): list the temp files before cleanup
	-L LENGTH: set suffix length to LENGTH (min. 10, default 10)
	-n NUMBER: number of files to create in parallel, multiple of 4.
		Defaults to 400. NUMBER/4 parallel processes are forked."
}

# Parse options.
ftype=''
unset -v opt_i opt_l
opt_L=10
opt_n=400
while getopts 'dFilL:n:' opt; do
	case $opt in
	( d|F )	ftype=-$opt ;;
	( i )	opt_i= ;;
	( l )	opt_l= ;;
	( L )	opt_L=$OPTARG ;;
	( n )	opt_n=$OPTARG ;;
	( '?' )	exit -u 2 ;;
	( * )	thisshellhas BUG_GETOPTSMA && str eq $opt ':' && exit -u 2
		exit 3 'internal error' ;;
	esac
done
shift $((OPTIND - 1))

# Validate options and arguments.
str isint $opt_L && let "opt_L >= 0" || exit -u 2 '-L: invalid length: $opt_n'
str isint $opt_n && let "opt_n > 0" || exit -u 2 '-n: invalid number of files: $opt_n'
let "$# == 0" || exit -u 2 'excess arguments'

# Load the module with the mktemp function.
use sys/base/mktemp ${opt_i+-i}

# Make temp directory for temp files. Option -C does autocleanup on EXIT,
# SIGPIPE and SIGTERM, and warns user of files left on DIE and SIGINT.
mktemp -Csd /tmp/mktemp\ test${CCn}directory.XXXXXX
mydir=$REPLY

# Create suffix template: as many X'es as the length.
suffix_tmpl=$(putr $opt_L 'X')

# We make 4 files per parallel process, so constrain to multiple of 4.
let "opt_n=((opt_n+2)/4)*4"

# The stress test.
put "PIDs are:"
LOOP repeat opt_n/4; DO
	mktemp -sQ $ftype \
		$mydir/just${CCt}one\ test${CCn}file.$suffix_tmpl \
		$mydir/foo.$suffix_tmpl \
		$mydir/foo.$suffix_tmpl \
		$mydir/foo.$suffix_tmpl &
	put " $!"
DONE
putln '' "Waiting for these jobs to finish..."
wait

if not isset opt_i && not is -L charspecial /dev/urandom; then
	putln 'Note: this system does not have /dev/urandom; awk was used to generate suffixes.'
fi

# Check results.
countfiles -s $mydir
if isset opt_l; then
	(set -o xtrace; ls $mydir/)
fi
if let "REPLY == opt_n"; then
	putln "Succeeded: $REPLY files created. Cleaning up."
	# 'mktemp -C' will now automatically clean up on exit.
else
	die "Failed: $REPLY files created, should be $opt_n."
	# 'mktemp -C' will now show the directory that is left.
fi
