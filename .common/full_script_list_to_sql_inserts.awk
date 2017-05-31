# ${local_sed} "s/^.*$/insert into tt_db_full_inc_script_path (txt_script) values (q'{&}');/g"

BEGIN {
	BATCH_SIZE = 25;
	l_buffer = "";
	l_buffer_size = 0;
}

{
	l_buffer = l_buffer "\n\tinto tt_db_full_inc_script_path (txt_script) values (q'{" $0 "}')";
	l_buffer_size++;
}

l_buffer_size > 0 && l_buffer_size >= BATCH_SIZE {
	print "insert all" l_buffer "\nselect 1 from dual;\n";
	l_buffer_size = 0;
	l_buffer = "";
}

END {
	if (l_buffer_size > 0)
		print "insert all" l_buffer "\nselect 1 from dual;\n";
}
