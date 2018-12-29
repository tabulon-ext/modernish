#! test/for/moderni/sh
# See the file LICENSE in the main modernish directory for the licence.

# Regression tests related to (built-in) utilities of the shell.

doTest1() {
	title="options to 'command' can be expansions"
	v='-v'
	command $v : >/dev/null 2>&1
	case $? in
	( 0 )	mustNotHave BUG_CMDOPTEXP ;;
	# test suite runs with PATH=/dev/null, so we can rely on 127 = not found
	( 127 )	mustHave BUG_CMDOPTEXP ;;
	( * )	return 1 ;;
	esac
}

doTest2() {
	title="'command -v -p' searches default PATH"
	command -v -p chmod >/dev/null \
	&& command -v -p : >/dev/null
	e=$?
	case $e in
	( 0 )	mustNotHave BUG_CMDPV ;;
	( 1 | 127 )
		if ( eval '[[ ${.sh.version} == Version\ *\ 201?-??-?? ]]' ) 2>/dev/null; then
			xfailmsg='ksh intermittent -p bug'
			# ref.: https://github.com/att/ast/issues/426
			return 2
		fi
		mustHave BUG_CMDPV ;;
	( * )	failmsg="e = $e"
		return 1 ;;
	esac
}

doTest3() {
	title="'command' stops special builtins exiting"
	v=$(	readonly v=foo
		exec 2>/dev/null
		# All the "special builtins" below should fail, and not exit, so 'putln ok' is reached.
		# Ref.: http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html
		# Left out are 'command exec /dev/null/nonexistent', where no shell follows the standard,
		# 'command eval "("', where too many shells either exit on syntax error or become crash-prone,
		# as well as 'command exit' and 'command return', because, well, obviously.
		command : </dev/null/nonexistent
		command . /dev/null/nonexistent
		command export v=baz
		command readonly v=bar
		command set +o bad@option
		command shift $(($# + 1))
		command times foo bar >/dev/null
		command trap foo bar baz quux
		command unset v
		if not thisshellhas QRK_BCDANGER; then
			command break
			command continue
		fi
		putln ok)
	case $v in
	( ok )	mustNotHave BUG_CMDSPEXIT ;;
	( '' )	mustHave BUG_CMDSPEXIT ;;
	( * )	return 1 ;;
	esac
}

doTest4() {
	title="'command -v' finds reserved words"
	v=$(command -v until)
	case $v in
	( until )
		mustNotHave BUG_CMDVRESV ;;
	( '' )	mustHave BUG_CMDVRESV ;;
	( * )	return 1 ;;
	esac
}

doTest5() {
	title="'break' works from within 'eval'"
	(
		for v in 0 1 2; do
			eval "v=OK${CCn}break${CCn}v=FreeBSDvariant" 2>/dev/null
			exit 13
		done
		identic $v OK && exit 42
	)
	case $? in
	( 42 )	mustNotHave BUG_EVALCOBR ;;
	( * )	mustHave BUG_EVALCOBR ;;
	esac
}

doTest6() {
	title="'continue' works from within 'eval'"
	(
		for e in 1 2 42; do
			eval "v=OK${CCn}continue${CCn}v=FreeBSDvariant" 2>/dev/null
			break
		done
		identic $v OK && exit $e
	)
	case $? in
	( 42 )	mustNotHave BUG_EVALCOBR ;;
	( * )	mustHave BUG_EVALCOBR ;;
	esac
}

doTest7() {
	title="\$LINENO works from within 'eval'"
	if not thisshellhas LINENO; then
		skipmsg='no LINENO'
		return 3
	fi
	v=$LINENO; eval "${CCn}x=\$LINENO${CCn}y=\$LINENO${CCn}z=\$LINENO${CCn}"
	if let "y == x + 1 && z == y + 1"; then
		mustNotHave BUG_LNNOEVAL
	elif let "x == v && y == v && z == v"; then
		mustNotHave BUG_LNNOEVAL && okmsg='no increment'
	elif let "x == 0 && y == 0 && z == 0"; then
		mustHave BUG_LNNOEVAL
	else
		failmsg="x==$x; y==$y; z==$z"
		return 1
	fi
}

doTest8() {
	title="\$LINENO works within alias expansion"
	if not thisshellhas LINENO; then
		skipmsg='no LINENO'
		return 3
	fi
	alias _util_test8="${CCn}x=\$LINENO${CCn}y=\$LINENO${CCn}z=\$LINENO${CCn}"
	# use 'eval' to force immediate alias expansion in function definition
	eval 'testFn() {
		_util_test8
	}'
	testFn
	unalias _util_test8
	unset -f testFn
	if let "y == x + 1 && z == y + 1"; then
		mustNotHave BUG_LNNOALIAS
	elif let "x == 0 && y == 0 && z == 0"; then
		mustHave BUG_LNNOALIAS
	elif let "y == x && z == y"; then
		mustNotHave BUG_LNNOALIAS && okmsg='no increment'
	else
		failmsg="x==$x; y==$y; z==$z"
		return 1
	fi
}

doTest9() {
	title="'export' can export readonly variables"
	v=$(
		msh_util_test9=ok
		readonly msh_util_test9
		export msh_util_test9 2>/dev/null
		if isset -o xtrace && thisshellhas BUG_XTRCREDIR; then
			set +o xtrace
		fi
		PATH=$DEFPATH $MSH_SHELL -c 'echo "$msh_util_test9"' 2>&1
	)
	case $v in
	( ok )	mustNotHave BUG_NOEXPRO ;;
	( '' )	mustHave BUG_NOEXPRO ;;
	( * )	return 1 ;;
	esac
}

doTest10() {
	title="shell options w/o ltrs don't affect \${-}"
	if not thisshellhas -o nolog; then
		skipmsg='no nolog option'
		return 3
	fi
	(
		set -C -o nolog
		v=abc${-}def${-}ghi
		set +o nolog
		identic $v abc$-def$-ghi
	) || mustHave BUG_OPTNOLOG
}

doTest11() {
	title="long option names case-sensitive?"
	if thisshellhas BUG_CMDSPEXIT; then
		(set +o nOgLoB +o NoUnSeT +o nOcLoBbEr) 2>/dev/null
	else
		push -o nOgLoB -o NoUnSeT -o nOcLoBbEr
		command set +o nOgLoB +o NoUnSeT +o nOcLoBbEr 2>/dev/null
		pop --keepstatus -o nOgLoB -o NoUnSeT -o nOcLoBbEr
	fi
	case $? in
	( 0 )	mustHave QRK_OPTCASE && okmsg="they're not ($okmsg)" ;;
	( * )	mustNotHave QRK_OPTCASE && okmsg="they are" ;;
	esac
}

doTest12() {
	title="long option names sensitive to '_'?"
	if thisshellhas BUG_CMDSPEXIT; then
		(set +o nog_lob +o no_un__s_e__t +o nocl___obbe_r) 2>/dev/null
	else
		push -o nog_lob -o no_un__s_e__t -o nocl___obbe_r
		command set +o nog_lob +o no_un__s_e__t +o nocl___obbe_r 2>/dev/null
		pop --keepstatus -o nog_lob -o no_un__s_e__t -o nocl___obbe_r
	fi
	case $? in
	( 0 )	mustHave QRK_OPTULINE && okmsg="they're not ($okmsg)" ;;
	( * )	mustNotHave QRK_OPTULINE && okmsg="they are" ;;
	esac
}

doTest13() {
	title="long option names sensitive to '-'?"
	if thisshellhas BUG_CMDSPEXIT; then
		(set +o nog-lob +o no-un--s-e--t +o nocl---obbe-r) 2>/dev/null
	else
		push -o nog-lob -o no-un--s-e--t -o nocl---obbe-r
		command set +o nog-lob +o no-un--s-e--t +o nocl---obbe-r 2>/dev/null
		pop --keepstatus -o nog-lob -o no-un--s-e--t -o nocl---obbe-r
	fi
	case $? in
	( 0 )	mustHave QRK_OPTDASH && okmsg="they're not ($okmsg)" ;;
	( * )	mustNotHave QRK_OPTDASH && okmsg="they are" ;;
	esac
}

doTest14() {
	title="long options have dynamic 'no' prefix?"
	if (set +o nonotify +o noallexport -o exec -o glob -o noerrexit) 2>/dev/null; then
		mustHave OPTNOPREFIX
	else
		mustNotHave OPTNOPREFIX
	fi
}

doTest15() {
	title="xtrace is not redirected by simple redir"
	v=$(	PATH=$DEFPATH
		PS4='BUG_XTRCREDIR:'
		exec 2>/dev/null
		set -x
		exec sh -c 'echo OK' 2>&1
	)
	case $v in
	( OK )	mustNotHave BUG_XTRCREDIR ;;
	( BUG_XTRCREDIR:exec\ sh\ -c\ *echo\ OK*${CCn}OK )
		mustHave BUG_XTRCREDIR ;;
	( * )	return 1 ;;
	esac
}

doTest16() {
	title="'set' in function outputs global vars"
	thisshellhas LOCALVARS && local foo=BUG_SETOUTVAR
	v=$(set)
	case $v in
	( testscript=* | *${CCn}testscript=* )
		mustNotHave BUG_SETOUTVAR ;;
	( foo=*BUG_SETOUTVAR* )
		thisshellhas LOCALVARS && mustHave BUG_SETOUTVAR ;;
	( '' )	not thisshellhas LOCALVARS && mustHave BUG_SETOUTVAR ;;
	( * )	return 1 ;;
	esac
}

doTest17() {
	title="'command exec' fails without exiting"
	# check correct BUG_CMDEXEC detection
	(
		fn() {
			command exec 5>&6 || command exec 1>&1
		}
		# Another effect of BUG_CMDEXEC is that an explicit 'exit'
		# makes the subshell hang, so avoid that and use 'setstatus'.
		if ! fn one two three 2>/dev/null 5>&- 6>&-; then
			setstatus 112
		elif identic $#,${1-},${2-},${3-} 3,one,two,three; then
			setstatus 111
		elif ne $# 0; then
			setstatus 113
		fi
	)
	case $? in
	( 0 )	mustNotHave BUG_CMDEXEC ;;
	( 111 )	mustHave BUG_CMDEXEC ;;
	( 112 )	failmsg=FNFAIL; return 1 ;;
	( 113 )	failmsg=PPFAIL; return 1 ;;
	( * )	return 1 ;;
	esac
}

doTest18() {
	title="'command .' fails without exiting"
	# On dash < 0.5.7, trying to launch a nonexistent command from a dot script sourced with 'command .' causes program
	# flow corruption. The nonexistent command causes it to return from the dot script with a nonzero exit status (so
	# 'putln COR' is executed), then it continues where it left off in the dot script (executing 'putln end').
	# Also, triggering the bug makes the shell very likely to hang, so test it in a subshell (command substitution).
	v=$(	umask 022 &&
		putln >$testdir/command_dot.sh '/dev/null/ne 2>/dev/null' 'putln end' &&
		command . "$testdir/command_dot.sh" || putln COR )
	case $v in
	( end )	;;
	( COR${CCn}end )  # dash < 0.5.7
		failmsg="flow corrupt"; return 1 ;;
	( '' )	# No known variant of BUG_CMDSPEXIT causes 'command .' to exit on failure.
		failmsg="exits"; return 1 ;;
	( * )	shellquote v; failmsg="new bug: $v"; return 1 ;;
	esac
}


doTest19() {
	title="'command -v' is quiet on not found"
	# This fails on bash < 3.1.0.
	v=$(command -v /dev/null/nonexistent 2>&1)
	empty $v
}

lastTest=19
