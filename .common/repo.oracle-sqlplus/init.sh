#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

cd "${DeployRepoTechPath}/repo_ddl"

Tech_OracleSqlPlus_GetConnectString g_OracleSqlPlus_repoDbConnect !deploy_repo!
Tech_OracleSqlPlus_GetConnectString l_OracleSqlPlus_repoDbConnectObfuscated !deploy_repo! obfuscate-password
InfoMessage "    deployment repository connection = \"${l_OracleSqlPlus_repoDbConnectObfuscated}\""

# ------------------------------------------------------------------------------------------------

InfoMessage "    preconfiguring repository installer"

set \
	| ${local_grep} -Ei '^deploy_repo_' \
	| ${local_grep} -Evi '^deploy_repo_password' \
	| ${local_sed} 's/^\(.*\)\s*=\s*\(.*\)\s*$/define \1 = \2/g' \
	| ${local_sed} "s/= '\(.*\)'$/= \1/g" \
	>> "_deploy_repo_defines.${RndToken}.tmp"

echo "define deploy_cfg_app_id = '${cfg_app_id}'" >> "_deploy_repo_defines.${RndToken}.tmp"

# ------------------------------------------------------------------------------------------------

InfoMessage "    set up repository"
"${SqlPlusBinary}" -L -S "${g_OracleSqlPlus_repoDbConnect}" @_deploy_repository.sql ${RndToken} \
	|| ThrowException "SQL*Plus failed"
	2> "${g_LogFolder}/${gx_Env}._deploy_repository.${RndToken}.err"
	> "${g_LogFolder}/${gx_Env}._deploy_repository.${RndToken}.out"

InfoMessage "    set up API"

# ------------------------------------------------------------------------------------------------

function DeployRepo_PrePhase()
{
	x_id_script="$1"
	x_id_script_execution="$2"

	cat > "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback

		-- phase: pre-phase

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

	echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

	cat >> "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

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

	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S "${g_OracleSqlPlus_repoDbConnect}" @"${l_sqlplus_script_file}" \
		2> "${g_LogFolder}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
		|| scriptReturnCode=$?

	rm "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
	rm "${TmpPath}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out"
	rm "${g_LogFolder}/${gx_Env}.script_exec_start.${x_id_script}-${x_id_script_execution}.${RndToken}.log"

	return ${scriptReturnCode}
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_PostPhase()
{
	x_id_script="$1"
	x_id_script_execution="$2"
	x_script_return_code="$3"

	cat > "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback

		set autoprint off
		set autotrace off
		set echo on
		set define on
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

		define deploy_cfg_app_id = '${cfg_app_id}'

	EOF

	echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

	cat >> "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

		prompt --- updating deployment repository (post-phase)

		var l_script_spool nclob;
		var l_script_stderr nclob;

		update t_db_script_execution FX
		set FX.fip_finish = current_timestamp,
		    FX.num_return_code = ${x_script_return_code},
		    FX.txt_script_spool = empty_clob(),
		    FX.txt_script_stderr = empty_clob(),
		    FX.app_v_id = (select app_v_id from t_db_app where ${scriptReturnCode} = 0 and app_id = '&deploy_cfg_app_id')
		where FX.id_db_script_execution = ${x_id_script_execution}
		returning txt_script_spool, txt_script_stderr
			into :l_script_spool, :l_script_stderr
		;

		set define off

	EOF

	cat "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.log" \
		| gzip -9cn \
		| base64 \
		| ${local_gawk} \
			-f "${DeployRepoTechPath}/gzip_base64_to_sqlplus.awk" \
			-v 'outputClobVarName=l_script_spool' \
		>> "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

	cat "${g_LogFolder}/${gx_Env}.script_exec_exec.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
		| gzip -9cn \
		| base64 \
		| ${local_gawk} \
			-f "${DeployRepoTechPath}/gzip_base64_to_sqlplus.awk" \
			-v 'outputClobVarName=l_script_stderr' \
		>> "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"

	cat >> "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

		commit;

		exit success
	EOF

	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S ${g_OracleSqlPlus_repoDbConnect} @"${l_sqlplus_script_file}" \
		|| ThrowException "SQL*Plus failed"

	rm "${TmpPath}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
	rm "${g_LogFolder}/${gx_Env}.script_exec_finish.${x_id_script}-${x_id_script_execution}.${RndToken}.log"
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_FakeExec()
{
	x_id_script="$1"
	x_id_script_execution="$2"

	scriptReturnCode=0

	cat > "${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback

		set autoprint off
		set autotrace off
		set echo on
		set define on
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

		define deploy_cfg_app_id = '${cfg_app_id}'

	EOF

	echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
	fakeMsg="note: a faked execution of \"${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql\""

	cat >> "${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" <<-EOF

		prompt --- updating deployment repository (fake execution)

		update t_db_script_execution FX
		set FX.fip_start = current_timestamp,
			FX.fip_finish = current_timestamp,
		    FX.num_return_code = ${scriptReturnCode},
		    FX.txt_script_spool = '${fakeMsg}',
		    FX.txt_script_stderr = null,
		    FX.app_v_id = (select app_v_id from t_db_app where ${scriptReturnCode} = 0 and app_id = '&deploy_cfg_app_id')
		where FX.id_db_script_execution = ${x_id_script_execution};

		commit;

		exit success
	EOF

	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S ${g_OracleSqlPlus_repoDbConnect} @"${l_sqlplus_script_file}" \
		2> "${g_LogFolder}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out" \
		|| ThrowException "SQL*Plus execution exited with status of $?"

	[ -z "${DEBUG:-}" ] || true && (
		rm "${g_LogFolder}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.stderr.out"
		rm "${TmpPath}/${gx_Env}.script_exec_fake.${x_id_script}-${x_id_script_execution}.${RndToken}.sql"
	)

	return ${scriptReturnCode}
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_MergeIncrements()
{
	cat > "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback
	
		set trimspool on
		set trimout on
		set linesize 32767
		set termout off
		set echo off
		set feedback on

	EOF

	echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.merge_increments_to_repo.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql"
	
	cat >> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql" <<-EOF

		define deploy_cfg_app_id = '${cfg_app_id}'

		col "It's ..." format a40
		select user||'@'||global_name as "It's ..." from global_name;
	
		prompt --- loading the list of script files to DB
	
		set feedback off
	
		select count(1) as temp_records_before from tt_db_full_inc_script_path;
	
	EOF
	
	cat "${TmpPath}/${gx_Env}.script_full_paths.${RndToken}.tmp" \
		| ${local_gawk} -f "${DeployRepoTechPath}/full_script_list_to_sql_inserts.awk" \
		>> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql"
	
	cat >> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql" <<-EOF
	
		select count(1) as temp_records_after from tt_db_full_inc_script_path;
	
		set feedback on
		prompt --- now about to synchronize the repository
	EOF
	
	echo '@"'$( EchoPathUnixToWin "${DeployRepoTechPath}/merge_increments_to_repo.sql" )'"' >> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql"
	
	cat >> "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql" <<-EOF
		prompt --- DONE synchronizing the repository
	
		commit;
	
		spool off
		exit success
	EOF
	
	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S "${g_OracleSqlPlus_repoDbConnect}" @"${l_sqlplus_script_file}" \
		|| ThrowException "SQL*Plus failed"
	
	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${gx_Env}.script_full_paths.${RndToken}.tmp"
		rm "${TmpPath}/${gx_Env}.merge_increments_to_repo.${RndToken}.sql"
		rm "${g_LogFolder}/${gx_Env}.merge_increments_to_repo.${RndToken}.log"
	)
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_GetListToExecute()
{
	cat > "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback
	
		set autoprint off
		set autotrace off
		set echo off
		set define on
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
	
		define deploy_cfg_app_id = '${cfg_app_id}'
	
	EOF
	
	echo 'spool "'$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.tmp" )'"' >> "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql"
	echo '@"'$( EchoPathUnixToWin "${DeployRepoTechPath}/retrieve_the_deployment_setup.sql" )'"' >> "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql"
	
	cat >> "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql" <<-EOF
	
		spool off
		exit success
	EOF
	
	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S ${g_OracleSqlPlus_repoDbConnect} @"${l_sqlplus_script_file}" \
		|| ThrowException "SQL*Plus failed"
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_CreateRun()
{
	x_deploy_action="$1"

	cat > "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql" <<-EOF
		whenever sqlerror exit 1 rollback
		whenever oserror exit 2 rollback
	
		set trimspool on
		set trimout on
		set linesize 32767
		set termout off
		set echo off
		set feedback on

		define deploy_cfg_app_id = '${cfg_app_id}'
	
	EOF
	
	echo 'spool "'$( EchoPathUnixToWin "${g_LogFolder}/${gx_Env}.set_up_deployment_run.${RndToken}.log" )'"' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	echo '' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	
	echo 'prompt --- loading deployment targets to tmp' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	declare | ${local_grep} -E '^(dpltgt_[^=]*_(db|user)|dbgrp_.*)=' | ${local_sed} "s/^.*$/insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{&}');/gi" >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	echo '' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	
	echo 'prompt --- calling set_up_deployment_run.sql' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	if [ "${x_deploy_action}" = "sync" ] ; then
		echo '@"'$( EchoPathUnixToWin "${DeployRepoTechPath}/prepare_or_sync_deployment_run.sql" )'" sync-only' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	else
		echo '@"'$( EchoPathUnixToWin "${DeployRepoTechPath}/prepare_or_sync_deployment_run.sql" )'" normal' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	fi
	echo '' >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
	
	cat >> "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql" <<-EOF
		prompt --- DONE setting up a deployment run
	
		commit;
	
		spool off
		exit success
	EOF
	
	l_sqlplus_script_file=$( EchoPathUnixToWin "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql" )
	"${SqlPlusBinary}" -L -S ${g_OracleSqlPlus_repoDbConnect} @"${l_sqlplus_script_file}" \
		|| ThrowException "SQL*Plus failed"
	
	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${gx_Env}.set_up_deployment_run.${RndToken}.sql"
		rm "${g_LogFolder}/${gx_Env}.set_up_deployment_run.${RndToken}.log"
	)
}

# ------------------------------------------------------------------------------------------------

function DeployRepo_CleanUp()
{
	true
}

# ------------------------------------------------------------------------------------------------

[ -z "${DEBUG:-}" ] || true && (
	InfoMessage "    done"
	rm -f "_deploy_repository.${RndToken}.log"
	rm -f "_deploy_repository.upgrade_script.${RndToken}.tmp"
	rm -f "${g_LogFolder}/${gx_Env}._deploy_repository.${RndToken}.err"
	rm -f "${g_LogFolder}/${gx_Env}._deploy_repository.${RndToken}.out"
	rm -f "_deploy_repo_defines.${RndToken}.tmp"
)

cd "${ScriptPath}"
