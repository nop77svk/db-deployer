update t_db_script_execution T
set T.app_v_id = (select app_v_id from t_db_app where app_id = '&deploy_cfg_app_id')
where T.app_v_id is null
    and T.num_return_code = 0
;

commit;

alter table t_db_script_execution
add constraint CK_db_script_exec$app_v_nn
    check ( num_return_code = 0 and app_v_id is not null
        or lnnvl(num_return_code = 0) and app_v_id is null )
;
