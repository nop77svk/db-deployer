#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

x_action="$1"
x_rnd_token="$2"
x_id_script="$3"
x_id_script_execution="$4"

case "${x_action}" in
	(run)
		x_connect="$5"
		x_script_folder="$6"
		x_script_file="$7"
		x_db_defines_file="$8"
		x_sqlplus_defines_flag="$9"

		cat > "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback

			-- phase: execution

			connect ${x_connect}

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

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			col "It's ..." format a40
			select user||'@'||global_name as "It's ..." from global_name;

			prompt --- setting up deployment config vars

		EOF

		echo '@@"'$( PathUnixToWin "${x_db_defines_file}" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		# add "default" schema defines
#		echo '' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
#		cat "${x_db_defines_file}" \
#			| ${local_gawk} -v "schemaId=${l_schema_id}" '
#				BEGIN {
#					schemaIdLen = length(schemaId);
#				}
#
#				substr($0, 1, schemaIdLen+1+7) == "define " schemaId "_" {
#						print "define default_" substr($0, schemaIdLen+2+7);
#					}
#			' \
#			>> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		[ "${x_sqlplus_defines_flag}" = "N" ] && definesFlag=off || definesFlag=on

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			prompt --- turning SQL*Plus defines "${definesFlag}"
			set define ${definesFlag}

			prompt --- running the script "${x_script_folder}/${x_script_file}" (ID "${x_id_script}", execution ID "${x_id_script_execution}")

		EOF

		echo '@@"'$( PathUnixToWin "${DeploySrcRoot}/${x_script_folder}/${x_script_file}" )'"' >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

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

		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S /nolog @"${l_sqlplus_script_file}" \
			2> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			|| scriptReturnCode=$?

		return ${scriptReturnCode}
		;;

	(post-run-check)
		l_lines_OK=$(
			${local_grep} -Ei \
				"^(it's\s*\.\.\.|---\s*(setting\s+up\s+deployment\s+config\s+vars\s*$|turning\s+sql\*plus\s+defines|running\s+the\s+script|done\s*$))" \
				"${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" \
				| wc -l
		) || ThrowException "Spool file missing?"

		[ "$l_lines_OK" -eq 5 ] || ThrowException "Incomplete script execution! Trailing slash missing?"
		;;

	(cleanup)
		rm "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out"
		rm "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		;;

	(*)
		ThrowException "Unmatched action \"${x_action}\""
esac
