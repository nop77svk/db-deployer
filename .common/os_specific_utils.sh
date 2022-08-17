#!/bin/bash

l_uname="$(uname)"
if [[ "${l_uname,,}" =~ ^cygwin ]] ; then
	OStype=cygwin
else if [[ "${l_uname,,}" =~ ^linux ]] ; then
	OStype=linux
else if [[ "${l_uname,,}" =~ ^msys_nt- ]] ; then
	OStype=mingw
else if [ "${l_uname}" = "SunOS" ] ; then
	OStype=SunOS
else if [ "${OS:-??}" = "Windows_NT" ] ; then
	OStype=cygwin
else
	ThrowException "Unknown OS type! uname = \"$(uname)\", OS env var = \"${OS:-}\""
fi ; fi ; fi ; fi ; fi

# ------------------------------------------------------------------------------------------------

function bash__VersionIsAtLeast()
{
	local bashMajorVersion=${BASH_VERSION%%.*}
	local bashMinorVersion=${BASH_VERSION#*.}
	local bashMinorVersion=${bashMinorVersion%%.*}

	local targetMajorVersion=$1
	local targetMinorVersion=$2

	[ ${bashMajorVersion} -gt ${targetMajorVersion} -o ${bashMajorVersion} -eq ${targetMajorVersion} -a ${bashMinorVersion} -ge ${targetMinorVersion} ] \
		|| ThrowException "BASH version must be at least ${targetMajorVersion}.${targetMinorVersion}"
}

function bash__SupportsVariableReferences()
{
	bash__VersionIsAtLeast 4 3 || ThrowException "Variable references not supported in this BASH version"
}

# ------------------------------------------------------------------------------------------------

if [ ${OStype} = "SunOS" ] ; then
	local_find=/usr/xpg4/bin/find
	local_gawk=/usr/xpg4/bin/awk
	local_grep=/usr/xpg4/bin/grep
	local_sed=/usr/xpg4/bin/sed
	local_sort=/usr/xpg4/bin/sort
else if [ ${OStype} = "cygwin" -o ${OStpe} = "mingw" -o ${OStype} = "linux" ] ; then
	local_find=/bin/find
	local_gawk=/bin/gawk
	local_grep=/bin/grep
	local_sed=/bin/sed
	local_sort=/bin/sort
fi ; fi

[ -f "${local_find}" -o -f "${local_find}.exe" ] || ThrowException "FIND command not accessible"
[ -f "${local_gawk}" -o -f "${local_gawk}.exe" ] || ThrowException "GAWK command not accessible"
[ -f "${local_grep}" -o -f "${local_grep}.exe" ] || ThrowException "GREP command not accessible"
[ -f "${local_sed}" -o -f "${local_sed}.exe" ] || ThrowException "SED command not accessible"
[ -f "${local_sort}" -o -f "${local_sort}.exe" ] || ThrowException "SORT command not accessible"

# ------------------------------------------------------------------------------------------------

function CatPathUnixToWin()
{
	if [ ${OStype} = "cygwin" ] ; then
		${local_sed} 's/^\/cygdrive\/\([^\/]*\)/\1:/gi' | ${local_sed} 's/\//\\/g'
	else if [ ${OStype} = "mingw" ] ; then
		${local_sed} 's/^\/\([^\/]*\)/\1:/gi' | ${local_sed} 's/\//\\/g'
	else
		cat
	fi ; fi
}

function CatPathWinToUnix()
{
	if [ ${OStype} = "cygwin" ] ; then
		${local_sed} 's/\\/\//g' | ${local_sed} 's/^\([^\\]*\):/\/cygdrive\/\1/gi'
	else if [ ${OStype} = "mingw" ] ; then
		${local_sed} 's/\\/\//g' | ${local_sed} 's/^\([^\\]*\):/\/\1/gi'
	else
		cat
	fi ; fi
}

function EchoPathUnixToWin()
{
	if [ ${OStype} = "cygwin" -o ${OStype} = "mingw" ] ; then
		echo $1 | CatPathUnixToWin
	else
		echo $1
	fi
}

function EchoPathWinToUnix()
{
	if [ ${OStype} = "cygwin" -o ${OStype} = "mingw" ] ; then
		echo $1 | CatPathWinToUnix
	else
		echo $1
	fi
}
