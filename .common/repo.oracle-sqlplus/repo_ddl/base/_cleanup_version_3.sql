whenever sqlerror continue

drop view v_db_deployment_ok;
drop view v_db_deployment;

whenever sqlerror exit failure rollback
