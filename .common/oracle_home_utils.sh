#!/bin/bash

if [ ${OStype} = "cygwin" ] ; then
	ORACLE_HOME=$( PathUnixToWin "${ORACLE_HOME}" )
fi

SqlPlusBinary=$( PathWinToUnix "${ORACLE_HOME}" )/bin/sqlplus
