alter table t_db_deployment
add (
    app_id                          varchar2(32 byte),
    constraint FK_db_deployment$app
        foreign key (app_id)
        references t_db_app_h (app_id)
);
