#!/bin/bash

[ -n "${g_LogFolder}" ] || g_LogFolder="${DeploySrcRoot}" || g_LogFolder=$( dirname "$0" )/log
[ -d "${g_LogFolder}" ] || mkdir "${g_LogFolder}"

LogFileStub="${LogFileStub:-run_deploy}"
LogFileName="${LogFileStub}."$( date +%Y%m%d )".log"

function DoLog()
{
	local LogTimeStamp=$( date "+%Y-%m-%d %H:%M:%S" )
	for param in "$@" ; do
		echo \[${LogTimeStamp}/$$\] "${param}" >> "${g_LogFolder}/${LogFileName}"
	done
}

function InfoMessage()
{
	echo "$*"
	DoLog "$*"
}

trap 'ThrowException "Uncaught exception!"' ERR
trap 'ThrowException "DB-deployer shell script KILLed"' KILL
trap 'ThrowException "DB-deployer shell script TERMed"' TERM

function ThrowException()
{
	local exitStatus=$?

	# display error
	echo ------------------------------------------------------------------------------
	echo ERROR IN $0 !
	for msg in "$@" ; do
		InfoMessage "${msg}"
	done
	InfoMessage "Command return code = ${exitStatus}"

	if [ -n "${ErrorNotificationMailRecipients:=}" ] ; then
		(
			echo ERROR IN $0 !
			for msg in "$@" ; do
				echo "${msg}"
			done
			echo Command return code = ${exitStatus}
		) | mailx -s "ERROR: DB deployment failure" -r ${ErrorNotificationMailSender+DBDeploy} ${ErrorNotificationMailRecipients}
	fi

	echo ------------------------------------------------------------------------------

	if [ ${exitStatus} -le 0 ] ; then
		exitStatus=254
	fi

	exit ${exitStatus}
}
