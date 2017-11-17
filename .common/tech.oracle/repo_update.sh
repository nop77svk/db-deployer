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
	(pre-phase-run)
		x_connect="$5"

		cat > "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback

			-- phase: pre-phase

			connect ${x_connect}

			set autoprint off
			set autotrace off
			set echo on
			set define off
			set escape off
			set feedback on
			set heading on
			set headsep on
			set linesize 32767
			set sqlbl off
			set termout off
			set trimout on
			set trimspool on
			set verify on
			set wrap on
			set sqlterminator ';'

			set exitcommit off

		EOF

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			prompt --- updating deployment repository (pre-phase)

			update t_db_script_execution FX
			set FX.fip_start = current_timestamp
			where FX.id_db_script_execution = ${x_id_script_execution};

			prompt --- OK

			commit;

			spool off
			exit success
		EOF

		scriptReturnCode=0

		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S /nolog @"${l_sqlplus_script_file}" \
			2> "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			|| scriptReturnCode=$?

		return ${scriptReturnCode}
		;;

	(post-phase-run)
		cat > "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback

			set autoprint off
			set autotrace off
			set echo on
			set define off
			set escape off
			set feedback on
			set heading on
			set headsep on
			set linesize 32767
			set sqlbl off
			set termout off
			set trimout on
			set trimspool on
			set verify on
			set wrap on

			set exitcommit on

		EOF

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			prompt --- updating deployment repository (post-phase)

			var l_script_spool nclob;
			var l_script_stderr nclob;

			begin
				dbms_lob.createTemporary(
					lob_loc => :l_script_spool,
					cache => true,
					dur => dbms_lob.session
				);
				dbms_lob.createTemporary(
					lob_loc => :l_script_stderr,
					cache => true,
					dur => dbms_lob.session
				);
			end;
			/

		EOF

		cat "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" \
			| ${local_gawk} -v apostrophe="'" '
				{
					row = $0;
					gsub(/\s+$/, "", row);
					len = length(row);
					if (len >= 7400) {
						len = 7399;
						row = substr(row, 1, len);
					}
					print "exec dbms_lob.writeAppend(:l_script_spool, " (len+1) ", q" apostrophe "[" row "]" apostrophe "||chr(10));";
				}
			' \
			>> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			| ${local_gawk} -v apostrophe="'" '
				{
					row = $0;
					gsub(/\s+$/, "", row);
					len = length(row);
					if (len >= 7400) {
						len = 7399;
						row = substr(row, 1, len);
					}
					print "exec dbms_lob.writeAppend(:l_script_spool, " (len+1) ", q" apostrophe "[" row "]" apostrophe "||chr(10));";
				}
			' \
			>> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			update t_db_script_execution FX
			set FX.fip_finish = current_timestamp,
			    FX.num_return_code = ${scriptReturnCode},
			    FX.txt_script_spool = :l_script_spool,
			    FX.txt_script_stderr = :l_script_stderr
			where FX.id_db_script_execution = ${l_id_script_execution};

			commit;

			exit success
		EOF

		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S ${cfg_deploy_repo_db} @"${l_sqlplus_script_file}" \
			|| ThrowException "SQL*Plus failed"

		return ${scriptReturnCode}
		;;

	(pre-phase-cleanup|cleanup)
		rm "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		rm "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log"
		;;&

	(post-phase-cleanup|cleanup)
		rm "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		rm "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log"
		;;

esac
