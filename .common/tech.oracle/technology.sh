#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

x_action="$1"

case "$x_action" in
	(initialize)
		if [ -z "${ORACLE_HOME:-}" -a -z "${cfg_oracle_home:-}" ] ; then
			ThrowException 'Neither the ORACLE_HOME env. var. nor the "cfg_oracle_home" config var. is set'
		fi
		
		export ORACLE_HOME="${ORACLE_HOME:-${cfg_oracle_home}}"
		
		if [ ${OStype} = "cygwin" ] ; then
			export ORACLE_HOME=$( PathUnixToWin "${ORACLE_HOME}" )
		fi
		
		InfoMessage "        Oracle home in use = \"${ORACLE_HOME}\""
		
		export SqlPlusBinary=$( PathWinToUnix "${ORACLE_HOME}" )/bin/sqlplus
		InfoMessage "        SQL*Plus binary = \"${SqlPlusBinary}\""
		
		export gOracle_dbDefinesScriptFile="${TmpPath}/${Env}.deployment_db_defines.${RndToken}.sql"
		InfoMessage "        SQL*Plus defines file = \"${gOracle_dbDefinesScriptFile}\""
		
		set \
			| ${local_grep} -Ei '^dpltgt_' \
			| ${local_sed} 's/^dpltgt_\(.*\)\s*=\s*\(.*\)\s*$/define \1 = \2/g' \
			| ${local_sed} "s/= '\(.*\)'$/= \1/g" \
			>> "${gOracle_dbDefinesScriptFile}"
		
		InfoMessage "        done"
		;;

	(teardown)
		rm "${gOracle_dbDefinesScriptFile}"
		;;
esac
