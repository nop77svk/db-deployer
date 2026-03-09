create table t_db_deployment
(
    id_db_deployment                integer not null,
    constraint PK_db_deployment
        primary key (id_db_deployment)
        using index
        tablespace &DEPLOY_REPO_TBS_INDEX,
    fip_create                      timestamp with time zone default current_timestamp not null,
    xml_environment                 xmltype
)
xmltype xml_environment store as securefile binary xml (
    disable storage in row
    tablespace &DEPLOY_REPO_TBS_LOB
--    compress low
--    deduplicate
    chunk 256
)
tablespace &DEPLOY_REPO_TBS_TABLE;

comment on table t_db_deployment is '(Deployment) Execution instance of a deployment';

comment on column t_db_deployment.id_db_deployment is 'Synthetic primary key';
comment on column t_db_deployment.fip_create is 'Creation timestamp of the deployment in the DB repository';

comment on column t_db_deployment.xml_environment is 'Environment information in XML';

