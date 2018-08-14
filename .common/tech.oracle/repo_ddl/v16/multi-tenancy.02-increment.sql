alter table t_db_increment
add (
    app_id                          varchar2(32 byte),
    constraint FK_db_increment$app
        foreign key (app_id)
        references t_db_app_h (app_id)
);
