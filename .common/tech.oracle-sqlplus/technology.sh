#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

# ------------------------------------------------------------------------------------------------

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
		[ -f "${SqlPlusBinary}" -o -f "${SqlPlusBinary}.exe" ] || ThrowException "SQL*Plus binary not accessible"
		
		export SqlLoaderBinary=$( PathWinToUnix "${ORACLE_HOME}" )/bin/sqlldr
		InfoMessage "        SQL*Loader binary = \"${SqlLoaderBinary}\""
		[ -f "${SqlLoaderBinary}" -o -f "${SqlLoaderBinary}.exe" ] || InfoMessage "            Warning: SQL*Loader binary not accessible!"
		
		export gOracle_dbDefinesScriptFile="${TmpPath}/${gx_Env}.deployment_db_defines.${RndToken}.sql"
		InfoMessage "        SQL*Plus defines file = \"${gOracle_dbDefinesScriptFile}\""

		# ----------------------------------------------------------------------------------------------

		function tech-oracle-sqlplus-get_connect_string()
		{
			if bash__SupportsVariableReferences ; then
				declare -n o_result=$1
			else
				local o_result
			fi

			[ -n "${2:-}" ] || ThrowException "No target id supplied in call to tech-oracle-sqlplus-get_connect_string()"
			local x_target_id="$2"
			local x_pass_flag="${3:-}"

			# build the connection string
			local l_db_user_var=dpltgt_${x_target_id}_user
			local l_db_proxy_var=dpltgt_${x_target_id}_proxy
			local l_db_password_var=dpltgt_${x_target_id}_password
			local l_db_db_var=dpltgt_${x_target_id}_db
			local l_db_as_sysdba=dpltgt_${x_target_id}_as_sysdba

			local l_db_user=${!l_db_user_var} || ThrowException "Config variable \"${l_db_user_var}\" not set"
			local l_db_proxy=${!l_db_proxy_var:=}
			if [ "${x_pass_flag}" = "obfuscate-password" ] ; then
				local l_db_password="******"
			else
				local l_db_password=${!l_db_password_var} || ThrowException "Config variable \"${l_db_password_var}\" not set"
			fi
			local l_db_db=${!l_db_db_var} || ThrowException "Config variable \"${l_db_db_var}\" not set"
			local l_db_as_sysdba=${!l_db_as_sysdba:-no}

			if [ "${l_db_as_sysdba}" = "yes" ] ; then
				o_result="${l_db_user}/${l_db_password}@${l_db_db} as sysdba"
			else if [ -n "${l_db_proxy:-}" ] ; then
				o_result="${l_db_proxy}[${l_db_user}]/${l_db_password}@${l_db_db}"
			else
				o_result="${l_db_user}/${l_db_password}@${l_db_db}"
			fi ; fi

			if ! bash__SupportsVariableReferences ; then
				eval $1=\$o_result
			fi
		}

		# ----------------------------------------------------------------------------------------------

		set \
			| ${local_grep} -Ei '^dpltgt_' \
			| ${local_grep} -Evi '^dpltgt_[^=]*_password' \
			| ${local_sed} 's/^dpltgt_\(.*\)\s*=\s*\(.*\)\s*$/define \1 = \2/g' \
			| ${local_sed} "s/= '\(.*\)'$/= \1/g" \
			>> "${gOracle_dbDefinesScriptFile}"

		if [ "${DeployRepoTech}" = "oracle-sqlplus" ] ; then
			tech-oracle-sqlplus-get_connect_string gOracle_repoDbConnect deploy_repo
			tech-oracle-sqlplus-get_connect_string lOracle_repoDbConnectObfuscated deploy_repo obfuscate-password

			InfoMessage "        deployment repository connection = \"${lOracle_repoDbConnectObfuscated}\""
		fi
		
		InfoMessage "        done"
		;;

	(teardown)
		rm "${gOracle_dbDefinesScriptFile}"
		;;
esac
