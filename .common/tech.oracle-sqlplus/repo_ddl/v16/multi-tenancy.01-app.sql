create table t_db_app_h
(
    app_id                          varchar2(32 byte) not null,
    constraint CK_db_app$id
        check ( regexp_like(app_id, '^[A-Za-z][A-Za-z0-9_-]*$') ),
    constraint PK_db_app_h
        primary key (app_id)
)
organization index
tablespace &deploy_repo_tbs_index
;

--------------------------------------------------------------------------------------------------

create sequence seq_db_app_v
    nocache
    nocycle;

create table t_db_app_v
(
    app_v_id                        integer /*generated as identity (nocache nocycle)*/ not null,
    constraint PK_app_v
        primary key (app_v_id)
        using index reverse tablespace &deploy_repo_tbs_index,
    --
    app_id                          varchar2(32 byte) not null,
    constraint FK_db_app_v$head
        foreign key (app_id)
        references t_db_app_h (app_id)
        on delete cascade,
    d_ver_from                      timestamp with local time zone default systimestamp not null,
    constraint UQ_db_app_v$head_from
        unique (app_id, d_ver_from)
        using index tablespace &deploy_repo_tbs_index,
    d_ver_to                        timestamp with local time zone,
    constraint CK_db_app_v$to_lt_from
        check (d_ver_from < d_ver_to),
    constraint UQ_db_app_v$to_head
        unique (d_ver_to, app_id)
        using index tablespace &deploy_repo_tbs_index,
    app_id$nt                       varchar2(32 byte) as (case when d_ver_to is not null then app_id end),
    constraint FK_db_app_v$adjoin
        foreign key (app_id$nt, d_ver_to)
        references t_db_app_v (app_id, d_ver_from)
        deferrable
        initially deferred,
    --
    ver_major                       integer not null,
    constraint CK_db_app$ver_maj
        check ( ver_major >= 0 ),
    ver_minor                       integer not null,
    constraint CK_db_app$ver_min
        check ( ver_minor >= 0 ),
    ver_maintenance                 integer default 0 not null,
    constraint CK_db_app$ver_maintn
        check ( ver_maintenance >= 0 ),
    codename                    nvarchar2(128)
)
tablespace &deploy_repo_tbs_table
;

comment on table t_db_app_v is '(Deployment) Applications (= deployment repository tenants) (versions)';

comment on column t_db_app_v.app_v_id is 'Synthetic primary key of Application version';
comment on column t_db_app_v.d_ver_from is 'Application version validity start (inclusive)';
comment on column t_db_app_v.d_ver_to is 'Application version validity end (exclusive)';
comment on column t_db_app_v.app_id$nt is '(Technical, Calculated) Application head reference on non-current Application versions';

comment on column t_db_app_v.app_id is 'Application identifier';
comment on column t_db_app_v.ver_major is 'Application version - major';
comment on column t_db_app_v.ver_minor is 'Application version - minor';
comment on column t_db_app_v.ver_maintenance is 'Application version - maintenance/hotfix/patch number';
comment on column t_db_app_v.codename is 'Application version codename';

----------------------------------------------------------------------------------------------------

create or replace view t_db_app
as
select app_v_id, app_id, d_ver_from, ver_major, ver_minor, ver_maintenance, codename
from t_db_app_v
where d_ver_to is null;

comment on table t_db_app is '(Deployment) Applications (= deployment repository tenants), the current version';

comment on column t_db_app.app_id is 'Application identifier';
comment on column t_db_app.ver_major is 'Application version - major';
comment on column t_db_app.ver_minor is 'Application version - minor';
comment on column t_db_app.ver_maintenance is 'Application version - maintenance/hotfix/patch number';
comment on column t_db_app.codename is 'Application version codename';

----------------------------------------------------------------------------------------------------

create or replace trigger trg_db_app$iriu
instead of insert or update on t_db_app
declare
    l_new                           t_db_app_v%rowtype;
    l_is_version_number_lower       boolean;
begin
    if inserting then
        insert into t_db_app_h (app_id)
        values (:new.app_id);
        
        l_new.d_ver_from := systimestamp;
        l_new.codename := :new.codename;
    elsif updating('APP_ID') or updating('D_VER_FROM') or updating('APP_V_ID') then
        raise_application_error(-20990, 'Cannot update primary key columns of T_DB_APP(_V)');
    elsif updating then
        update t_db_app_v T
        set T.d_ver_to = systimestamp
        where T.app_id = :old.app_id
            and T.d_ver_to is null
        returning T.app_id, T.d_ver_to, T.ver_major, T.ver_minor, T.ver_maintenance, T.codename
            into l_new.app_id, l_new.d_ver_from, l_new.ver_major, l_new.ver_minor, l_new.ver_maintenance, l_new.codename
        ;

        l_is_version_number_lower := :new.ver_major < l_new.ver_major
            or :new.ver_major = l_new.ver_major
                and :new.ver_minor < l_new.ver_minor
            or :new.ver_major = l_new.ver_major
                and :new.ver_minor = l_new.ver_minor
                and :new.ver_maintenance < l_new.ver_maintenance
        ;
        if l_is_version_number_lower then
            raise_application_error(-20990,
                'New application version "'||:new.ver_major||'.'||:new.ver_minor||'.'||:new.ver_maintenance||'" '||
                'must not be lower than '||
                'the previous version "'||l_new.ver_major||'.'||l_new.ver_minor||'.'||l_new.ver_maintenance||'"'
            );
        end if;

        if updating('CODENAME') then
            l_new.codename := :new.codename;
        end if;
    else
        raise_application_error(-20990, 'What are you trying to do?');
    end if;

    insert into t_db_app_v
        ( app_v_id, app_id, d_ver_from,
        ver_major, ver_minor, ver_maintenance, codename )
    values (
        seq_db_app_v.nextval, :new.app_id, l_new.d_ver_from,
        :new.ver_major, :new.ver_minor, :new.ver_maintenance, l_new.codename
    );
end;
/

