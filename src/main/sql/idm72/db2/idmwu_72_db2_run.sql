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
--    THIS IS THE VERSION FOR SAP(R) IDM 7.2 ON IBM(R) DB2(R)
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
-- Usage:    1. Paste this source code into the SQL editor of any
--              graphical SQL client that can display CLOB and/or
--              XML data. Microsoft(R) SQL Server Management Studio,
--              Oracle(R) SQL Developer and IBM(R) Data Studio are
--              known to work fine. Others may work as well.
--
--           2. In the SQL editor, replace YOUR_SEARCH_TERM_HERE
--              near the end of the code with the string you want
--              to search for. See also section "Example".
--
--           3. Execute the resulting query as OPER user (MXMC_OPER).
--
--           4. (Optional) Examine MATCH_LOCATION_* and MATCH_DOCUMENT
--              values of the result set directly in the SQL client.
--
--           5. (Optional) Locate tasks or jobs corresponding to NODE_ID
--              values from your result set using MMC's Find action.
--              Make sure to check "Find Tasks or Jobs only"!
--
-- Example:  To search for all occurences of the string MX_DISABLED,
--           the code near the end should look like:
--
--           where contains(upper-case($t),upper-case("MX_DISABLED"))
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
--           2. NODE_ID             : int
--           3. NODE_NAME           : varchar(max)
--           4. MATCH_LOCATION_XML  : xml                 (MSSQL only)
--           5. MATCH_LOCATION_TEXT : varchar(max)
--           6. MATCH_DOCUMENT      : xml
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
--           MATCH_LOCATION_XML is similar to MATCH_LOCATION_TEXT,
--           just represented as XML to enable convenient hyperlink
--           navigation in Microsoft(R) SQL Server Management Studio.
--           This column exists in the MSSQL version only.
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
--           which differ only in their MATCH_LOCATION_* values.
--
-- Credits:  Martin Smith http://stackoverflow.com/users/73226/martin-smith
--           Thanks for explaining how to display large text in SSMS
--
--           Finn Ellebaek Nielsen https://ellebaek.wordpress.com
--           Thanks for explaining how to convert LONG to CLOB on the fly
--
-- *******************************************************************
WITH text_datasource_cte(node_id,node_type,node_name,native_xml) AS (
SELECT
     a.attr_id
     ,'A'-- Attribute
     ,a.attrname
     ,xmldocument(
        xmlelement(
            NAME "ATTRIBUTE_S"
            ,xmlconcat(
                xmlforest(
                    a.attr_id
                    ,a.attrname
		    ,a.is_id
		    ,i.idstorename
                    ,a.info
                    ,a.deltask
                    ,a.modtask
                    ,a.instask                
                    ,a.display_name
                    ,a.tooltip
                    ,a.regexvalidate
                    ,a.sqlvalues
                    ,a.sqlaccesstask
                    ,a.sqlvaluestable
                    ,a.sqlvaluesid)
                    ,xmlelement(
                        NAME "ATTRIBUTE_VALUE_CHOICE_T"
                        ,(SELECT
                            xmlagg(
                                xmlelement(
                                    NAME "ATTRIBUTE_VALUE_CHOICE_S"
                                    ,xmlforest(
                                        v.attr_value))
                            ORDER BY v.attr_value)
                        FROM mxi_attrvaluechoice v
                        WHERE v.attr_id=a.attr_id)))))                    
     FROM mxiv_allattributes a
     INNER JOIN mxi_idstores i
     ON a.is_id=i.is_id

UNION ALL SELECT
    t.taskid
    ,'T'-- Task
    ,t.taskname
    ,xmldocument(
        xmlelement(
            NAME "TASK_S"
            ,xmlconcat(
                xmlforest(
                    t.taskid
                    ,t.taskname
                    ,t.boolsql
                    ,t.onsubmit)
                ,xmlelement(
                    NAME "TASK_ATTRIBUTE_T"
                    ,(SELECT
                        xmlagg(
                            xmlelement(
                                NAME "TASK_ATTRIBUTE_S"
                                ,xmlforest(
                                    ta.attr_id
                                    ,ta.attrname
                                    ,ta.sqlvalues))
                            ORDER BY ta.attrname)
                        FROM mxiv_taskattributes ta
                        WHERE ta.taskid=t.taskid))
                ,xmlelement(
                    NAME "TASK_ACCESS_T"
                    ,(SELECT
                        xmlagg(
                            xmlelement(
                                NAME "TASK_ACCESS_S"
                                ,xmlforest(
                                    tx.sqlscript
                                    ,tx.targetsqlscript
                                    ,a.attrname         AS "ATTRNAME"
                                    ,ta.attrname        AS "TARGETATTRNAME"
                                    ,e.mcmskeyvalue     AS "MSKEYVALUE"
                                    ,te.mcmskeyvalue    AS "TARGETMSKEYVALUE"))
                        ORDER BY
                            tx.sqlscript
                            ,tx.targetsqlscript)
                        FROM mxpv_taskaccess tx
                        LEFT OUTER JOIN mxi_attributes a
                        ON tx.attr_id=a.attr_id
                        LEFT OUTER JOIN mxi_attributes ta
                        ON tx.targetattr_id=ta.attr_id
                        LEFT OUTER JOIN idmv_entry_simple e
                        ON tx.mskey=e.mcmskey
                        LEFT OUTER JOIN idmv_entry_simple te
                        ON tx.targetmskey=te.mcmskey
                        WHERE tx.taskid=t.taskid)))))
    FROM mxpv_alltaskinfo t
)
,b64_enc_prefix_cte(node_id, node_type, node_name, b64_enc_prefix, is_xml) AS (
SELECT
    scriptid
    ,'S' -- Global script
    ,scriptname
    ,scriptdefinition
    ,0
    FROM mc_global_scripts
UNION ALL SELECT
    jobid
    ,'J' -- Job
    ,name
    ,jobdefinition
    ,1
    FROM mc_jobs
)
,b64_enc_cte(node_id, node_type, node_name, b64_enc,is_xml) AS (
SELECT
    node_id
    ,node_type
    ,node_name
    ,SUBSTR(b64_enc_prefix
            ,LENGTH('{B64}') + 1
            ,LENGTH(b64_enc_prefix) - LENGTH('{B64}')
    )
    ,is_xml
    FROM b64_enc_prefix_cte
)
,b64_dec_cte(node_id,node_type,node_name,b64_dec,is_xml) AS (
SELECT
    node_id
    ,node_type
    ,node_name
    ,XMLCAST(XMLQUERY('xs:base64Binary($b64_enc)' 
                      PASSING b64_enc AS "b64_enc" ) 
             AS BLOB(2g)
    )
    ,is_xml
    FROM b64_enc_cte
)
,b64_datasource_cte(node_id,node_type,node_name,native_xml) AS (
SELECT
    node_id
    ,node_type
    ,node_name
    ,CASE is_xml
        WHEN 1 THEN XMLPARSE(DOCUMENT b64_dec PRESERVE WHITESPACE)
        ELSE XMLPARSE(DOCUMENT 
                      XMLCAST(XMLQUERY('xs:hexBinary($i)' 
                                       PASSING CAST('<?xml version="1.0" encoding="UTF-8"?><ROOT><![CDATA[' 
                                                    AS BLOB(2g)) 
                                       AS "i") 
                              AS BLOB(2g))
                      || b64_dec 
                      || XMLCAST(XMLQUERY('xs:hexBinary($i)' 
                                          PASSING CAST(']]></ROOT>' AS BLOB(2g)) 
                                          AS "i") 
                                 AS BLOB(2g))
                      PRESERVE WHITESPACE)
    END
    FROM b64_dec_cte
)
,any_datasource_cte(node_id,node_type,node_name,native_xml) AS (
SELECT
     *
     from b64_datasource_cte
UNION ALL SELECT
     *
     FROM text_datasource_cte
)
SELECT
     node_id
     ,node_type
     ,node_name
     ,match_location_text
     ,match_document
     FROM any_datasource_cte
     ,xmltable('
         for $t in ( $native_xml//attribute::*
                    ,$native_xml/descendant-or-self::text())
         where contains( upper-case($t)
                        ,upper-case("YOUR_SEARCH_TERM_HERE")) 
         return $t
         
         (: This could be used on DB2 to conditionally return  :)
         (: parent of attribute nodes, but self of text nodes. :)
         (: XQuery "instance of"" operator seems unsupported.  :)
         (:                                                    :)
         (: return if($t/self::attribute()) then $t/.. else $t :) 
     ' 
     PASSING BY REF native_xml AS "native_xml"
     COLUMNS "MATCH_LOCATION_TEXT"  CLOB(2G) PATH '.'
             ,"MATCH_DOCUMENT" XML PATH '/'
     )
    ORDER BY node_type, node_id
;
