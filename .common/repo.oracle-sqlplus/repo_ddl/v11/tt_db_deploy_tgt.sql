create global temporary table tt_db_deploy_tgt
(
    txt_config_var_assignment       varchar2(4000)
)
on commit delete rows
;

comment on table tt_db_deploy_tgt is '(Deployment) List of all "(dpltgt|dbgrp)_something=something" deployment targets configured to be parsed and merged into the T_DB_DEPLOY_TGT% tables for delta deployments';

comment on column tt_db_deploy_tgt.txt_config_var_assignment is 'The actual assignment';

---

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

