whenever sqlerror continue

alter table t_db_script_execution drop constraint FK_db_scr_exec$depl_tgt_atomic;
alter table t_db_script_execution drop constraint PK_db_script_execution_2;
alter table t_db_script_execution drop column nam_deploy_target;

drop table t_db_deploy_tgt;
drop table tt_db_deploy_tgt;

drop view vt_db_deploy_tgt_grp_resolve;
drop view vtt_db_deploy_tgt_atomic;
drop view vtt_db_deploy_tgt_group;

whenever sqlerror exit failure rollback
