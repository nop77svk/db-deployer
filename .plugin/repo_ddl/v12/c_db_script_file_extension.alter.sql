alter table c_db_script_file_extension
add (
	yn_sqlplus_defines char(1) default 'Y' not null,
	constraint CK_db_scr_file_ext$sqlpl_def
		check (yn_sqlplus_defines in ('Y','N'))
);

