create table t_db_script_execution
(
    id_db_script_execution         integer not null,
    constraint PK_db_script_execution
        primary key (id_db_script_execution)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    fip_create                      timestamp with time zone default current_timestamp not null,
    --
    id_db_deployment                integer not null,
    constraint FK_db_scr_exec$deployment
        foreign key (id_db_deployment)
        references t_db_deployment (id_db_deployment)
        on delete cascade,
    id_db_script                    integer not null,
    constraint FK_db_scr_exec$script
        foreign key (id_db_script)
        references t_db_script (id_db_script)
        on delete cascade,
    constraint PK_db_script_execution_2
        unique (id_db_script, id_db_deployment)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    num_order                       integer not null,
    constraint PK_db_script_execution_3
        unique (id_db_deployment, num_order)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    --
    fip_start                       timestamp with time zone,
    fip_finish                      timestamp with time zone,
    num_return_code                 number,
    constraint CK_db_scr_exec$ret_code_nn
        check ( fip_finish is null and num_return_code is null
            or fip_finish is not null and num_return_code is not null ),
    txt_script_spool                nclob,
    constraint CK_db_scr_exec$spool_nn
        check ( fip_finish is null and txt_script_spool is null
            or fip_finish is not null ),
    txt_script_stderr               nclob,
    constraint CK_db_scr_exec$stderr_nn
        check ( fip_finish is null and txt_script_stderr is null
            or fip_finish is not null )
)
lob (txt_script_spool) store as securefile lob_db_scr_exec$spool (
    disable storage in row
    tablespace &DEPLOY_REPO_TBS_LOB
--    compress medium
--    keep_duplicates
	chunk 256
)
lob (txt_script_stderr) store as securefile lob_db_scr_exec$stderr (
    disable storage in row
    tablespace &DEPLOY_REPO_TBS_LOB
--    compress low
--    deduplicate
    chunk 256
)
tablespace &DEPLOY_REPO_TBS_TABLE;

comment on table t_db_script_execution is '(Deployment) Incremental DB script''s execution = an T_DB_DEPLOYMENT instance of a T_DB_SCRIPT entry';

comment on column t_db_script_execution.id_db_script_execution is 'Synthetic primary key';
comment on column t_db_script_execution.fip_create is 'Creation timestamp of the script deployment entry in the DB repository';

comment on column t_db_script_execution.id_db_deployment is 'Reference to the deployment execution (ref: T_DB_DEPLOYMENT)';
comment on column t_db_script_execution.id_db_script is 'Reference to the increment script (ref: T_DB_SCRIPT)';
comment on column t_db_script_execution.num_order is 'Preset order of execution of the script within the deployment';

comment on column t_db_script_execution.fip_start is 'Timestamp of the script execution start';
comment on column t_db_script_execution.fip_finish is 'Timestamp of the script execution finish';
comment on column t_db_script_execution.num_return_code is 'Return code of the script run within SQL*Plus';
comment on column t_db_script_execution.txt_script_spool is 'Spool output of the script run within SQL*Plus';
comment on column t_db_script_execution.txt_script_stderr is 'STDERR output of the SQL*Plus having executed the script';

create unique index UQ_db_scr_exec$1_ok
on t_db_script_execution (case when num_return_code = 0 then id_db_script end)
tablespace &DEPLOY_REPO_TBS_INDEX
;

