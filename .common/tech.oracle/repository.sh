#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

# 2do! make ${Env} a parameter ${x_env}?

x_action="$1"
x_rnd_token="$2"

case "${x_action}" in
	(pre-phase-run)
		x_id_script="$3"
		x_id_script_execution="$4"
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
		x_id_script="$3"
		x_id_script_execution="$4"
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
		"${SqlPlusBinary}" -L -S ${x_connect} @"${l_sqlplus_script_file}" \
			|| ThrowException "SQL*Plus failed"

		return ${scriptReturnCode}
		;;

	(pre-phase-cleanup|cleanup)
		x_id_script="$3"
		x_id_script_execution="$4"

		rm "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		rm "${TmpPath}/${Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log"
		;;&

	(post-phase-cleanup|cleanup)
		x_id_script="$3"
		x_id_script_execution="$4"

		rm "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		rm "${TmpPath}/${Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.log"
		;;

	(fake-exec)
		x_id_script="$3"
		x_id_script_execution="$4"
		x_connect="$5"

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
		"${SqlPlusBinary}" -L -S ${x_connect} @"${l_sqlplus_script_file}" \
			2> "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out" \
			|| ThrowException "SQL*Plus execution exited with status of $?"

		[ -z "${DEBUG}" ] && (
			rm "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.stderr.out"
			rm "${TmpPath}/${Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${x_rnd_token}.sql"
		)

		return ${scriptReturnCode}
		;;

	(merge-inc)
		x_connect="$3"

		cat > "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback
	
			set trimspool on
			set trimout on
			set linesize 32767
			set termout off
			set echo off
			set feedback on
			spool "${Env}.merge_increments_to_repo.${RndToken}.log"
	
			col "It's ..." format a40
			select user||'@'||global_name as "It's ..." from global_name;
	
			prompt --- loading the list of script files to DB
	
			set feedback off
	
			select count(1) as temp_records_before from tt_db_full_inc_script_path;
	
		EOF
	
		cat "${TmpPath}/${Env}.script_full_paths.${x_rnd_token}.tmp" \
			| ${local_gawk} -f "${CommonsPath}/tech.oracle/full_script_list_to_sql_inserts.awk" \
			>> "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql"
	
		cat >> "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql" <<-EOF
	
			select count(1) as temp_records_after from tt_db_full_inc_script_path;
	
			set feedback on
	
		EOF
	
		echo '@@"'$( PathUnixToWin "${CommonsPath}/tech.oracle/merge_increments_to_repo.sql" )'"' >> "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql"
	
		cat >> "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql" <<-EOF
			prompt --- DONE synchronizing repository
	
			commit;
	
			spool off
			exit success
		EOF
	
		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S ${x_connect} @"${l_sqlplus_script_file}" \
			|| ThrowException "SQL*Plus failed"
	
		[ -z "${DEBUG}" ] && (
			rm "${TmpPath}/${Env}.script_full_paths.${x_rnd_token}.tmp"
			rm "${TmpPath}/${Env}.merge_increments_to_repo.${x_rnd_token}.sql"
		)
		;;

	(get-list-to-exec)
		x_connect="$3"

		cat > "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback
	
			set autoprint off
			set autotrace off
			set echo off
			set define off
			set feedback off
			set heading off
			set headsep off
			set linesize 2048
			set newpage none
			set recsep off
			set tab on
			set termout off
			set trimout on
			set trimspool on
			set verify off
			set wrap off
			set sqlterminator ';'
	
			set exitcommit off
	
		EOF
	
		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.tmp" )'"' >> "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.sql"
		echo '@@"'$( PathUnixToWin "${CommonsPath}/tech.oracle/retrieve_the_deployment_setup.sql" )'"' >> "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.sql"
	
		cat >> "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.sql" <<-EOF
	
			spool off
			exit success
		EOF
	
		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.retrieve_the_deployment_setup.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S ${x_connect} @"${l_sqlplus_script_file}" \
			|| ThrowException "SQL*Plus failed"
		;;

	(create-run)
		x_connect="$3"
		x_deploy_action="$4"

		cat > "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql" <<-EOF
			whenever sqlerror exit 1 rollback
			whenever oserror exit 2 rollback
	
			set trimspool on
			set trimout on
			set linesize 32767
			set termout off
			set echo off
			set feedback on
	
		EOF
	
		echo 'spool "'$( PathUnixToWin "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.log" )'"' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		echo '' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
	
		echo 'prompt --- loading deployment targets to tmp' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		declare | ${local_grep} -E '^(dpltgt|dbgrp)_.*=' | ${local_sed} "s/^.*$/insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{&}');/gi" >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		echo '' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
	
		echo 'prompt --- calling set_up_deployment_run.sql' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		if [ "${x_deploy_action}" = "sync" ] ; then
			echo '@@"'$( PathUnixToWin "${CommonsPath}/tech.oracle/prepare_or_sync_deployment_run.sql" )'" sync-only' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		else
			echo '@@"'$( PathUnixToWin "${CommonsPath}/tech.oracle/prepare_or_sync_deployment_run.sql" )'" normal' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		fi
		echo '' >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
	
		cat >> "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql" <<-EOF
			prompt --- DONE setting up a deployment run
	
			commit;
	
			spool off
			exit success
		EOF
	
		l_sqlplus_script_file=$( PathUnixToWin "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql" )
		"${SqlPlusBinary}" -L -S ${x_connect} @"${l_sqlplus_script_file}" \
			|| ThrowException "SQL*Plus failed"
	
		[ -z "${DEBUG}" ] && (
			rm "${TmpPath}/${Env}.set_up_deployment_run.${x_rnd_token}.sql"
		)
		;;

	(*)
		ThrowException "Unmatched action \"${x_action}\""
esac
