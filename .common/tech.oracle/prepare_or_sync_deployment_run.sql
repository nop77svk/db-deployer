prompt --- trace @ prepare_or_sync_deployment_run.sql

define script_action="&1"

prompt script action = "&script_action"

/*
delete from tt_db_deploy_tgt;
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_local_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_local_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_local_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_local_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_local_user=dqmadmin_aurep}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_db=dqm-local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_aurep_repl_user=dqmadmin_aurep_2}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_db=dqm-local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_deploy_repo_user=dqmadmin}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_db=dqm-local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_local_user=dqmadmin_ldd}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_db=dqm-local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_ldd_repl_user=dqmadmin_ldd_2}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_db=dqm-local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_password=xxxxxxxx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_tbs_index=dqm_idx}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_tbs_lob=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_tbs_table=dqm_dat}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dpltgt_master_user=dqmadmin}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_aurep=aurep_local,aurep_repl}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_downwards=master,repl,local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_ldd=ldd_local,ldd_repl}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_local=ldd_local,aurep_local}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_repl=ldd_repl,aurep_repl}');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values (q'{dbgrp_upwards=local,repl,master}');
*/

var l_new_deployment_id number;
var l_app_v_id number;

prompt --- Lock the app for deployment

exec select app_v_id into :l_app_v_id from t_db_app where app_id = '&deploy_cfg_app_id' for update;

print :l_app_v_id;

prompt --- Set up a new deployment

insert into t_db_deployment (id_db_deployment, app_id, xml_environment)
values (seq_db_deployment.nextval, '&deploy_cfg_app_id', null)
returning id_db_deployment
into :l_new_deployment_id;

print :l_new_deployment_id;

prompt --- Update the environment info for the new deployment

merge into t_db_deployment T
using (
    select
        xmlelement("userenv",
            xmlagg(
                xmlelement(evalname lower(X.column_value),
                    sys_context('userenv', X.column_value)
                )
            )
        ) as xml_environment
    from table(sys.ora_mining_varchar2_nt('AUTHENTICATED_IDENTITY', 'AUTHENTICATION_DATA',
            'AUTHENTICATION_METHOD', /*'CDB_NAME',*/ 'CLIENT_IDENTIFIER', 'CLIENT_INFO', /*'CLIENT_PROGRAM_NAME',*/
            /*'CON_NAME',*/ 'CURRENT_EDITION_NAME', 'CURRENT_SCHEMA', 'CURRENT_USER', 'DBLINK_INFO',
            'ENTERPRISE_IDENTITY', 'GLOBAL_UID', 'HOST', 'IDENTIFICATION_TYPE', 'INSTANCE_NAME', 'IP_ADDRESS',
            'ISDBA', 'LANGUAGE', 'LANG', 'NETWORK_PROTOCOL', 'NLS_CALENDAR', 'NLS_CURRENCY', 'NLS_DATE_FORMAT',
            'NLS_DATE_LANGUAGE', 'NLS_SORT', 'NLS_TERRITORY', /*'ORACLE_HOME',*/ 'OS_USER', /*'PLATFORM_SLASH',*/
            'PROXY_ENTERPRISE_IDENTITY', 'PROXY_USER', /*'SCHEDULER_JOB',*/ 'SERVER_HOST', 'SERVICE_NAME',
            'SESSION_EDITION_NAME', 'SESSION_USER', 'SID', 'TERMINAL'
        )) X
) S
on ( T.id_db_deployment = :l_new_deployment_id
    and T.app_id = '&deploy_cfg_app_id' )
when matched then
    update
    set T.xml_environment = S.xml_environment
;

prompt --- Set up the configuration of deployment targets

--select max(id_db_deployment) from t_db_deployment;

insert into t_db_deploy_tgt (id_db_deploy_tgt, id_db_deployment, nam_target, txt_db_user, txt_db_db)
select seq_db_deployment.nextval, :l_new_deployment_id, X.target_name, X.target_user, X.target_db
from vtt_db_deploy_tgt_atomic X;

insert into t_db_deploy_tgt (id_db_deploy_tgt, id_db_deployment, nam_target, num_member_target_seq, nam_member_target)
select seq_db_deployment.nextval, :l_new_deployment_id, X.group_name, X.member_seq, X.member_name
from vtt_db_deploy_tgt_group X;

--select * from t_db_deploy_tgt;

prompt --- Set up the list of scripts to be executed

insert into t_db_script_execution
	( id_db_script_execution, id_db_deployment, id_db_script, nam_deploy_target, num_order,
	num_return_code, app_v_id,
	fip_start, fip_finish )
with xyz as (
    select I.dat_folder, F.id_db_script, F.num_order as script_order, F.nam_schema_id, DT.nam_atomic_target, DT.target_order,
        row_number() over (partition by I.app_id order by I.dat_folder asc, F.num_order asc, DT.target_order asc) as script_run_order
    from t_db_script F
        join t_db_increment I
            on I.id_db_increment = F.id_db_increment
        left join vt_db_deploy_tgt_grp_resolve DT
            on DT.id_db_deployment = :l_new_deployment_id
            and DT.nam_target = F.nam_schema_id
    where I.app_id = '&deploy_cfg_app_id'
        and not exists (
            select *
            from t_db_script_execution FX
            where FX.id_db_script = F.id_db_script
                and FX.nam_deploy_target = DT.nam_atomic_target
                and FX.num_return_code <= 0
                and FX.num_return_code not in (-2)
        )
)
select seq_db_deployment.nextval, :l_new_deployment_id, id_db_script, nam_atomic_target, script_run_order,
    case
        when '&script_action' = 'sync-only' then 0
        when dat_folder >= sysdate+1/24 then -2
        else null
    end as num_return_code,
    case when '&script_action' = 'sync-only' then :l_app_v_id end as app_v_id,
    case
        when '&script_action' = 'sync-only' then systimestamp
        when dat_folder >= sysdate+1/24 then systimestamp
        else null
    end as fip_start,
    case
    when '&script_action' = 'sync-only' then systimestamp
    when dat_folder >= sysdate+1/24 then systimestamp
    else null
    end as fip_finish
from xyz
;

