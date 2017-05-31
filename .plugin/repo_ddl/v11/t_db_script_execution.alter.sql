alter table t_db_script_execution
add (
    nam_deploy_target               varchar2(32),
    constraint FK_db_scr_exec$depl_tgt_atomic
        foreign key (id_db_deployment, nam_deploy_target)
        references t_db_deploy_tgt (id_atomic_db_deployment$, nam_atomic_target$)
);

---

whenever sqlerror continue

alter table t_db_script_execution
drop constraint PK_db_script_execution_2;

whenever sqlerror exit failure rollback

alter table t_db_script_execution
add constraint PK_db_script_execution_2
        unique (id_db_script, nam_deploy_target, id_db_deployment)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX
;

---

whenever sqlerror continue

drop index UQ_db_scr_exec$1_ok;

whenever sqlerror exit failure rollback

create unique index UQ_db_scr_exec$1_ok
on t_db_script_execution (
    case when num_return_code = 0 then id_db_script end,
    case when num_return_code = 0 then nam_deploy_target end
)
tablespace &DEPLOY_REPO_TBS_INDEX
;
