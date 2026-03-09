#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

# ------------------------------------------------------------------------------------------------

if [ -z "${ORACLE_HOME:-}" -a -z "${cfg_oracle_home:-}" ] ; then
	ThrowException 'Neither the ORACLE_HOME env. var. nor the "cfg_oracle_home" config var. is set'
fi

export ORACLE_HOME="${ORACLE_HOME:-${cfg_oracle_home}}"

if [ ${OStype} = "cygwin" -o ${OStype} = "mingw" ] ; then
	export ORACLE_HOME=$( EchoPathUnixToWin "${ORACLE_HOME}" )
fi

InfoMessage "        Oracle home in use = \"${ORACLE_HOME}\""

l_oracle_bin_path=$( EchoPathWinToUnix "${ORACLE_HOME}" )
if [ ! -f "${l_oracle_bin_path}/sqlplus" -a ! -f "${l_oracle_bin_path}/sqlplus.exe" ] ; then
	l_oracle_bin_path=$( EchoPathWinToUnix "${ORACLE_HOME}" )/bin
fi

SqlPlusBinary="${l_oracle_bin_path}/sqlplus"
[ -f "${SqlPlusBinary}.exe" ] && SqlPlusBinary="${SqlPlusBinary}.exe"
InfoMessage "        SQL*Plus binary = \"${SqlPlusBinary}\""
[ -f "${SqlPlusBinary}" ] || ThrowException "SQL*Plus binary not accessible"

SqlLoaderBinary="${l_oracle_bin_path}/sqlldr"
[ -f "${SqlLoaderBinary}.exe" ] && SqlLoaderBinary="${SqlLoaderBinary}.exe"
InfoMessage "        SQL*Loader binary = \"${SqlLoaderBinary}\""
[ -f "${SqlLoaderBinary}" ] || InfoMessage "            Warning: SQL*Loader binary not accessible"

export gOracle_dbDefinesScriptFile="${TmpPath}/${gx_Env}.deployment_db_defines.${RndToken}.tmp"
InfoMessage "        SQL*Plus defines file = \"${gOracle_dbDefinesScriptFile}\""

# ----------------------------------------------------------------------------------------------

InfoMessage "        setting up API"

function Tech_OracleSqlPlus_GetConnectString()
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
	if [ "${x_target_id}" = "!deploy_repo!" ] ; then
		local l_db_user_var=deploy_repo_user
		local l_db_proxy_var=deploy_repo_proxy
		local l_db_password_var=deploy_repo_password
		local l_db_db_var=deploy_repo_db
		local l_db_as_sysdba=deploy_repo_as_sysdba
	else
		local l_db_user_var=dpltgt_${x_target_id}_user
		local l_db_proxy_var=dpltgt_${x_target_id}_proxy
		local l_db_password_var=dpltgt_${x_target_id}_password
		local l_db_db_var=dpltgt_${x_target_id}_db
		local l_db_as_sysdba=dpltgt_${x_target_id}_as_sysdba
	fi
	
	local l_db_user=${!l_db_user_var} || ThrowException "Config variable \"${l_db_user_var}\" not set"
	local l_db_proxy=${!l_db_proxy_var:=}
	local l_db_db=${!l_db_db_var} || ThrowException "Config variable \"${l_db_db_var}\" not set"
	local l_db_as_sysdba=${!l_db_as_sysdba:-no}

	local l_db_password=${!l_db_password_var} || local l_db_password=

	if [ -z "${l_db_password}" ] ; then
		if [ "${l_db_as_sysdba}" = "yes" ] ; then
			local l_password_prompt="${l_db_user}@${l_db_db} as sysdba"
		else if [ -n "${l_db_proxy:-}" ] ; then
			local l_password_prompt="${l_db_proxy}[${l_db_user}]@${l_db_db}"
		else
			local l_password_prompt="${l_db_user}@${l_db_db}"
		fi ; fi

		if [ "${x_target_id}" = "!deploy_repo!" ] ; then
			local l_password_prompt="    Enter password for ${l_password_prompt} (deployment repository): "
		else
			local l_password_prompt="            Enter password for ${l_password_prompt} (target ${x_target_id}): "
		fi

		read -s -r -p "${l_password_prompt}" l_db_password < /dev/tty > /dev/tty
		export ${l_db_password_var}=${l_db_password}
		echo ''
	fi

	if [ -z "${l_db_password}" ] ; then
		ThrowException "Config variable \"${l_db_password_var}\" not set"
	fi

	if [ "${x_pass_flag}" = "obfuscate-password" ] ; then
		local l_db_password="******"
	else
		local l_db_password=${!l_db_password_var}
	fi

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

InfoMessage "        done"
