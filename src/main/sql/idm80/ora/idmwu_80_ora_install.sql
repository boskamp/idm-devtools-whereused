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
--------------------------------------------------------
--  DDL for Type z_idmwu_clob_obj
--------------------------------------------------------
CREATE OR REPLACE TYPE z_idmwu_clob_obj AUTHID CURRENT_USER
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
CREATE OR REPLACE TYPE BODY z_idmwu_clob_obj
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
            dbms_sql.column_value_long( iv_dbms_sql_cursor ,3 --position of LONG column in cursor's SELECT list
            ,lv_buf_len ,lv_offset ,lv_buf_val ,lv_bytes_returned );
            EXIT
        WHEN lv_bytes_returned = 0;
            -- Concatentation operator vs. dbms_lob.append
            -- performed the same in my tests on 11g
            node_data := node_data || lv_buf_val;
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
        dbms_sql.define_column( iv_dbms_sql_cursor ,2 ,node_name ,2000 -- character length of node_name's data type
        );
        -- LONG column
        dbms_sql.define_column_long( iv_dbms_sql_cursor ,3 );
    END define_columns;
END;
/
--------------------------------------------------------
--  DDL for Type z_idmwu_clob_tab
--------------------------------------------------------
CREATE OR REPLACE TYPE Z_IDMWU_CLOB_TAB
-- =================================================
-- Specifying an invoker_rights_clause doesn't seem
-- to work for anything other than OBJECT types
-- =================================================
-- AUTHID CURRENT_USER
AS
    TABLE OF z_idmwu_clob_obj;
    /
    --------------------------------------------------------
    --  DDL for Package z_idmwu
    --------------------------------------------------------
CREATE OR REPLACE PACKAGE z_idmwu AUTHID CURRENT_USER
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
END z_idmwu;
/
--------------------------------------------------------
--  DDL for Package Body z_idmwu
--------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY z_idmwu
AS
    FUNCTION base64_decode(
            iv_base64 CLOB )
        RETURN CLOB
    AS
        lv_result CLOB;
        lv_substring VARCHAR2(4000 byte);
        lv_num_chars_to_read PLS_INTEGER   := 0;
        lv_offset PLS_INTEGER              := 1;
        lv_num_chars_remaining PLS_INTEGER := 0;
    BEGIN
        lv_num_chars_remaining := LENGTH(iv_base64) - lv_offset + 1;
        -- Create CLOB that will not be cached and free'd after this call
        dbms_lob.createtemporary(lv_result, FALSE, dbms_lob.call);
        WHILE lv_num_chars_remaining > 0
        LOOP
            lv_num_chars_to_read   := least(lv_num_chars_remaining, 2000);
            lv_substring           := dbms_lob.substr( iv_base64 ,lv_num_chars_to_read ,lv_offset );
            lv_offset              := lv_offset              + lv_num_chars_to_read;
            lv_num_chars_remaining := lv_num_chars_remaining - lv_num_chars_to_read;
            -- Concatentation operator vs. dbms_lob.append
            -- performed the same in my tests on 11g
            lv_result := lv_result || utl_raw.cast_to_varchar2( utl_encode.base64_decode( utl_raw.cast_to_raw(lv_substring) ) );
        END LOOP;
        RETURN lv_result;
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
        lv_query := 'SELECT ' || iv_id_column_name || ', ' || iv_name_column_name || ', ' || iv_long_column_name || ' FROM ' || iv_table_name ;
        -- Create cursor, parse and bind
        lv_dbms_sql_cursor := dbms_sql.open_cursor();
        dbms_sql.parse(lv_dbms_sql_cursor, lv_query, dbms_sql.native);
        -- Define columns through dummy object type instance
        lo_clob_object := z_idmwu_clob_obj();
        lo_clob_object.define_columns(lv_dbms_sql_cursor);
        -- Execute
        lv_execute_rc := dbms_sql.execute(lv_dbms_sql_cursor);
        -- ============================================================
        -- UNCOMMENT FOR DEBUGGING ONLY
        -- and ensure buffer for DBMS output is large enough
        -- ============================================================
        -- dbms_output.put_line('Cursor executed, RC=' || lv_execute_rc);
        -- ============================================================
        -- Fetch all rows, pipe each back
        WHILE dbms_sql.fetch_rows(lv_dbms_sql_cursor) > 0
        LOOP
            lo_clob_object := z_idmwu_clob_obj(lv_dbms_sql_cursor);
            PIPE ROW(lo_clob_object);
            -- ============================================================
            -- UNCOMMENT FOR DEBUGGING ONLY
            -- and ensure buffer for DBMS output is large enough
            -- ============================================================
            -- dbms_output.put_line(
            --     'Piped back table='
            --     || iv_table_name
            --     || ' ,node_id='
            --     || lo_clob_object.node_id
            --     || ', node_name='
            --     || lo_clob_object.node_name
            -- );
            -- ============================================================
        END LOOP;
        dbms_sql.close_cursor(lv_dbms_sql_cursor);
    EXCEPTION
    WHEN OTHERS THEN
        IF dbms_sql.is_open(lv_dbms_sql_cursor) THEN
            dbms_sql.close_cursor(lv_dbms_sql_cursor);
        END IF;
        RAISE;
    END read_tab_with_long_col_ptf;
END z_idmwu;
/
