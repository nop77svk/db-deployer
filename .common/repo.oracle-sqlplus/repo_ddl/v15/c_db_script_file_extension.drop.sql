alter table t_db_script
drop constraint FK_db_increment$file_ext;

drop table c_db_script_file_extension;

alter table t_db_script
drop column cod_file_ext;
