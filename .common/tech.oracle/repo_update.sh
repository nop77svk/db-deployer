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
		x_connect="$5"
		x_script_return_code="$6"

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
			set serveroutput on size unlimited format truncated

		EOF

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			prompt --- updating deployment repository (post-phase)

			var l_script_spool nclob;
			var l_script_stderr nclob;

			update t_db_script_execution FX
			set FX.fip_finish = current_timestamp,
			    FX.num_return_code = ${x_script_return_code},
			    FX.txt_script_spool = empty_clob(),
			    FX.txt_script_stderr = empty_clob()
			where FX.id_db_script_execution = ${x_id_script_execution}
			returning txt_script_spool, txt_script_stderr
				into :l_script_spool, :l_script_stderr
			;

		EOF

		cat "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" \
			| gzip -9cn \
			| base64 \
			| ${local_gawk} \
				-f "${CommonsPath}/tech.oracle/gzip_base64_to_sqlplus.awk" \
				-v 'outputClobVarName=l_script_spool' \
			>> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat "${TmpPath}/${Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			| gzip -9cn \
			| base64 \
			| ${local_gawk} \
				-f "${CommonsPath}/tech.oracle/gzip_base64_to_sqlplus.awk" \
				-v 'outputClobVarName=l_script_stderr' \
			>> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

		cat >> "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

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

	(fake-exec)
		scriptReturnCode=0

		cat > "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF
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

		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		fakeMsg="note: a faked execution of \"${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql\""

		cat >> "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF

			prompt --- updating deployment repository (fake execution)

			update t_db_script_execution FX
			set FX.fip_start = current_timestamp,
				FX.fip_finish = current_timestamp,
			    FX.num_return_code = ${scriptReturnCode},
			    FX.txt_script_spool = '${fakeMsg}',
			    FX.txt_script_stderr = null
			where FX.id_db_script_execution = ${x_id_script_execution};

			commit;

			exit success
		EOF

		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S ${cfg_deploy_repo_db} @"${l_sqlplus_script_file}" \
			2> "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			|| ThrowException "SQL*Plus execution exited with status of $?"

		return ${scriptReturnCode}
		;;

	(fake-exec-cleanup)
		rm "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out"
		rm "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"

esac
