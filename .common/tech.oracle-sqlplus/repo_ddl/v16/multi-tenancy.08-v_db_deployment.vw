create or replace view v_db_deployment
as
select
    I.app_id, I.id_db_increment, I.txt_folder,
    F.id_db_script, F.txt_script_file,
    FX.id_db_deployment, FX.id_db_script_execution, FX.num_order, FX.nam_deploy_target,
    row_number() over (partition by F.id_db_script order by FX.fip_create desc nulls first) as script_execution_relevance,
    nvl2(AV.app_v_id, n''||AV.ver_major||n'.'||AV.ver_minor||n'.'||AV.ver_maintenance||nvl2(AV.codename, n'/'||AV.codename, null), null) as app_version,
    FX.fip_start as fip_execution_start, FX.fip_finish as fip_execution_finish, FX.num_return_code, FX.txt_script_spool, FX.txt_script_stderr
from t_db_increment I
    join t_db_script F
        on F.id_db_increment = I.id_db_increment
    left join t_db_script_execution FX
        on FX.id_db_script = F.id_db_script
    left join t_db_app_v AV
        on AV.app_v_id = FX.app_v_id
;

comment on table v_db_deployment is '(Deployment) Composite view over all deployed, undeployed and failed incremental scripts';

----------------------------------------------------------------------------------------------------

create or replace view v_db_deployment_ok
as
select app_id, txt_folder, txt_script_file, nam_deploy_target
from v_db_deployment
where num_return_code = 0
;

comment on table v_db_deployment_ok is '(Deployment) Simple view over all deployed scripts in all increments';
