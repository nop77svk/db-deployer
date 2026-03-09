create or replace view v_db_deployment
as
select
    I.id_db_increment, I.txt_folder,
    F.id_db_script, F.txt_script_file,
    FX.id_db_deployment, FX.id_db_script_execution, FX.nam_deploy_target, FX.num_order, row_number() over (partition by F.id_db_script, FX.nam_deploy_target order by FX.fip_create desc nulls first) as script_execution_relevance,
    FX.fip_start as fip_execution_start, FX.fip_finish as fip_execution_finish, FX.num_return_code, FX.txt_script_spool, FX.txt_script_stderr    
from t_db_increment I
    join t_db_script F
        on F.id_db_increment = I.id_db_increment
    left join t_db_script_execution FX
        on FX.id_db_script = F.id_db_script
;

comment on table v_db_deployment is '(Deployment) Composite view over all deployed, undeployed and failed incremental scripts';

----------------------------------------------------------------------------------------------------

create or replace view v_db_deployment_ok
as
select txt_folder, txt_script_file, nam_deploy_target
from v_db_deployment
where num_return_code = 0
;

comment on table v_db_deployment_ok is '(Deployment) Simple view over all deployed scripts in all increments';

