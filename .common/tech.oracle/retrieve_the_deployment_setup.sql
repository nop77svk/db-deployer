with last_deploy$ as (
    select *
    from (
        select id_db_deployment as last_id_db_deployment
        from t_db_deployment D
        where app_id = '&deploy_cfg_app_id'
        order by fip_create desc
    )
    where rownum <= 1
),
output$ as (
    select FX.id_db_script_execution, FX.num_order, F.id_db_script, F.id_db_increment, I.txt_folder, F.txt_script_file, nvl(FX.nam_deploy_target,'???') as nam_schema_id,
        FX.num_return_code, FX.fip_finish, FX.txt_script_spool, FX.txt_script_stderr,
        count(num_return_code) over (partition by X.last_id_db_deployment order by FX.num_order asc rows between current row and unbounded following) as next_unfinished
    from last_deploy$ X
        join t_db_script_execution FX
            on FX.id_db_deployment = X.last_id_db_deployment
            and ( FX.num_return_code is null or FX.num_return_code >= 0 )
        join t_db_script F
            on F.id_db_script = FX.id_db_script
        join t_db_increment I
            on I.id_db_increment = F.id_db_increment
            and I.app_id = '&deploy_cfg_app_id'
)
select id_db_script_execution||'|'||num_order||'|'||id_db_script||'|'||id_db_increment||'|'||nam_schema_id||'|'||txt_folder||'|'||txt_script_file
from output$
where num_return_code is null and next_unfinished = 0
order by num_order
;

