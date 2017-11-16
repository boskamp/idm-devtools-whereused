-- Copyright 2014 Lambert Boskamp
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- ========================================================================
--    THIS IS THE VERSION FOR SAP(R) IDM 8.0 ON ORACLE(R)
-- ========================================================================
--
-- The latest version of this code, as well as versions for
-- other SAP(R) IDM releases and other databases can be found at
--
--    https://github.com/boskamp/idm-devtools-whereused/
--
-- ========================================================================
--
-- Synopsis: INSTALL where-used query for use with SAP(R) IDM.
--
-- Usage:    1. If you have run this script before
--              and wish to update an existing installation,
--              YOU MUST RUN THE UNINSTALLER FIRST.
--
--           2. Use any SQL client, such as Oracle(R) SQL Developer,
--              to connect to the SAP(R) IDM database and execute this
--              script as OPER user (MXMC_OPER, by default).
--
-- Result:   You can now run the where-used query for use with
--           SAP(R) IDM as OPER user (MXMC_OPER, by default).
--
-- ========================================================================
-- NEW
--------------------------------------------------------
--  DDL for Type Z_IDMWU_CLOB_OBJ
--------------------------------------------------------

  CREATE OR REPLACE TYPE Z_IDMWU_CLOB_OBJ AUTHID CURRENT_USER
AS
    OBJECT
    (
        node_id   NUMBER(10,0) ,
        node_name VARCHAR2(4000 byte) ,
        node_data CLOB ,
        CONSTRUCTOR
    FUNCTION z_idmwu_clob_obj
        RETURN SELF
    AS
        RESULT ,
        CONSTRUCTOR
        FUNCTION z_idmwu_clob_obj(
                iv_dbms_sql_cursor IN INTEGER )
            RETURN SELF
        AS
            RESULT ,
            MEMBER PROCEDURE define_columns(
                    iv_dbms_sql_cursor IN INTEGER) );
                                        
/
CREATE OR REPLACE TYPE BODY Z_IDMWU_CLOB_OBJ
AS
    /**
    * Constructor. Sets all attributes to NULL.
    * @return  New object type instance.
    */
    CONSTRUCTOR
    FUNCTION z_idmwu_clob_obj
        RETURN SELF
    AS
        RESULT
    AS
    BEGIN
        RETURN;
    END z_idmwu_clob_obj;
/**
* Constructs a new instance with values fetched from DBMS_SQL cursor
*
* @param   IV_DBMS_SQL_CURSOR
* @return  new object type instance
*/
CONSTRUCTOR
    FUNCTION z_idmwu_clob_obj(
            iv_dbms_sql_cursor IN INTEGER)
        RETURN SELF
    AS
        RESULT
    AS
        lv_buf_val        VARCHAR2(32767 BYTE);
        lv_buf_len        INTEGER := 32767;
        lv_bytes_returned INTEGER;
        lv_offset         INTEGER := 0;
    BEGIN
        dbms_sql.column_value(iv_dbms_sql_cursor, 1, node_id);
        dbms_sql.column_value(iv_dbms_sql_cursor, 2, node_name);
        -- Create CLOB that will not be cached and free'd after this call
        dbms_lob.createtemporary(node_data, FALSE, dbms_lob.call);
        -- Piecewise fetching of the LONG column into VARCHAR2 buffer
        LOOP
            dbms_sql.column_value_long( 
                c => iv_dbms_sql_cursor 
                ,position => 3
                ,length => lv_buf_len 
                ,offset => lv_offset 
                ,value => lv_buf_val 
                ,value_length => lv_bytes_returned 
            );
            EXIT WHEN lv_bytes_returned = 0;

            -- Concatentation operator vs. dbms_lob.append?
            dbms_lob.writeappend(
                lob_loc => node_data
                ,amount => lv_bytes_returned
                ,buffer => lv_buf_val
            );

            --node_data := node_data || lv_buf_val;

            lv_offset := lv_offset + lv_bytes_returned;
        END LOOP;
        RETURN;
    END z_idmwu_clob_obj;
/**
* Defines all columns in DBMS_SQL cursor
*
* @param  IV_DBMS_SQL_CURSOR    parsed DBMS_SQL cursor
*/
MEMBER PROCEDURE define_columns(
            iv_dbms_sql_cursor IN INTEGER )
    AS
    BEGIN
        -- INT column
        dbms_sql.define_column( iv_dbms_sql_cursor ,1 ,node_id );
        -- VARCHAR2 column
        dbms_sql.define_column( --
        iv_dbms_sql_cursor      --cursor ID
        ,2                      -- column position, starting at 1
        ,node_name              -- value of the column being defined
        ,4000                   -- Max. size in bytes for VARCHAR2 columns
        );
        -- LONG column
        dbms_sql.define_column_long( iv_dbms_sql_cursor ,3 );
    END define_columns;
END;
/
--------------------------------------------------------
--  DDL for Type Z_IDMWU_CLOB_TAB
--------------------------------------------------------
CREATE OR REPLACE TYPE Z_IDMWU_CLOB_TAB
-- =================================================
-- Specifying an invoker_rights_clause doesn't seem
-- to work for anything other than OBJECT types
-- =================================================
-- AUTHID CURRENT_USER
AS
    TABLE OF Z_IDMWU_CLOB_OBJ;

/
--------------------------------------------------------
--  DDL for Package Z_IDMWU
--------------------------------------------------------
CREATE OR REPLACE PACKAGE Z_IDMWU AUTHID CURRENT_USER
AS
    /**
    * Public function BASE64_DECODE
    *
    * Special purpose BASE64 decoder which
    * assumes that the result of decoding is
    * not just any raw binary data, but charater-like
    * data which can be represented as a CLOB.
    *
    * @param: IV_BASE64 encoded data
    * @return decoded, character-like data
    */
    FUNCTION base64_decode(
            iv_base64 CLOB )
        RETURN CLOB;
    /**
    * Public function READ_TAB_WITH_LONG_COL_PTF
    *
    * Pipelined table function that reads from a source table
    * specified in IV_TABLE_NAME and converts LONG data stored
    * in column IV_LONG_COLUMN_NAME to CLOB on the fly.
    *
    * The table supplied in IV_TABLE_NAME must have one INT column
    * containing a unique ID for each row.
    * Provide the name of this column in IV_ID_COLUMN_NAME.
    *
    * Second, the table must have a char-like column containing
    * a NAME for each row.
    * Provide the name of this column in IV_NAME_COLUMN_NAME.
    *
    * The combination of ID, NAME and CLOB data (converted from
    * LONG) will be returned in a table whose rows have the
    * object type Z_IDMWU_CLOB_TAB.
    *
    * @param IV_TABLE_NAME        table to read from
    * @param IV_ID_COLUMN_NAME    ID column in table
    * @param IV_NAME_COLUMN_NAME  name column in table
    * @param IV_LONG_COLUMN_NAME  column in table with LONG data
    * @return                     table of ID, name and CLOB data
    */
    FUNCTION read_tab_with_long_col_ptf(
            iv_table_name       VARCHAR2 ,
            iv_id_column_name   VARCHAR2 ,
            iv_name_column_name VARCHAR2 ,
            iv_long_column_name VARCHAR2 )
        RETURN z_idmwu_clob_tab PIPELINED;
    /**
    * Public function FILTER_READ_SOURCE_PTF
    * @param IV_SEARCH_TERM     (optional) string to search for
    * @return                   table of ID name and CLOB data
    */
    FUNCTION filter_read_source_ptf(
            iv_search_term VARCHAR2 )
        RETURN z_idmwu_clob_tab pipelined;
    PROCEDURE my_test;
END Z_IDMWU;
/


CREATE OR REPLACE PACKAGE BODY Z_IDMWU
AS
    PROCEDURE my_test
    AS
        lv_char clob;
        lv_xml xmltype;
        lv_substr varchar2(4000 byte);
    BEGIN
            FOR lo_test IN
            (
            select * from table(
                read_tab_with_long_col_ptf(
                     iv_table_name => 'MC_JOBS'
                    ,iv_id_column_name => 'JOBID'
                    ,iv_name_column_name => 'NAME'
                    ,iv_long_column_name => 'JOBDEFINITION'               
                )
           )
           --where node_name='00 Generic Test'
           )
            LOOP
                lv_char := base64_decode(lo_test.node_data);
                    lv_substr := dbms_lob.substr(
                    lob_loc => lv_char
                    ,amount => 1000
                    ,offset => 1
                );
                dbms_output.put_line(lv_substr);
                
                select xmlparse(document lv_char) into lv_xml from dual;
                dbms_output.put_line(
                    'NODE_ID: ' 
                    || cast(lo_test.node_id as VARCHAR2));
            END LOOP;
    END my_test;
   
    FUNCTION base64_decode(
            iv_base64 CLOB )
        RETURN CLOB
    AS
        lv_b64_decoded_binary BLOB;
        lv_b64_decoded_char CLOB;
        lv_clob_offset integer := 1;
        lv_clob_len integer := length( iv_base64 );
        lv_raw_buffer raw(32767);
        lv_raw_len integer;
        lv_varchar2_buffer varchar2(32767 byte);
        lv_varchar2_len integer;
        lv_divisible_by_4_len integer;
        lv_dest_offset integer := 1;
        lv_src_offset integer := 1;
        lv_lang_context integer := dbms_lob.default_lang_ctx;
        lv_warning integer := dbms_lob.no_warning;
        lv_blob_csid integer;
        lv_amount integer;
    BEGIN
        select nls_charset_id('AL32UTF8') into lv_blob_csid from dual;
        
        -- Create LOB as buffer for BASE64-decoded binary data
         dbms_lob.createtemporary(
            lob_loc => lv_b64_decoded_binary
            ,cache => FALSE
            ,dur => dbms_lob.call
        );
        
        -- Create CLOB for overall result
        dbms_lob.createtemporary(
            lob_loc => lv_b64_decoded_char
            ,cache => FALSE
            ,dur => dbms_lob.call
        );

        --If input starts with {B64}, ignore this prefix
        if instr(iv_base64, '{B64}') = 1 then
            lv_clob_offset := lv_clob_offset + length('{B64}');
        end if;
        
         WHILE NOT lv_clob_offset > lv_clob_len 
        LOOP
            lv_amount := least(lv_clob_len - lv_clob_offset + 1, 32767);
            
            lv_varchar2_buffer := dbms_lob.substr(
                lob_loc => iv_base64
                ,amount => lv_amount
                ,offset => lv_clob_offset
             );

            lv_varchar2_len := length( lv_varchar2_buffer );
            lv_divisible_by_4_len := floor(lv_varchar2_len/4) * 4;         
            
            if lv_divisible_by_4_len > 0 and lv_varchar2_len > lv_divisible_by_4_len then
                lv_varchar2_buffer := substr(
                     lv_varchar2_buffer --char
                     ,1 --position
                     ,lv_divisible_by_4_len --substring_length
                );
            else
                -- Handle cases where lv_varchar2_len < 4, end if input
                lv_divisible_by_4_len := lv_varchar2_len;
            end if;
            
            lv_clob_offset := lv_clob_offset + lv_divisible_by_4_len;
                      
            lv_raw_buffer := utl_encode.base64_decode(utl_raw.cast_to_raw(lv_varchar2_buffer));
            lv_raw_len := utl_raw.length(lv_raw_buffer);
            
            dbms_lob.writeappend(
               lob_loc => lv_b64_decoded_binary
               ,amount => lv_raw_len
               ,buffer => lv_raw_buffer
            );
            
        END LOOP;
        
        dbms_lob.converttoclob(
            dest_lob => lv_b64_decoded_char
            ,src_blob => lv_b64_decoded_binary
            ,amount => dbms_lob.getlength(lv_b64_decoded_binary)
            ,dest_offset => lv_dest_offset
            ,src_offset => lv_src_offset
            ,blob_csid => lv_blob_csid
            ,lang_context => lv_lang_context
            ,warning => lv_warning
        );
        
        dbms_lob.freetemporary( lob_loc => lv_b64_decoded_binary );
        
        RETURN lv_b64_decoded_char;
    END base64_decode;

    FUNCTION read_tab_with_long_col_ptf(
            iv_table_name       VARCHAR2 ,
            iv_id_column_name   VARCHAR2 ,
            iv_name_column_name VARCHAR2 ,
            iv_long_column_name VARCHAR2 )
        RETURN z_idmwu_clob_tab PIPELINED
    AS
        lv_query           VARCHAR2(2000);
        lv_dbms_sql_cursor INTEGER;
        lv_execute_rc PLS_INTEGER;
        lo_clob_object z_idmwu_clob_obj;
    BEGIN
        lv_query
            := 'SELECT '
            || iv_id_column_name
            || ', '
            || iv_name_column_name
            || ', '
            || iv_long_column_name
            || ' FROM '
            || iv_table_name
            || ' WHERE '
            || iv_long_column_name
            || ' IS NOT NULL'
            ;

         -- Create cursor, parse and bind
        lv_dbms_sql_cursor := dbms_sql.open_cursor();
        dbms_sql.parse(lv_dbms_sql_cursor, lv_query, dbms_sql.native);

        -- Define columns through dummy object type instance
        lo_clob_object := z_idmwu_clob_obj();
        lo_clob_object.define_columns(lv_dbms_sql_cursor);

        -- Execute
        lv_execute_rc := dbms_sql.execute(lv_dbms_sql_cursor);

        -- Fetch all rows, pipe each back
        WHILE dbms_sql.fetch_rows(lv_dbms_sql_cursor) > 0
        LOOP
            lo_clob_object := z_idmwu_clob_obj(lv_dbms_sql_cursor);
            PIPE ROW(lo_clob_object);
        END LOOP;
        dbms_sql.close_cursor(lv_dbms_sql_cursor);
    EXCEPTION
        WHEN OTHERS THEN
            if dbms_sql.is_open(lv_dbms_sql_cursor) THEN
                dbms_sql.close_cursor(lv_dbms_sql_cursor);
            end if;
            RAISE;
    END read_tab_with_long_col_ptf;

    FUNCTION filter_read_source_ptf(
            iv_search_term VARCHAR2 )
        RETURN z_idmwu_clob_tab PIPELINED
    AS
        lo_clob_object z_idmwu_clob_obj;
        lv_object_type user_objects.object_type%TYPE;
    BEGIN
        FOR ls_source IN
        (
            SELECT distinct a.object_id
            ,a.object_type
            ,a.object_name
            FROM user_objects a
            INNER JOIN user_source b
            ON  a.object_name=b.name
            AND a.object_type=b.type
            --Case insensitive pre-select only source objects
            --containing the input search term.
            --Note that string || null results in string on Oracle,
            --so this works fine with null input.
            WHERE upper(b.text) like '%'||upper(iv_search_term)||'%'
        )      
        LOOP
            lo_clob_object := NEW z_idmwu_clob_obj();
            lo_clob_object.node_id := ls_source.object_id;
            lo_clob_object.node_name := ls_source.object_name;

            --USER_OBJECTS.OBJECT_TYPE contains spaces for some object types,
            --such as "PACKAGE BODY" and "TYPE BODY". The actual object type
            --expected by DBMS_METADATA uses underscore as a separator, though.
            --See https://docs.oracle.com/cd/B19306_01/appdev.102/b14258/d_metada.htm#i997127
            lv_object_type := replace(ls_source.object_type, ' ', '_');
            
            lo_clob_object.node_data := dbms_metadata.get_ddl(
                object_type => lv_object_type
                ,name => ls_source.object_name 
            );
            pipe row(lo_clob_object);            
        END LOOP;

        --Pipe last row collected by loop, if any
        if lo_clob_object is not null then
                PIPE ROW(lo_clob_object);
        end if;

    END filter_read_source_ptf;
END Z_IDMWU;
/
