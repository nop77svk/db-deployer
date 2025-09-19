insert into t_db_app (app_id, ver_major, ver_minor, ver_maintenance, codename)
values ('&deploy_cfg_app_id', 0, 0, 0, 'prototype');

update t_db_increment T
set T.app_id = '&deploy_cfg_app_id'
where T.app_id is null;

commit;

alter table t_db_increment modify app_id not null;
