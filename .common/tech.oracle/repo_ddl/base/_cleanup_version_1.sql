whenever sqlerror continue

drop table t_db_script_execution;
drop table t_db_deployment;
drop table t_db_script;
drop table t_db_increment;
drop sequence seq_db_deployment;
drop table c_db_script_file_extension;

whenever sqlerror exit failure rollback
