whenever sqlerror continue

drop table t_db_meta;

whenever sqlerror exit failure rollback
