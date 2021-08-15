/*
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_user=dqmadmin');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_password=xxxxxxxx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_db=dqm-local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_tbs_table=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_tbs_index=dqm_idx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_master_tbs_lob=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_user=dqmadmin_ldd');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_password=xxxxxxxx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_db=dqm-local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_tbs_table=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_tbs_index=dqm_idx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_local_tbs_lob=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_user=dqmadmin_ldd_2');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_password=xxxxxxxx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_db=dqm-local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_tbs_table=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_tbs_index=dqm_idx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_ldd_repl_tbs_lob=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_user=dqmadmin_aurep');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_password=xxxxxxxx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_db=dqm-local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_tbs_table=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_tbs_index=dqm_idx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_local_tbs_lob=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_user=dqmadmin_aurep_2');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_password=xxxxxxxx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_db=dqm-local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_tbs_table=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_tbs_index=dqm_idx');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dpltgt_aurep_repl_tbs_lob=dqm_dat');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_local=ldd_local,aurep_local');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_repl=ldd_repl,aurep_repl');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_ldd=ldd_local,ldd_repl');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_aurep=aurep_local,aurep_repl');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_upwards=local,repl,master');
insert into tt_db_deploy_tgt (txt_config_var_assignment) values ('dbgrp_downwards=master,repl,local');
*/

create or replace view vtt_db_deploy_tgt
as
select
    regexp_substr(txt_config_var_assignment, '^(.*)=(.*)$', 1, 1, null, 1) as txt_left_side,
    regexp_substr(txt_config_var_assignment, '^(.*)=(.*)$', 1, 1, null, 2) as txt_right_side
from tt_db_deploy_tgt
;


create or replace view vtt_db_deploy_tgt_atomic
as
with xyz as (
    select
        regexp_substr(txt_left_side, '^dpltgt_(.*)_(user|password|db|tbs_.*|flags|tech)$', 1, 1, 'i', 1) as deploy_target,
        regexp_substr(txt_left_side, '^dpltgt_(.*)_(user|password|db|tbs_.*|flags|tech)$', 1, 1, 'i', 2) as deploy_var_name,
        txt_right_side as deploy_var_value
    from vtt_db_deploy_tgt X
    where txt_left_side like 'dpltgt!_%' escape '!'
)
select deploy_target as target_name,
    user_val as target_user,
    password_val as target_password,
    db_val as target_db,
    flags_val as target_flags
from xyz pivot (
    min(deploy_var_value) as val
    for (deploy_var_name) in (
        'user' as "USER",
        'password' as "PASSWORD",
        'db' as "DB",
        'flags' as "FLAGS"
    )) X
;


create or replace view vtt_db_deploy_tgt_group
as
with groups$ as (
    select
        regexp_substr(txt_left_side, '^dbgrp_(.*)$', 1, 1, 'i', 1) as group_name,
        '|'||X.txt_right_side||'|' as group_contents
    from vtt_db_deploy_tgt X
    where txt_left_side like 'dbgrp!_%' escape '!'
),
groups_unpivot$(group_name, member_seq, member_name) as (
    select group_name, 0, null
    from groups$
    union all
    select X.group_name, X.member_seq+1, regexp_substr(G.group_contents, '[^,;:|]+', 1, X.member_seq+1)
    from groups_unpivot$ X
        join groups$ G
            on G.group_name = X.group_name
            and regexp_substr(G.group_contents, '[^,;:|]+', 1, X.member_seq+1) is not null
)
select GU.*
from groups_unpivot$ GU
where member_name is not null
order by group_name, member_seq
;
