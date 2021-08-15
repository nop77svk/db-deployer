grant select on common.t_db_app_h to deploy;
grant select on common.t_db_app_v to deploy;
grant select on common.t_db_deployment to deploy;
grant select on common.t_db_deploy_tgt to deploy;
grant select on common.t_db_increment to deploy;
grant select on common.t_db_script to deploy;
grant select on common.t_db_script_execution to deploy;

----------------------------------------------------------------------------------------------------

rollback;

delete from t_db_script_execution where app_v_id in (select app_v_id from t_db_app_v where app_id in (select app_id from common.t_db_app_h));
delete from t_db_app_v where app_id in (select app_id from common.t_db_app_h);
delete from t_db_increment where app_id in (select app_id from common.t_db_app_h);
delete from t_db_deploy_tgt where id_db_deployment in (select id_db_deployment from t_db_deployment where app_id in (select app_id from common.t_db_app_h));
delete from t_db_deployment where app_id in (select app_id from common.t_db_app_h);
delete from t_db_app_h where app_id in (select app_id from common.t_db_app_h);

insert into t_db_app_h (app_id)
select app_id
from common.t_db_app_h;

insert into t_db_app_v (app_v_id, app_id, d_ver_from, d_ver_to, ver_major, ver_minor, ver_maintenance, codename)
select seq_db_app_v.nextval, app_id, d_ver_from, d_ver_to, ver_major, ver_minor, ver_maintenance, codename
from common.t_db_app_v;

insert into t_db_increment (id_db_increment, fip_create, txt_folder, app_id)
select seq_db_deployment.nextval, fip_create, txt_folder, app_id
from common.t_db_increment I;

insert into t_db_script (id_db_script, fip_create, id_db_increment, txt_script_file)
select seq_db_deployment.nextval, S.fip_create, IT.id_db_increment, S.txt_script_file
from common.t_db_script S
    join common.t_db_increment IX
        on IX.id_db_increment = S.id_db_increment
    left join t_db_increment IT
        on IT.app_id = IX.app_id
        and IT.txt_folder = IX.txt_folder
;

insert into t_db_deployment (id_db_deployment, fip_create, xml_environment, app_id)
select seq_db_deployment.nextval, fip_create, xml_environment, app_id
from common.t_db_deployment;

insert into t_db_deploy_tgt (id_db_deploy_tgt, id_db_deployment, nam_target, txt_db_user, txt_db_db, num_member_target_seq, nam_member_target)
select seq_db_deployment.nextval, DT.id_db_deployment, T.nam_target, T.txt_db_user, T.txt_db_db, T.num_member_target_seq, T.nam_member_target
from common.t_db_deploy_tgt T
    join common.t_db_deployment DX
        on DX.id_db_deployment = T.id_db_deployment
    left join t_db_deployment DT
        on DT.app_id = DX.app_id
        and DT.fip_create = DX.fip_create
;

insert into t_db_script_execution (id_db_script_execution, fip_create, id_db_deployment, id_db_script, num_order, fip_start, fip_finish, num_return_code, txt_script_spool, txt_script_stderr, nam_deploy_target, app_v_id)
select seq_db_deployment.nextval, X1.fip_create, D2.id_db_deployment, S2.id_db_script, X1.num_order, X1.fip_start, X1.fip_finish, X1.num_return_code, X1.txt_script_spool, X1.txt_script_stderr, X1.nam_deploy_target, V2.app_v_id
from common.t_db_script_execution X1
    join common.t_db_deployment D1
        on D1.id_db_deployment = X1.id_db_deployment
    left join t_db_deployment D2
        on D2.app_id = D1.app_id
        and D2.fip_create = D1.fip_create
    join common.t_db_app_v V1
        on V1.app_v_id = X1.app_v_id
    left join t_db_app_v V2
        on V2.app_id = V1.app_id
        and V2.ver_major = V1.ver_major
        and V2.ver_minor = V1.ver_minor
        and V2.ver_maintenance = V1.ver_maintenance
    join common.t_db_script S1
        on S1.id_db_script = X1.id_db_script
    join common.t_db_increment I1
        on I1.id_db_increment = S1.id_db_increment
    left join t_db_increment I2
        on I2.app_id = V2.app_id
        and I2.txt_folder = I1.txt_folder
    left join t_db_script S2
        on S2.id_db_increment = I2.id_db_increment
        and S2.txt_script_file = S1.txt_script_file
;

rollback;
