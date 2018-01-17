create table c_db_script_file_extension
(
    cod_file_extension              varchar2(32) not null,
    constraint PK_db_script_file_extension
        primary key (cod_file_extension)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    txt_description                 nvarchar2(2000)
)
tablespace &DEPLOY_REPO_TBS_TABLE;

comment on table c_db_script_file_extension is '(Deployment) Allowed script file extensions';

comment on column c_db_script_file_extension.cod_file_extension is 'File extension';
comment on column c_db_script_file_extension.txt_description is 'File extension description';

---

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('sql', 'SQL*Plus script in general');

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('pck', 'PL/SQL package');
insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('spc', 'PL/SQL package specification');
insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('bdy', 'PL/SQL package body');

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('prc', 'PL/SQL schema-level procedure');
insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('fnc', 'PL/SQL schema-level function');

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('typ', 'Oracle object/class type');
insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('tps', 'Oracle object/class type specification');
insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('tpb', 'Oracle object/class type body');

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('trg', 'Trigger');

insert into c_db_script_file_extension (cod_file_extension, txt_description) values ('vw', 'View');

commit;
