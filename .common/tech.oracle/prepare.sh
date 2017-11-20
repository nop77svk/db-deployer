#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

if [ ${OStype} = "cygwin" ] ; then
	export ORACLE_HOME=$( PathUnixToWin "${ORACLE_HOME}" )
fi

export SqlPlusBinary=$( PathWinToUnix "${ORACLE_HOME}" )/bin/sqlplus
