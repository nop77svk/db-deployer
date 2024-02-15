#!/bin/bash

OStype=$( nop77svk__EchoGnuSubsystemId )

if [ ${OStype} = "SunOS" ] ; then
	local_find=/usr/xpg4/bin/find
	local_gawk=/usr/xpg4/bin/awk
	local_grep=/usr/xpg4/bin/grep
	local_sed=/usr/xpg4/bin/sed
	local_sort=/usr/xpg4/bin/sort
else if [ ${OStype,,} = "cygwin" -o ${OStype,,} = "mingw" -o ${OStype,,} = "linux" ] ; then
	local_find=/bin/find
	local_gawk=/bin/gawk
	local_grep=/bin/grep
	local_sed=/bin/sed
	local_sort=/bin/sort
else
	ThrowException "OS-specific utils for OS type \"${OStype}\" not implemented"
fi ; fi

[ -f "${local_find}" -o -f "${local_find}.exe" ] || ThrowException "FIND command not accessible"
[ -f "${local_gawk}" -o -f "${local_gawk}.exe" ] || ThrowException "GAWK command not accessible"
[ -f "${local_grep}" -o -f "${local_grep}.exe" ] || ThrowException "GREP command not accessible"
[ -f "${local_sed}" -o -f "${local_sed}.exe" ] || ThrowException "SED command not accessible"
[ -f "${local_sort}" -o -f "${local_sort}.exe" ] || ThrowException "SORT command not accessible"
