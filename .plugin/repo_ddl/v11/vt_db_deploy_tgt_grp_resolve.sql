create or replace view vt_db_deploy_tgt_grp_resolve
as
with xyz(id_db_deployment, nam_root_target, nam_target, yn_atomic, txt_db_user, txt_db_db, num_member_target_seq, nam_member_target) as (
    select id_db_deployment, nam_target,
        nam_target, yn_atomic, txt_db_user, txt_db_db, num_member_target_seq, nam_member_target
    from t_db_deploy_tgt
    union all
    select X.id_db_deployment, X.nam_root_target, Y.nam_target, Y.yn_atomic, Y.txt_db_user, Y.txt_db_db, Y.num_member_target_seq, Y.nam_member_target
    from xyz X
        join t_db_deploy_tgt Y
            on Y.id_db_deployment = X.id_db_deployment
            and Y.nam_target = X.nam_member_target
    where X.yn_atomic = 'N'
)
search depth first
    by num_member_target_seq asc nulls first
    set recursive_order
select id_db_deployment, nam_root_target as nam_target, nam_target as nam_atomic_target, row_number() over (partition by id_db_deployment, nam_root_target order by recursive_order) as target_order
from xyz
where yn_atomic = 'Y'
order by id_db_deployment, recursive_order
;
