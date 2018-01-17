#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

x_action="$1"
x_id_script="$2"
x_id_script_execution="$3"

case "${x_action}" in
	(run)
		x_schema_id="$4"
		x_script_folder="$5"
		x_script_file="$6"

		# build the connection string
		l_db_user_var=dpltgt_${l_schema_id}_user
		l_db_password_var=dpltgt_${l_schema_id}_password
		l_db_db_var=dpltgt_${l_schema_id}_db
		l_db_as_sysdba=dpltgt_${l_schema_id}_as_sysdba

		l_db_user=${!l_db_user_var}
		l_db_password=${!l_db_password_var}
		l_db_db=${!l_db_db_var}
		l_db_as_sysdba=${!l_db_as_sysdba:-no}

		if [ "${l_db_as_sysdba}" = "yes" ] ; then
			l_connect="${l_db_user}/${l_db_password}@${l_db_db} as sysdba"
		else
			l_connect="${l_db_user}/${l_db_password}@${l_db_db}"
		fi
		
		# determine the "defines" flag
		l_script_file_ext=${x_script_file##*.}
		case "${l_script_file_ext}" in
			pkg|spc|bdy|pck|pks|pkb|typ|tps|tpb|trg|fnc|prc)
				l_sqlplus_defines_flag=off
				;;
			*)
				l_sqlplus_defines_flag=on
				;;
		esac

		# execute the script
		cat > "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF
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

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

			col "It's ..." format a40
			select user||'@'||global_name as "It's ..." from global_name;

			prompt --- setting up deployment config vars

		EOF

		echo '@@"'$( PathUnixToWin "${gOracle_dbDefinesScriptFile}" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

		# add "default" schema defines
#		echo '' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
#		cat "${gOracle_dbDefinesScriptFile}" \
#			| ${local_gawk} -v "schemaId=${l_schema_id}" '
#				BEGIN {
#					schemaIdLen = length(schemaId);
#				}
#
#				substr($0, 1, schemaIdLen+1+7) == "define " schemaId "_" {
#						print "define default_" substr($0, schemaIdLen+2+7);
#					}
#			' \
#			>> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

			prompt --- turning SQL*Plus defines "${l_sqlplus_defines_flag}"
			set define ${l_sqlplus_defines_flag}

			prompt --- running the script "${x_script_folder}/${x_script_file}" (ID "${x_id_script}", execution ID "${x_id_script_execution}")

		EOF

		echo '@@"'$( PathUnixToWin "${DeploySrcRoot}/${x_script_folder}/${x_script_file}" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

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

		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" )
		"${SqlPlusBinary}" -L -S /nolog @"${l_sqlplus_script_file}" \
			2> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
			|| scriptReturnCode=$?

		return ${scriptReturnCode}
		;;

	(post-run-check)
		l_lines_OK=$(
			${local_grep} -Ei \
				"^(it's\s*\.\.\.|---\s*(setting\s+up\s+deployment\s+config\s+vars\s*$|turning\s+sql\*plus\s+defines|running\s+the\s+script|done\s*$))" \
				"${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" \
				| wc -l
		) || ThrowException "Spool file missing?"

		[ "$l_lines_OK" -eq 5 ] || ThrowException "Incomplete script execution! Trailing slash missing?"
		;;

	(cleanup)
		rm "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out"
		rm "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
		;;

	(*)
		ThrowException "Unmatched action \"${x_action}\""
esac
