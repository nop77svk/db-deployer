alter table deploy.t_db_increment drop constraint uq_db_increment$folder;
alter table deploy.t_db_increment add constraint uq_db_increment$folder unique (app_id, txt_folder) using index tablespace &deploy_repo_tbs_index;
