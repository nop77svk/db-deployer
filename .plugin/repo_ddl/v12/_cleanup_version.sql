whenever sqlerror continue

alter table c_db_script_file_extension
drop column yn_sqlplus_defines;

whenever sqlerror exit failure rollback

commit;
