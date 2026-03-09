create table t_db_meta
(
    meta_name                       varchar2(32) not null,
    constraint PK_db_meta
        primary key (meta_name)
        using index tablespace &DEPLOY_REPO_TBS_INDEX,
    constraint CK_db_meta$name
        check (meta_name = lower(trim(meta_name))),
    meta_value                      nvarchar2(2000)
)
tablespace &DEPLOY_REPO_TBS_TABLE
;

comment on table t_db_meta is '(Deployment) Deployment repository metatable';

comment on column t_db_meta.meta_name is 'Meta-variable name';
comment on column t_db_meta.meta_value is 'Meta-variable value';
