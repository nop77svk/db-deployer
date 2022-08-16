#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

x_action="$1"

case "${x_action}" in
	(run)
		x_id_script="$2"
		x_id_script_execution="$3"

		x_target_id="$4"
		x_script_folder="$5"
		x_script_file="$6"

		Tech_OracleSqlPlus_GetConnectString l_connect "${x_target_id}"
		
		# determine the "defines" flag
		l_script_file_ext=${x_script_file##*.}
		case "${l_script_file_ext}" in
			pkg|spc|bdy|pck|pks|pkb|typ|tps|tpb|trg|fnc|prc)
				l_sqlplus_defines_flag=off
				;;
			ctl)
				l_sqlplus_defines_flag=-
				;;
			*)
				l_sqlplus_defines_flag=on
				;;
		esac

		# execute the script
		if [ "${l_script_file_ext}" = "ctl" ] ; then
			ln "${DeploySrcRoot}/${x_script_folder}/${x_script_file}" "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.ctl"
			"${SqlLoaderBinary}" \
				userid="${l_connect}" \
				control=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.ctl" ) \
				log=$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" ) \
				2>&1 \
				> "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
				|| scriptReturnCode=$?

		else
			cat > "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF
				whenever sqlerror exit 1 rollback
				whenever oserror exit 2 rollback

				-- phase: execution

				connect ${l_connect}

				set autoprint off
				set autotrace off
				set echo on
				set define on
				set escape off
				set feedback on
				set heading on
				set headsep on
				set linesize 32767
				set serveroutput on size unlimited format truncated
				set sqlbl on
				set sqlterminator ';'
				set termout off
				set trimout on
				set trimspool on
				set verify on
				set wrap on

				set exitcommit on

			EOF

			echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

			cat >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

				col "It's ..." format a40
				select user||'@'||global_name as "It's ..." from global_name;

				prompt --- setting up deployment config vars

			EOF

			echo '@"'$( EchoPathUnixToWin "${gOracle_dbDefinesScriptFile}" )'"' >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

			cat >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

				prompt --- turning SQL*Plus defines "${l_sqlplus_defines_flag}"
				set define ${l_sqlplus_defines_flag}

				prompt --- running the script "${x_script_folder}/${x_script_file}" (ID "${x_id_script}", execution ID "${x_id_script_execution}")

			EOF

			echo '@"'$( EchoPathUnixToWin "${DeploySrcRoot}/${x_script_folder}/${x_script_file}" )'"' >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

			cat >> "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

				set autoprint off
				set autotrace off
				set echo on
				set define on
				set escape off
				set feedback on
				set heading on
				set headsep on
				set linesize 32767
				set serveroutput on size unlimited format truncated
				set sqlbl on
				set sqlterminator ';'
				set termout off
				set trimout on
				set trimspool on
				set verify on
				set wrap on

				prompt --- DONE
				commit;

				spool off
				exit success
			EOF

			scriptReturnCode=0

			l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" )
			"${SqlPlusBinary}" -L -S /nolog @"${l_sqlplus_script_file}" \
				2> "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
				|| scriptReturnCode=$?

			l_lines_OK=$(
				${local_grep} -Ei \
					"^(it's\s*\.\.\.|---\s*(setting\s+up\s+deployment\s+config\s+vars\s*$|turning\s+sql\*plus\s+defines|running\s+the\s+script|done\s*$))" \
					"${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" \
					| wc -l
			) || ThrowException "Spool file missing?"

			[ "$l_lines_OK" -eq 5 ] || ThrowException "Incomplete script execution! Trailing slash missing?"
		fi

		return ${scriptReturnCode}
		;;

	(cleanup)
		x_id_script="$2"
		x_id_script_execution="$3"

		rm "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out"
		rm -f "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" 2> /dev/null
		rm -f "${TmpPath}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.ctl" 2> /dev/null
		;;

	(teardown)
		rm "${gOracle_dbDefinesScriptFile}"
		;;

	(*)
		ThrowException "Unmatched action \"${x_action}\""
esac
