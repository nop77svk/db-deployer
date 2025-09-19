create or replace view vtt_db_inc_script_path
as
with strip_leading_folder$ as (
    select regexp_replace(txt_script, '^\./', null) as txt_script
    from tt_db_full_inc_script_path
)
select
    regexp_substr(FP.txt_script, '^(.*)/([^/]*)$', 1, 1, null, 1) as txt_path,
    regexp_substr(FP.txt_script, '^(.*)/([^/]*)$', 1, 1, null, 2) as txt_file
from strip_leading_folder$ FP
;

comment on table vtt_db_inc_script_path is '(Deployment) Parsed contents of TT_DB_FULL_INC_SCRIPT_PATH';
