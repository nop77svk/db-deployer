update t_db_deployment T
set T.app_id = '&deploy_cfg_app_id'
where T.app_id is null;

commit;

alter table t_db_deployment modify app_id not null;
