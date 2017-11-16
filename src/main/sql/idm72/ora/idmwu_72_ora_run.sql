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
--    THIS IS THE VERSION FOR SAP(R) IDM 7.2 ON ORACLE(R)
-- ========================================================================
--
-- The latest version of this code, as well as versions for
-- other SAP(R) IDM releases and other databases can be found at
--
--    https://github.com/boskamp/idm-devtools-whereused/
--
-- ========================================================================
--
-- Synopsis: Find any string in SAP(R) Identity Management (IDM)
--           JavaScript or SQL source code, job definitions or tasks.
--
-- Usage:    1. Before you can use this query, YOU MUST RUN THE
--              INSTALLER once.
--
--           2. Paste this source code into the SQL editor of any
--              graphical SQL client that can display CLOB and/or
--              XML data. Microsoft(R) SQL Server Management Studio,
--              Oracle(R) SQL Developer and IBM(R) Data Studio are
--              known to work fine. Others may work as well.
--
--           3. In the SQL editor, replace YOUR_SEARCH_TERM_HERE
--              near the end of the code with the string you want
--              to search for. See also section "Example".
--
--           4. Execute the resulting query as OPER user (MXMC_OPER).
--
--           5. (Optional) Examine MATCH_LOCATION_TEXT and MATCH_DOCUMENT
--              values of the result set directly in the SQL client.
--
--           6. (Optional) TODO: describe locate tasks or jobs
--
-- Example:  To search for all occurrences of the string MX_DISABLED,
--           modify the query near the top like this:
--
--           WITH search_term_cte(st) AS
--                (
--                    SELECT 'MX_DISABLED' FROM dual
--                )
--
--           Search is CASE-INSENSITIVE and uses SUBSTRING MATCHING,
--           so this query would find any of the following strings,
--           for instance:
--
--           MX_DISABLED
--           mx_disabled
--           #mx_disabled
--
-- Result:   The result set will list any locations that contain your
--           search term. Its rows have the following structure:
--
--           1. NODE_TYPE           : char(1)
--           2. NODE_ID             : number(10,0)
--           3. NODE_NAME           : varchar2(4000 byte)
--           4. MATCH_LOCATION_TEXT : clob
--           5. MATCH_DOCUMENT      : xmltype
--
--           NODE_TYPE = [ 'A' -- Attribute (Identity Store attribute)
--                       | 'T' -- Task
--                       | 'S' -- Script (global script)
--                       | 'J' -- Job
--                       ]
--
--           NODE_ID   = [ attribute_id
--                       | task_id
--                       | script_id
--                       | job_id
--                       ]
--
--           NODE_NAME = [ attribute_name
--                       | task_name
--                       | script_name
--                       | job_name
--                       ]
--
--           MATCH_LOCATION_TEXT is a piece of text contained in
--           MATCH_DOCUMENT. This piece of text contains your search
--           term at least once.
--
--           MATCH_DOCUMENT is an XML representation of the whole
--           designtime object (attribute, task, script or job)
--           identified by NODE_TYPE and NODE_ID.
--
--           For MATCH_DOCUMENTs that contain your search term multiple
--           times, the result set will generally contain multiple lines
--           which differ only in their MATCH_LOCATION_TEXT values.
--
-- Credits:  Martin Smith http://stackoverflow.com/users/73226/martin-smith
--           Thanks for explaining how to display large text in SSMS
--
--           Finn Ellebaek Nielsen https://ellebaek.wordpress.com
--           Thanks for explaining how to convert LONG to CLOB on the fly
--
-- *******************************************************************
WITH search_term_cte(st) AS
    (
        SELECT 'YOUR_SEARCH_TERM_HERE' FROM dual
    )
,xml_datasource_cte(node_id,node_type,node_name,native_xml) AS
    (
        SELECT a.attr_id
          ,'A' -- Attribute
          ,a.attrname
          ,xmlroot(            --
            xmlelement(        --
            NAME "ATTRIBUTE_S" --
            ,xmlconcat(        --
            xmlforest(         --
            a.attr_id          --
            ,a.is_id           --
            ,i.idstorename     --
            ,a.attrname        --
            ,a.info            --
            ,a.deltask         --
            ,a.modtask         --
            ,a.instask         --
            ,a.display_name    --
            ,a.tooltip         --
            ,a.regexvalidate   --
            ,a.sqlvalues       --
            ,a.sqlaccesstask   --
            ,a.sqlvaluestable  --
            ,a.sqlvaluesid     --
            )                  --xmlforest
            , xmlforest(       --
            (
                SELECT xmlagg(                      --
                    xmlelement(                     --
                    NAME "ATTRIBUTE_VALUE_CHOICE_S" --
                    , xmlforest( v.attr_value)      --
                    )                               --xmlelement
                ORDER BY v.attr_value               --
                    )                               --xmlagg
                FROM mxi_attrvaluechoice v
                WHERE v.attr_id=a.attr_id
            )                             --xmlforest
            AS "ATTRIBUTE_VALUE_CHOICE_T")--xmlforest
            )                             --xmlconcat
            )                             --xmlelement
            ,version '1.0')               --xmlroot
        FROM mxiv_allattributes a
        INNER JOIN mxi_idstores i
        ON  a.is_id=i.is_id
        UNION ALL
        SELECT t.taskid
          ,'T' -- Task
          ,t.taskname
          ,xmlroot(       --
            xmlelement(   --
            NAME "TASK_S" --
            ,xmlconcat(   --
            xmlforest(    --
            t.taskid      --
            , t.taskname  --
            ,t.boolsql    --
            ,t.onsubmit   --
            )             --xmlforst
            ,xmlforest(   --
            (
                SELECT xmlagg(              --
                    xmlelement(             --
                    NAME "TASK_ATTRIBUTE_S" --
                    ,xmlforest(             --
                    ta.attr_id              --
                    ,ta.attrname            --
                    ,ta.sqlvalues)          --xmlforest
                    )                       --xmlelement
                ORDER BY ta.attrname        --
                    )                       --xmlagg
                FROM mxiv_taskattributes ta
                WHERE ta.taskid=t.taskid
            )                      --xmlforest
            AS "TASK_ATTRIBUTE_T") --
            ,xmlforest(            --
            (
                SELECT xmlagg(                             --
                    xmlelement(                            --
                    NAME "TASK_ACCESS_S"                   --
                    ,xmlforest(                            --
                    tx.sqlscript                           --
                    ,tx.targetsqlscript                    --
                    ,a.attrname      AS "ATTRNAME"         --
                    ,ta.attrname     AS "TARGETATTRNAME"   --
                    ,e.mcmskeyvalue  AS "MSKEYVALUE"       --
                    ,te.mcmskeyvalue AS "TARGETMSKEYVALUE" --
                    )                                      --xmlforest
                    )                                      --xmlelement
                ORDER BY tx.sqlscript ,tx.targetsqlscript )--xmlagg
                FROM mxpv_taskaccess tx
                LEFT OUTER JOIN mxi_attributes a
                ON  tx.attr_id=a.attr_id
                LEFT OUTER JOIN mxi_attributes ta
                ON  tx.targetattr_id=ta.attr_id
                LEFT OUTER JOIN idmv_entry_simple e
                ON  tx.mskey=e.mcmskey
                LEFT OUTER JOIN idmv_entry_simple te
                ON  tx.targetmskey=te.mcmskey
                WHERE tx.taskid   =t.taskid
            )                  --xmlforest
            AS "TASK_ACCESS_T")--xmlforest
            )                  --xmlconcat
            )                  --xmlelement
            ,version '1.0')    --xmlroot
        FROM mxpv_alltaskinfo t
)
  ,text_datasource_cte(node_id,node_type,node_name,native_xml) AS
  (
    SELECT node_id
           ,'P' -- PROCEDURE
           ,cast(node_name as VARCHAR2(4000 byte))
           --Using a CDATA section to wrap DDL source code is a workaround
           --for sys_xmlgen's failure to properly encode some Unicode characters
           --that occur in the DDL like U+009A or U+00A0. Without CDATA section,
           --these would result in ORA-31011 during XML parsing.
           ,sys_xmlgen(xmlcdata(node_data), XMLFormat(enclTag => 'ROOT'))
           from table(
               z_idmwu.filter_read_source_ptf(
                   iv_search_term => (select st from search_term_cte)
               )
           )
  )
  ,b64_enc_prefix_cte(node_id, node_type, node_name, b64_enc_prefix, is_xml) AS
    (
        SELECT scriptid
          ,'S' -- Global or package script
          --See z_idmwu_clob_obj.node_name
          ,cast(scriptname as VARCHAR2(4000 byte))
          ,scriptdefinition
          ,0
        FROM mc_global_scripts
        UNION ALL SELECT
            node_id
            ,'J' -- Job
            ,node_name
            ,node_data
            ,1
            FROM table(
                z_idmwu.read_tab_with_long_col_ptf(
                    'MC_JOBS'        --iv_tab_name
                    ,'JOBID'         --iv_id_column_name
                    ,'NAME'          --iv_name_colun_name
                    ,'JOBDEFINITION' --iv_long_column_name
                )
            )
    )
,b64_enc_cte(node_id, node_type, node_name, b64_enc,is_xml) AS (
SELECT
    node_id
    ,node_type
    ,node_name
    -- SUBSTR returns datatype of arg1 (CLOB in this case)
    ,substr(
        -- CLOB, so return value will be CLOB
        b64_enc_prefix
        -- LENGTH accepts CHAR, VARCHAR2, NCHAR,
        -- NVARCHAR2,CLOB, or NCLOB
        ,length('{B64}') + 1
        ,length(b64_enc_prefix) - length('{B64}')
    )
    ,is_xml
    FROM b64_enc_prefix_cte
)  ,b64_dec_cte(node_id,node_type,node_name,b64_dec,is_xml) AS
    (
        SELECT node_id
          ,node_type
          ,node_name
          ,z_idmwu.base64_decode(b64_enc)
          ,is_xml
        FROM b64_enc_cte
    )
  ,b64_datasource_cte(node_id, node_type, node_name, native_xml) AS
    (
        SELECT node_id
          ,node_type
          ,node_name
          ,CASE is_xml
                WHEN 1
                THEN xmlparse(DOCUMENT b64_dec)
                ELSE sys_xmlgen(b64_dec, XMLFormat(enclTag => 'ROOT'))
            END
        FROM b64_dec_cte
        WHERE 
            case 
                when (select st from search_term_cte) is not null
                    then instr(upper(b64_dec)
                               ,upper((SELECT st FROM search_term_cte)))
                else 1
            end > 0
    )
  ,any_datasource_cte(node_id, node_type, node_name, native_xml) AS
    (
        SELECT * FROM b64_datasource_cte
        UNION ALL
        SELECT * FROM xml_datasource_cte
        UNION ALL
        SELECT * FROM text_datasource_cte
    )
  ,all_text_cte(node_id, node_type, node_name, match_location_text, match_document) AS
    (
        SELECT node_id
          ,node_type
          ,node_name
            -- Magic number 1 is the value of the documented,
            -- but non-existing constant dbms_xmlgen.entity_decode
          ,dbms_xmlgen.convert( 
              xmldata => extract(match_location,'.').getCLOBVal() 
              ,flag => 1 ) 
           AS match_location_text
          ,native_xml AS match_document
        FROM any_datasource_cte
          ,xmltable('for $t in ( $native_xml//attribute::*                   
                     ,$native_xml/descendant-or-self::text())        
                     return $t'
            PASSING native_xml AS "native_xml"
            COLUMNS match_location XMLType PATH '.' )
    )
SELECT *
    FROM all_text_cte
    WHERE 
        case 
            when (select st from search_term_cte) is not null
                then instr(upper(match_location_text)
                           ,upper((SELECT st FROM search_term_cte)))
            else 1
        end > 0
    ORDER BY node_type, node_id;
