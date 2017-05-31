whenever sqlerror continue

drop table tt_db_full_inc_script_path;
drop view vtt_db_inc_script_path;

whenever sqlerror exit failure rollback
