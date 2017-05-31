create sequence seq_db_deployment
nocache
nocycle;


create table t_db_increment
(
    id_db_increment                 integer not null,
    constraint PK_db_increment
        primary key (id_db_increment)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    fip_create                      timestamp with time zone default current_timestamp not null,
    --
    txt_folder                      varchar2(256) not null,
    constraint UQ_db_increment$folder
        unique (txt_folder)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    dat_folder                      date as (to_date(regexp_substr(txt_folder, '^(.*\/)?(\d{8}-\d{4})(;(.*))?$', 1, 1, null, 2), 'yyyymmdd_hh24mi')) not null,
    txt_comment                     as (regexp_substr(txt_folder, '^(.*\/)?(\d{8}-\d{4})(;(.*))?$', 1, 1, null, 4))
)
tablespace &DEPLOY_REPO_TBS_TABLE
;

alter table t_db_increment modify txt_comment varchar2(256);

---

comment on table t_db_increment is '(Deployment) DB increment packages (essentially: folders on the filesystem containing the actual increment scripts)';

comment on column t_db_increment.id_db_increment is 'Synthetic primary key';
comment on column t_db_increment.fip_create is 'Creation timestamp of the increment package in DB repository';

comment on column t_db_increment.txt_folder is 'Full (relative to the deployer shell script) folder path of the increment package as "yyyymmdd-hh24mi;any comment", optionally prefixed with an arbitrary sequence of parent folders';
comment on column t_db_increment.dat_folder is '(Calculated) Mandatory date/time part ("yyyymmdd-hh24mi") of the TXT_FOLDER';
comment on column t_db_increment.txt_comment is '(Calculated) Optional comment part ("any comment" after the semicolon) of the TXT_FOLDER';

