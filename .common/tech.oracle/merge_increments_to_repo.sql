prompt --- trace @ merge_increments_to_repo.sql

/* sample data ...
delete from tt_db_full_inc_script_path;
insert into tt_db_full_inc_script_path (txt_script) values (q'{data_fixes/20150814-1534;dvf_dvt_discrepancies/001-utl_ind_intfc_gen;default.pck}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{data_fixes/20150814-1534;dvf_dvt_discrepancies/002-v_all_generic_ds;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{data_fixes/20150814-1534;dvf_dvt_discrepancies/003-v_all_indicators;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{data_fixes/20150814-1534;dvf_dvt_discrepancies/005-reset behaviour of TOVR_AGR;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/002-t_signal_view;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/003-t_task_view;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/004-utl_ind_intfc_gen;default.pck}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/005-v_all_generic_ds_view;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/006-deploy2_repo_columns;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/007-v_all_indicators_view;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{db_resync/20150814-0935/008-v_db_deployment;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{metadata/20150812-1628/002-delete_codelist_for_786;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{metadata/20150812-1628/003-other_reasoning_made_last_eval_option;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150812-1242;dvf-dvt instead of source_dt/001-utl_rep_snapshot;default.pck}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150812-1242;dvf-dvt instead of source_dt/004-regenerate snapshots;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150814-1702;entity-enhanced C_REP_GENERATION/001-remove C_REP_GENERATION;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150814-1702;entity-enhanced C_REP_GENERATION/002-t_rep_generation;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150814-1702;entity-enhanced C_REP_GENERATION/003-utl_rep_snapshot;default.pck}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150814-1702;entity-enhanced C_REP_GENERATION/004-fill in T_REP_GENERATION;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150814-1702;entity-enhanced C_REP_GENERATION/005-v_rep_generation;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/001-t_rep_dom_client_eligibility;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/002-v_rep_dom_client_eligibility;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/003-t_rep_dom_lam_unit;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/004-v_rep_dom_lam_unit;default.sql}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/005-utl_rep_snapshot;default.pck}');
insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/006-prefill t_rep_dom_lam_unit;default.sql}');

insert into tt_db_full_inc_script_path (txt_script) values (q'{reporting/20150818-1121;additional input filters/007-prefill t_rep_dom_lam_unit;default.sql~}');
*/

prompt --- remove never-succeeded, now-removed-from-filesystem scripts from repository and/or deployment run

update t_db_script_execution FX
set FX.num_return_code = -1,
    FX.fip_finish = systimestamp
where lnnvl(FX.num_return_code = 0)
    and exists (
        select 1
        from t_db_script F
            join t_db_increment I
                on I.id_db_increment = F.id_db_increment
        where F.id_db_script = FX.id_db_script
            and not exists (
                select 1
                from vtt_db_inc_script_path FP
                where FP.txt_path = I.txt_folder
                    and FP.txt_file = F.txt_script_file
            )
    );

delete from (
    select F.id_db_script, F.id_db_increment, I.txt_folder, F.txt_script_file
    from t_db_script F
        join t_db_increment I
            on I.id_db_increment = F.id_db_increment
) T
where
    not exists (
        select 1
        from vtt_db_inc_script_path FP
        where FP.txt_path = T.txt_folder
            and FP.txt_file = T.txt_script_file
    )
    and not exists (
        select 1
        from t_db_script_execution FX
        where FX.id_db_script = T.id_db_script
            and FX.num_return_code = 0
    )
;

prompt --- removing empty, now-removed-from-filesystem increments from repository

delete from t_db_increment I
where
    not exists (
        select 1
        from t_db_script F
        where F.id_db_increment = I.id_db_increment
    )
    and not exists (
        select 1
        from vtt_db_inc_script_path X
        where X.txt_path = I.txt_folder
    )
;

prompt --- loading new increment packages into repository

declare
    E_Bulk_DML_Error                exception;
    CE_Bulk_DML_Error               constant pls_integer := -24381;
        pragma exception_init(E_Bulk_DML_Error, -24381);
    l_failed_packages               varchar2(1000);
    --
    cursor cur_db_package           is
        with unique_new_paths$ as (
            select unique FP.txt_path
            from vtt_db_inc_script_path FP
            where not exists (
                select 1
                from t_db_increment I
                where I.txt_folder = FP.txt_path
            )
        )
        select txt_path
        from unique_new_paths$
    ;
    subtype rec_db_package          is cur_db_package%rowtype;
    type arr_db_package             is table of rec_db_package index by pls_integer;
    l_db_package                    arr_db_package;
begin
    savepoint sp_merge_packages;

    lock table t_db_increment in share mode wait 3;
    lock table tt_db_full_inc_script_path in share mode wait 3;

    open cur_db_package;
    fetch cur_db_package bulk collect into l_db_package;
    close cur_db_package;

    begin
        forall i in indices of l_db_package save exceptions
            insert into t_db_increment (id_db_increment, txt_folder)
            values (seq_db_deployment.nextval, l_db_package(i).txt_path);
    exception
        when E_Bulk_DML_Error then
            begin
                for i in 1..sql%bulk_exceptions.count loop
                    l_failed_packages := l_failed_packages||chr(10)||
                        ' * '||l_db_package(sql%bulk_exceptions(i).error_index).txt_path||' ('||sqlerrm(-sql%bulk_exceptions(i).error_code)||')';
                end loop;
            exception
                when value_error then
                    raise_application_error(-20990, '???', true);
            end;
            raise_application_error(-20990, 'Following increment packages failed to be loaded to repository:'||l_failed_packages);
    end;

    dbms_output.put_line(l_db_package.count()||' new increment packages loaded');
exception
    when others then
        rollback to sp_merge_packages;
        raise;
end;
/

prompt --- loading new increment scripts into repository

declare
    E_Bulk_DML_Error                exception;
    CE_Bulk_DML_Error               constant pls_integer := -24381;
        pragma exception_init(E_Bulk_DML_Error, -24381);
    l_failed_scripts                varchar2(1000);
    --
    cursor cur_db_script            is
        select I.id_db_increment, FP.txt_path, FP.txt_file
        from vtt_db_inc_script_path FP
            join t_db_increment I
                on I.txt_folder = FP.txt_path
        where
            not exists (
                select 1
                from t_db_script F
                where F.id_db_increment = I.id_db_increment
                    and F.txt_script_file = FP.txt_file
            );
    subtype rec_db_script           is cur_db_script%rowtype;
    type arr_db_script              is table of rec_db_script index by pls_integer;
    l_db_script                     arr_db_script;
begin
    savepoint sp_merge_scripts;

    lock table t_db_increment in share mode wait 3;
    lock table tt_db_full_inc_script_path in share mode wait 3;

    open cur_db_script;
    fetch cur_db_script bulk collect into l_db_script;
    close cur_db_script;

    begin
        forall i in indices of l_db_script save exceptions
            insert into t_db_script ( id_db_script, id_db_increment, txt_script_file )
            values ( seq_db_deployment.nextval, l_db_script(i).id_db_increment, l_db_script(i).txt_file);
    exception
        when E_Bulk_DML_Error then
            begin
                for i in 1..sql%bulk_exceptions.count loop
                    l_failed_scripts := l_failed_scripts||chr(10)||
                        ' * '||l_db_script(sql%bulk_exceptions(i).error_index).txt_path||'/'||l_db_script(sql%bulk_exceptions(i).error_index).txt_file||' ('||sqlerrm(-sql%bulk_exceptions(i).error_code)||')';
                end loop;
            exception
                when value_error then
                    null;
            end;
            raise_application_error(-20990, 'Following increment scripts failed to be loaded to repository:'||l_failed_scripts);
    end;

    dbms_output.put_line(l_db_script.count()||' new increment scripts loaded');
exception
    when others then
        rollback to sp_merge_scripts;
        raise;
end;
/

prompt --- checking the repository for obvious errors

begin
    for cv in (
        with detect$ as (
            select
                id_db_increment, I.txt_folder, max(FX.fip_finish) over (partition by id_db_increment) as d_inc_finish,
                id_db_script, F.txt_script_file, F.num_order, FX.fip_start as d_scr_start, FX.fip_finish as d_scr_finish,
                count(FX.fip_start) over (partition by id_db_increment order by F.num_order asc rows between current row and unbounded following) as scripts_started_after
            from t_db_increment I
                join t_db_script F
                    using (id_db_increment)
                left join (
                    select id_db_script, min(fip_start) as fip_start, max(fip_finish) as fip_finish
                    from t_db_script_execution
                    group by id_db_script
                ) FX
                    using (id_db_script)
        )
        select *
        from detect$
        where ( d_scr_start is null and scripts_started_after > 0 )
--            or d_inc_finish is not null
        order by id_db_increment, num_order
    ) loop
        if cv.scripts_started_after > 0 then
            raise_application_error(-20990, 'Script "'||cv.txt_script_file||'" added to the middle of a run increment package "'||cv.txt_folder||'" ID "'||cv.id_db_increment||'" !');
/*
        elsif cv.d_inc_finish is not null then
            raise_application_error(-20990, 'Script "'||cv.txt_script_file||'" added to already '||case when cv.d_inc_finish is null then 'started' else 'finished' end||' increment package "'||cv.txt_folder||'" ID "'||cv.id_db_increment||'" !');
*/
        else
            raise_application_error(-20990, 'Script "'||cv.txt_script_file||'" cannot be added to increment package increment package "'||cv.txt_folder||'" ID "'||cv.id_db_increment||'" for unknown reason. Please inspect!');
        end if;
    end loop;
end;
/

