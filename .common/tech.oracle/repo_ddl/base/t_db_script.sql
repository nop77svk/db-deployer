create table t_db_script
(
    id_db_script                    integer not null,
    constraint PK_db_script
        primary key (id_db_script)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    fip_create                      timestamp with time zone default current_timestamp not null,
    --
    id_db_increment                 integer not null,
    constraint FK_db_script$increment
        foreign key (id_db_increment)
        references t_db_increment (id_db_increment)
        on delete cascade,
    txt_script_file                 varchar2(256) not null,
    --
    num_order                       integer as (regexp_substr(txt_script_file, '^(\d+)(-([^;]+))?;([a-z_]+)\.([a-z]+)$', 1, 1, 'i', 1)) not null,
    constraint CK_db_increment$ord_gt_0
        check (num_order > 0),
    constraint UQ_db_script$folder_seq
        unique (id_db_increment, num_order)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    txt_script_comment              as (regexp_substr(txt_script_file, '^(\d+)(-([^;]+))?;([a-z_]+)\.([a-z]+)$', 1, 1, 'i', 3)),
    nam_schema_id                   as (regexp_substr(txt_script_file, '^(\d+)(-([^;]+))?;([a-z_]+)\.([a-z]+)$', 1, 1, 'i', 4)) not null,
    constraint CK_db_increment$schema
        check (regexp_like(nam_schema_id, '^[a-z][a-z_]*$', 'i')),
    cod_file_ext                    as (regexp_substr(txt_script_file, '^(\d+)(-([^;]+))?;([a-z_]+)\.([a-z]+)$', 1, 1, 'i', 5)) not null
)
tablespace &DEPLOY_REPO_TBS_TABLE;

alter table t_db_script modify txt_script_comment varchar2(256);
alter table t_db_script modify nam_schema_id varchar2(32);
alter table t_db_script modify cod_file_ext varchar2(32);

---

alter table t_db_script
add constraint FK_db_increment$file_ext
    foreign key (cod_file_ext)
    references c_db_script_file_extension (cod_file_extension)
;

---

comment on table t_db_script is '(Deployment) Incremental DB scripts (essentially: the contents of the "increments" folders), ordered';

comment on column t_db_script.id_db_script is 'Synthetic primary key';
comment on column t_db_script.fip_create is 'Creation timestamp of the increment script in the DB repository';

comment on column t_db_script.id_db_increment is 'Reference to the containing increment package (i.e. to the containing folder)';
comment on column t_db_script.txt_script_file is 'Incremental script file name (w/o path) as "nnnnnn...-some_comment;schema_id.extension"';
comment on column t_db_script.num_order is '(Calculated) Order of the script within the increment package - the "nnnnnn..." part of the TXT_SCRIPT_FILE';
comment on column t_db_script.txt_script_comment is '(Calculated) Optional comment of the script - the "some_comment" part of the TXT_SCRIPT_FILE';
comment on column t_db_script.nam_schema_id is '(Calculated) Symbolic identifier of the credentials under which the script is supposed to run - the "schema_id" part of the TXT_SCRIPT_FILE; this refers to the dpltgt_<schema_id>_<variable_name> variables from the settings.cfg';
comment on column t_db_script.cod_file_ext is '(Calculated) Extension of the script file - the "extension" part of the TXT_SCRIPT_FILE (ref: C_DB_SCRIPT_FILE_EXTENSION)';

