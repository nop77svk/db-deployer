#!/bin/bash

if [ "${OS:-??}" = "Windows_NT" ] ; then
	OStype=cygwin
else if [[ $(uname) =~ ^[Cc][Yy][Gg][Ww][Ii][Nn] ]] ; then
	OStype=cygwin
else if [ $(uname) = "SunOS" ] ; then
	OStype=SunOS
else
	ThrowException "Unknown OS type! uname = "$(uname)", OS env var = ${OS:-}"
fi ; fi ; fi


if [ ${OStype} = "SunOS" ] ; then
	local_find=/usr/xpg4/bin/find
	local_gawk=/usr/xpg4/bin/awk
	local_grep=/usr/xpg4/bin/grep
	local_sed=/usr/xpg4/bin/sed
	local_sort=/usr/xpg4/bin/sort
else if [ ${OStype} = "cygwin" ] ; then
	local_find=/bin/find
	local_gawk=/bin/gawk
	local_grep=/bin/grep
	local_sed=/bin/sed
	local_sort=/bin/sort
fi ; fi


function CatPathUnixToWin()
{
	if [ ${OStype} = "cygwin" ] ; then
		${local_sed} 's/^\/cygdrive\/\([^\/]*\)/\1:/gi' | ${local_sed} 's/\//\\/g'
	else
		cat
	fi
}

function CatPathWinToUnix()
{
	if [ ${OStype} = "cygwin" ] ; then
		${local_sed} 's/\\/\//g' | ${local_sed} 's/^\([^\\]*\):/\/cygdrive\/\1/gi'
	else
		cat
	fi
}

function PathUnixToWin()
{
	if [ ${OStype} = "cygwin" ] ; then
		echo $1 | CatPathUnixToWin
	else
		echo $1
	fi
}

function PathWinToUnix()
{
	if [ ${OStype} = "cygwin" ] ; then
		echo $1 | CatPathWinToUnix
	else
		echo $1
	fi
}
