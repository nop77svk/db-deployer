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
		cat > "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback

			-- phase: pre-phase

			connect ${cfg_deploy_repo_db}

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

	(cleanup)
		rm "${TmpPath}/${Env}.script_exec_start.${l_id_script}-${l_id_script_execution}.${RndToken}.sql"
		rm "${TmpPath}/${Env}.script_exec_start.${l_id_script}-${l_id_script_execution}.${RndToken}.log"
		;;

esac
