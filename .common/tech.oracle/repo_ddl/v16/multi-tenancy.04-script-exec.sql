alter table t_db_script_execution
add (
    app_v_id                        integer,
    constraint FK_db_script_exec$app_v
        foreign key (app_v_id)
        references t_db_app_v (app_v_id)
);
