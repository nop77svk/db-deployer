merge into t_db_meta T
using dual
on ( T.meta_name = 'deploy_repo_ver' )
when matched then update set T.meta_value = &1
when not matched then insert (meta_name, meta_value) values ('deploy_repo_ver', &1)
;
