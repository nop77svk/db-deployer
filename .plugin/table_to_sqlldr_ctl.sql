whenever sqlerror exit sql.sqlcode rollback
whenever oserror exit failure rollback

define TABLE_NAME = 'v_db_deployment_ok'
define ORDERING_COLUMNS = 'txt_folder, txt_script_file, nam_deploy_target'

rem prompt Generating CTL-file for table "&TABLE_NAME" with ordering of "&ORDERING_COLUMNS" ...

set verify off
set echo off
set recsep off
set headsep off
set wrap on
set linesize 32767
set trimspool on
set trimout on
set newpage none
set feedback off
set heading off
set termout off
set long 100000
set longchunksize 100000

alter session set nls_numeric_characters = '. ';
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
alter session set nls_timestamp_format = 'yyyy-mm-dd hh24:mi:ss.ff9';
alter session set nls_timestamp_tz_format = 'yyyy-mm-dd hh24:mi:ss.ff9 tzh/tzm';

--------------
col xx new_val COLUMN_LIST_FORMATTED

select listagg('''@..''||'||lower(column_name)||'||''..@''', '||chr(9)||') within group (order by TC.column_id asc) as xx
from user_tab_cols TC
where TC.table_name = upper('&TABLE_NAME')
    and (lnnvl(TC.virtual_column = 'YES') or TC.data_type_owner = 'SYS' and TC.data_type = 'XMLTYPE')
    and lnnvl(TC.hidden_column = 'YES')
	and TC.data_type not in ('BLOB','BFILE','CLOB','NCLOB')
order by TC.column_id asc;

--------------
spool &TABLE_NAME..ctl

select q'{options (
    skip = 0,
    direct = false
)
load
    characterset utf8
    infile * "str '<eor>\n'"
    badfile '&TABLE_NAME..bad'
    discardfile '&TABLE_NAME..discard'
into table &TABLE_NAME
    replace
fields terminated by '	'
    optionally enclosed by '@..' and '..@'
    trailing nullcols
(}' from dual;

select '    '||
    lower(column_name)||
    case
        when TC.data_type in ('CHAR','VARCHAR2','NVARCHAR2','NCHAR')
            then '    char('||decode(TC.data_type,
				'CLOB', 32767,
				'NCLOB', 32767,
				'CHAR', TC.data_length,
				'VARCHAR2', TC.data_length,
				'NCHAR', 2*TC.data_length,
				'NVARCHAR2', 2*TC.data_length,
				TC.data_length
			)||')' -- '    "replace(replace(replace(:'||lower(TC.column_name)||q'{, '\\r', chr(13)), '\\n', chr(10)), '\\\\', '\\')"}'
        when TC.data_type in ('DATE')
            then '    char(64)' -- '    "to_date(:'||lower(TC.column_name)||', ''yyyy-mm-dd hh24:mi:ss'')"'
        when TC.data_type in ('TIMESTAMP')
            then '    char(64)' -- '    "to_timestamp(:'||lower(TC.column_name)||', ''yyyy-mm-dd hh24:mi:ss.ff9'')"'
        when TC.data_type like 'TIMESTAMP(%) WITH TIME ZONE'
            then '    char(64)' -- '    "to_timestamp_tz(:'||lower(TC.column_name)||', ''yyyy-mm-dd hh24:mi:ss.ff9 tzh/tzm'')"'
        when TC.data_type in ('XMLTYPE')
            then '    char(4000)'
    end||
    decode(row_number() over (partition by null order by column_id desc), 1,null, ',') as x
from user_tab_cols TC
where TC.table_name = upper('&TABLE_NAME')
    and (lnnvl(TC.virtual_column = 'YES') or TC.data_type_owner = 'SYS' and TC.data_type = 'XMLTYPE')
    and lnnvl(TC.hidden_column = 'YES')
	and TC.data_type not in ('BLOB','BFILE','CLOB','NCLOB')
order by TC.column_id asc;

select q'{)
begindata}' as x
from dual;

--------------
select &COLUMN_LIST_FORMATTED||chr(9)||'<eor>'
from &TABLE_NAME
order by &ORDERING_COLUMNS;

--------------
spool off
exit success
