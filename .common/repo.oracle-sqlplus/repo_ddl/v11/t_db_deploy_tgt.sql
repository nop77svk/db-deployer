create table t_db_deploy_tgt
(
    id_db_deploy_tgt                integer not null,
    constraint PK_db_deploy_tgt
        primary key (id_db_deploy_tgt)
        using index tablespace &DEPLOY_REPO_TBS_INDEX,
    --
    id_db_deployment                integer not null,
    constraint FK_db_deploy_tgt$deployment
        foreign key (id_db_deployment)
        references t_db_deployment (id_db_deployment),
    nam_target                      varchar2(32) not null,
    yn_atomic                       char(1) as (case when txt_db_user is not null then 'Y' when num_member_target_seq is not null then 'N' end),
    --
    txt_db_user                     varchar2(32),
    txt_db_db                       varchar2(256),
    constraint CK_db_deploy_tgt$atomic_nn
        check ( txt_db_user is null and txt_db_db is null
            or txt_db_user is not null and txt_db_db is not null ),
    --
    nam_atomic_target$              varchar2(32) as (case when txt_db_user is not null then nam_target end),
    id_atomic_db_deployment$        integer as (case when txt_db_user is not null then id_db_deployment end),
    constraint UQ_db_deploy_tgt$nam_atomic
        unique (id_atomic_db_deployment$, nam_atomic_target$)
        using index tablespace &DEPLOY_REPO_TBS_INDEX,
    --
    num_member_target_seq           integer,
    constraint CK_db_deploy_tgt$mmbr_seq_ge_1
        check ( num_member_target_seq >= 1 ),
    nam_member_target               varchar2(32),
    constraint CK_db_deploy_tgt$group_nn
        check ( num_member_target_seq is null and nam_member_target is null
            or num_member_target_seq is not null and nam_member_target is not null ),
    --
    constraint CK_db_deploy_tgt$atom_xor_grp
        check ( txt_db_user is null and num_member_target_seq is not null
            or txt_db_user is not null and num_member_target_seq is null )
)
tablespace &DEPLOY_REPO_TBS_TABLE
;

