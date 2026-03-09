BEGIN {
	if (outputClobVarName == "" || outputClobVarName == null)
		outputClobVarName = "io_clob_output";
	if (sessionCharset == "" || sessionCharset == null)
		sessionCharset = "";

	buffer = "";
	bufLen = 0;
	CHUNK_SIZE = 32000;

	print "declare";
	print "    l_base64_input_length           integer := 0;";
	print "    l_base64_decoded_gzip           blob;";
	print "    l_raw_chunk                     raw(32767);";
	print "    l_str_chunk                     varchar2(32767);";
	print "    l_original_bin                  blob;";
	print "    l_session_charset               constant varchar2(32) := nvl('" sessionCharset "', 'al32utf8');";
	print "    --";
	print "    l_doffs                         integer := 1;";
	print "    l_soffs                         integer := 1;";
	print "    l_langctx                       number := 0;";
	print "    l_warn                          number;";
	print "begin";
	print "    dbms_lob.createTemporary(l_base64_decoded_gzip, true, dbms_lob.call);";

	CHUNK_SIZE = int(CHUNK_SIZE / 6) * 6;
	print "    -- chunk size = \"" CHUNK_SIZE "\"";
}

{
	gensub(/[^A-Za-z0-9+\/]/, "", "g");
	if (bufLen + length($0) >= CHUNK_SIZE)
	{
		print "    --";
		print "    l_str_chunk := regexp_replace('" buffer "', '\\s+', null);";
        print "    l_base64_input_length := l_base64_input_length + length(l_str_chunk);";
		print "    l_raw_chunk := utl_encode.base64_decode(utl_raw.cast_to_raw(l_str_chunk));";
        print "    dbms_lob.writeAppend(l_base64_decoded_gzip, utl_raw.length(l_raw_chunk), l_raw_chunk);";

		buffer = "";
        bufLen = 0;
    }

	if (bufLen > 0)
		buffer = buffer "\n";
	buffer = buffer $0;
	bufLen = bufLen + length($0);
}

END {
	if (bufLen > 0)
	{
		print "    --";
		print "    l_str_chunk := regexp_replace('" buffer "', '\\s+', null);";
        print "    l_base64_input_length := l_base64_input_length + length(l_str_chunk);";
		print "    l_raw_chunk := utl_encode.base64_decode(utl_raw.cast_to_raw(l_str_chunk));";
        print "    dbms_lob.writeAppend(l_base64_decoded_gzip, utl_raw.length(l_raw_chunk), l_raw_chunk);";
	}

    print "    --";
	print "    dbms_output.put_line('Base64 input = \"'||l_base64_input_length||'\" bytes');";
	print "    dbms_output.put_line('GZIPped spool = \"'||dbms_lob.getLength(l_base64_decoded_gzip)||'\" bytes');";
    print "    --";
	print "    dbms_lob.createTemporary(l_original_bin, true, dbms_lob.call);";
	print "    utl_compress.lz_uncompress(";
	print "        src => l_base64_decoded_gzip,";
	print "        dst => l_original_bin";
	print "    );";
	print "    dbms_output.put_line('full size spool = \"'||dbms_lob.getLength(l_original_bin)||'\" bytes');";
	print "    dbms_output.put_line('charset for BLOB->CLOB conversion = \"'||l_session_charset||'\"');";
	print "    --";
	print "    if dbms_lob.getLength(l_original_bin) > 0 then";
	print "        dbms_lob.convertToClob(";
	print "            dest_lob => :" outputClobVarName ",";
	print "            src_blob => l_original_bin,";
	print "            amount => dbms_lob.lobmaxsize,";
	print "            dest_offset => l_doffs,";
	print "            src_offset => l_soffs,";
	print "            blob_csid => nls_charset_id(l_session_charset),";
	print "            lang_context => l_langctx,";
	print "            warning => l_warn";
	print "        );";
	print "    end if;";
	print "end;";
	print "/";
}
