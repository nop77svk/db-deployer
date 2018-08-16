whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

define RND_TOKEN = '&1'

set serveroutput on
set feedback off
set termout off
set trimout on
set trimspool on
set linesize 32767

spool _deploy_repository.&RND_TOKEN..log append

prompt === NOW STARTING DEPLOYMENT REPO INSTALLATION/UPGRADE ===

----------------------------------------------------------------------------------------------------

prompt --- Determining the current deployment repository version

var deploy_repo_version number;

declare
	l_repo_ver				integer := 0;
begin
	select decode(count(1), 1, 10, l_repo_ver) as checked_ver
	into l_repo_ver
	from user_objects
	where l_repo_ver = 0
	    and ( object_name in ('T_DB_META') and object_type = 'TABLE' )
	;
	--
	select decode(count(1), 5, 1, l_repo_ver) as checked_ver
	into l_repo_ver
	from user_objects
	where l_repo_ver = 0
	    and ( object_name in ('T_DB_INCREMENT','T_DB_SCRIPT','T_DB_DEPLOYMENT','T_DB_SCRIPT_EXECUTION') and object_type = 'TABLE'
	        or object_name in ('SEQ_DB_DEPLOYMENT') and object_type = 'SEQUENCE' )
	;
	select decode(count(1), 2, 2, l_repo_ver) as checked_ver
	into l_repo_ver
	from user_objects
	where l_repo_ver = 1
	    and ( object_name in ('TT_DB_FULL_INC_SCRIPT_PATH') and object_type = 'TABLE'
	        or object_name in ('VTT_DB_INC_SCRIPT_PATH') and object_type = 'VIEW' )
	;
	select decode(count(1), 4, 3, l_repo_ver) as checked_ver
	into l_repo_ver
	from user_objects
	where l_repo_ver = 2
	    and ( object_name in ('V_DB_DEPLOYMENT','V_DB_DEPLOYMENT_OK') and object_type = 'VIEW'
	        or object_name in ('TRG_VDB_DEPLOYMENT_OK$IRD','TRG_VDB_DEPLOYMENT_OK$IRI') and object_type = 'TRIGGER' )
	;
	--
	if l_repo_ver >= 10 then
		execute immediate 'select greatest(max(to_number(meta_value)), 10) from t_db_meta where lower(meta_name) = lower(:1)'
			into l_repo_ver
			using in 'deploy_repo_ver'
		;
		if l_repo_ver is null then
			l_repo_ver := 10;
			begin
				execute immediate 'insert into t_db_meta (meta_name, meta_value) values (:1, :2)'
					using in 'deploy_repo_ver', l_repo_ver;
			exception
				when dup_val_on_index then
					execute immediate 'update t_db_meta set meta_value = :1 where meta_name = :2'
						using in l_repo_ver, 'deploy_repo_ver';
			end;
			commit;
		end if;
	end if;
	--
	dbms_output.put_line('Current deployer repository version = '||l_repo_ver);
	:deploy_repo_version := l_repo_ver;
end;
/

----------------------------------------------------------------------------------------------------

prompt --- Creating deployment repository deployment script

set termout off
set verify off
spool _deploy_repository.upgrade_script.&RND_TOKEN..tmp

declare
	type rec_script_to_version is record (
		script varchar2(256),
		version integer
	);
	type arr_script_to_version is varray(1000) of rec_script_to_version;

	scr arr_script_to_version;

	l_repo_ver integer := :deploy_repo_version;
	l_cnt_scripts_higher_ver integer;

	function scr_ver(i_script in varchar2, i_ver in integer) return rec_script_to_version
	is
		l_result rec_script_to_version;
	begin
		l_result.script := i_script;
		l_result.version := i_ver;
		return l_result;
	end;
begin
	dbms_output.put_line('whenever sqlerror exit failure rollback');
	dbms_output.put_line('whenever oserror exit failure rollback');

	dbms_output.new_line();
	dbms_output.put_line('set serveroutput on');
	dbms_output.put_line('set feedback on');
	dbms_output.put_line('set define on');
	dbms_output.put_line('set verify on');
	dbms_output.put_line('set autoprint on');
	dbms_output.put_line('set autocommit off');

	dbms_output.new_line();
	dbms_output.put_line('@@./_deploy_repo_defines.'||'&RND_TOKEN'||'.tmp');

	scr := arr_script_to_version(
		scr_ver('base/_cleanup_version_1.sql', 1),
		scr_ver('base/t_db_increment.sql', 1),
		scr_ver('base/c_db_script_file_extension.sql', 1),
		scr_ver('base/t_db_script.sql', 1),
		scr_ver('base/t_db_deployment.sql', 1),
		scr_ver('base/t_db_script_execution.sql', 1),
		--
		scr_ver('base/_cleanup_version_2.sql', 2),
		scr_ver('base/tt_db_full_inc_script_path.sql', 2),
		scr_ver('base/vtt_db_inc_script_path.vw', 2),
		--
		scr_ver('base/_cleanup_version_3.sql', 3),
		scr_ver('base/v_db_deployment.vw', 3),
		scr_ver('base/v_db_deployment_ok.all.trg', 3),
		--
		scr_ver('base/_cleanup_version_10.sql', 10),
		scr_ver('base/t_db_meta.sql', 10),
		--
		scr_ver('v11/_cleanup_version.sql', 11),
		scr_ver('v11/t_db_deploy_tgt', 11),
		scr_ver('v11/vt_db_deploy_tgt_grp_resolve', 11),
		scr_ver('v11/tt_db_deploy_tgt', 11),
		scr_ver('v11/vtt_db_deploy_tgt.sql', 11),
		scr_ver('v11/t_db_script_execution.alter.sql', 11),
		scr_ver('v11/v_db_deployment.sql', 11),
		scr_ver('v11/v_db_deployment_ok.all.trg', 11),
		scr_ver('base/_update_meta.sql 11', 11),
		--
		scr_ver('v12/_cleanup_version.sql', 12),
		scr_ver('v12/c_db_script_file_extension.alter.sql', 12),
		scr_ver('v12/set_up_new_extensions.sql', 12),
		scr_ver('v12/set_up_defines_flag.sql ', 12),
		scr_ver('base/_update_meta.sql 12', 12),
		--
		scr_ver('v13/v_db_deployment_ok.all.trg', 13),
		scr_ver('base/_update_meta.sql 13', 13),
		--
		scr_ver('v14/vtt_db_deploy_tgt.sql', 14),
		scr_ver('base/_update_meta.sql 14', 14),
		--
		scr_ver('v15/c_db_script_file_extension.drop.sql', 15),
		scr_ver('base/_update_meta.sql 15', 15),
		--
		scr_ver('v16/multi-tenancy.01-app.sql', 16),
		scr_ver('v16/multi-tenancy.02-increment.sql', 16),
		scr_ver('v16/multi-tenancy.03-increment-fillup.sql', 16),
		scr_ver('v16/multi-tenancy.04-script-exec.sql', 16),
		scr_ver('v16/multi-tenancy.05-script-exec-fillup.sql', 16),
		scr_ver('v16/multi-tenancy.06-deployment.sql', 16),
		scr_ver('v16/multi-tenancy.07-deployment-fillup.sql', 16),
		scr_ver('v16/multi-tenancy.08-v_db_deployment.vw', 16),
		scr_ver('v16/multi-tenancy.09-v_db_deployment_ok.all.trg', 16),
		scr_ver('base/_update_meta.sql 16', 16),
		--
		scr_ver('v17/multi-tenancy.01-fix_increment.sql', 17),
		scr_ver('base/_update_meta.sql 17', 17)
	);

	l_cnt_scripts_higher_ver := scr.count();
	while l_cnt_scripts_higher_ver > 0 loop
		l_repo_ver := l_repo_ver + 1;
		dbms_output.new_line();
		dbms_output.put_line('prompt --- getting to version '||l_repo_ver);

		l_cnt_scripts_higher_ver := 0;
		for i in 1..scr.last() loop
			if scr(i).version > l_repo_ver then
				l_cnt_scripts_higher_ver := l_cnt_scripts_higher_ver + 1;
			elsif scr(i).version = l_repo_ver then
				dbms_output.new_line();
				dbms_output.put_line('prompt --- '||scr(i).script);
				dbms_output.put_line('@@'||scr(i).script);
			end if;
		end loop;
	end loop;
end;
/

spool _deploy_repository.&RND_TOKEN..log append
set verify on

----------------------------------------------------------------------------------------------------

prompt --- Now executing the installer

@@_deploy_repository.upgrade_script.&RND_TOKEN..tmp

----------------------------------------------------------------------------------------------------

prompt === EVERYTHING WENT OK ===

spool off

exit success
