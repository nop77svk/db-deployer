whenever sqlerror continue

insert into c_db_script_file_extension (cod_file_extension, txt_description, yn_sqlplus_defines) values ('pks', 'PL/SQL package specification (TOAD-style)', 'N');
insert into c_db_script_file_extension (cod_file_extension, txt_description, yn_sqlplus_defines) values ('pkb', 'PL/SQL package body (TOAD-style)', 'N');
insert into c_db_script_file_extension (cod_file_extension, txt_description, yn_sqlplus_defines) values ('pkg', 'PL/SQL package (TOAD-style)', 'N');

whenever sqlerror exit failure rollback

commit;
