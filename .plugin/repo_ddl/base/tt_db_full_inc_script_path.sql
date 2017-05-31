create global temporary table tt_db_full_inc_script_path
(
    txt_script                      varchar2(4000)
)
on commit delete rows
;

comment on table tt_db_full_inc_script_path is '(Deployment) List of all script files with full path to be parsed and merged into the T_DB_% tables for delta deployments';

comment on column tt_db_full_inc_script_path.txt_script is 'Full (relative) path to a script file';
