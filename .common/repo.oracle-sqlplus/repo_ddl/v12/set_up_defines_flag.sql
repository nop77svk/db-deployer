update c_db_script_file_extension
set yn_sqlplus_defines = 'N'
where cod_file_extension in ('pkg','pck','pks','pkb','spc','bdy','tps','tpb','typ','trg')
;
