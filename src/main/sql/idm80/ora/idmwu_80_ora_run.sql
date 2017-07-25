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
--                       | 'S' -- Script (package script)
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
  ,b64_enc_cte(node_id, node_type, node_name, b64_enc, is_xml) AS
    (
        SELECT mcscriptid
          ,'S' -- Package script
            --see  z_idmwu_clob_type.node_name
          ,CAST(mcscriptname AS VARCHAR2(4000 byte))
          ,mcscriptdefinition
          ,0
        FROM mc_package_scripts
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
,b64_dec_cte(node_id,node_type,node_name,b64_dec,is_xml) AS
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
,nodes
    -- ORA requires a list of column aliases, SQL Server doesn't
    (node_id, parent_node_id, parent_node_type, node_name, node_type, node_pkg) AS
    (
    -- Identity Stores
    SELECT is_id   AS node_id
      ,NULL        AS parent_node_id
      ,NULL        AS parent_node_type
      ,idstorename AS node_name
      ,'I'         AS node_type
      ,null        as node_pkg
    FROM mxi_idstores
    -- Top Level Package Folders for Identity Store
    UNION ALL
    SELECT group_id AS node_id
      ,idstore      AS parent_node_id
      ,'I'          AS parent_node_type
      ,group_name   AS node_name
      ,'G'          AS node_type
      ,mcpackageid  as node_pkg
    FROM mc_group
    WHERE provision_group=2 -- package folder
    AND parent_group    IS NULL
    AND mcpackageid     IS NULL
    -- Packages Contained in a Folder
    UNION ALL
    SELECT p.mcpackageid AS node_id
      ,p.mcgroup         AS parent_node_id
      ,'G'               AS parent_node_type
      ,p.mcqualifiedname AS node_name
      ,'P'               AS node_type
      ,p.mcpackageid     as node_pkg
    FROM mc_group g
    INNER JOIN mc_package p
    ON  p.mcgroup=g.group_id
    -- Tasks Contained in a Folder
    UNION ALL
    SELECT t.taskid AS node_id
      ,t.taskgroup  AS parent_node_id
      ,'G'          AS parent_node_type
      ,t.taskname   AS node_name
      ,'T'          AS node_type
      ,t.mcpackageid as node_pkg
    FROM mc_group g
    INNER JOIN mxp_tasks t
    ON  t.taskgroup=g.group_id
    -- Top Level Process, Form or Job Folder of Package
    UNION ALL
    SELECT group_id AS node_id
      ,mcpackageid  AS parent_node_id
      ,'P'          AS parent_node_type
      ,group_name   AS node_name
      ,'G'          AS node_type
      ,mcpackageid  as node_pkg
    FROM mc_group
    WHERE NOT provision_group=2 -- package folder
    AND parent_group        IS NULL
    -- Package, Process, Form or Job Folders Below Other Folders (Child Folders)
    UNION ALL
    SELECT group_id AS node_id
      ,parent_group AS parent_node_id
      ,'G'          AS parent_node_type
      ,group_name   AS node_name
      ,'G'          AS node_type
      ,mcpackageid  as node_pkg
    FROM mc_group
    WHERE parent_group IS NOT NULL
    -- Tasks Contained in a Process (Task Group)
    UNION ALL
    SELECT l.tasklnk AS node_id
      ,l.taskref     AS parent_node_id
      ,'T'           AS parent_node_type
      ,CASE p.actiontype
            WHEN -4 --Switch Task
            THEN '[CASE '
                || l.childgroup
                || '] - '
                || c.taskname
            WHEN -3 --Conditional Task
            THEN
                CASE l.childgroup
                    WHEN '1'
                    THEN '[CASE TRUE] - '
                        || c.taskname
                    ELSE '[CASE FALSE] - '
                        || c.taskname
                END
            ELSE c.taskname
        END AS node_name
      ,'T'  AS node_type
      ,c.mcpackageid as node_pkg
    FROM mxp_tasklnk l
    INNER JOIN mxp_tasks p
    ON  l.taskref=p.taskid
    INNER JOIN mxp_tasks c
    ON  l.tasklnk=c.taskid
    -- Provisioning Jobs
    UNION ALL
    SELECT j.jobid AS node_id
      ,t.taskid    AS parent_node_id
      ,'T'         AS parent_node_type
      ,j.NAME      AS node_name
      ,'J'         AS node_type
      ,j.mcpackageid as node_pkg
    FROM mc_jobs j
    INNER JOIN mxp_tasks t
    ON  j.jobguid    =t.jobguid
    WHERE j.provision=1
    -- Regular Jobs
    UNION ALL
    SELECT j.jobid AS node_id
      ,group_id    AS parent_node_id
      ,'G'         AS parent_node_type
      ,j.NAME      AS node_name
      ,'J'         AS node_type
      ,j.mcpackageid as node_pkg
    FROM mc_jobs j
    WHERE j.provision=0
    -- Package Scripts
    UNION ALL
    SELECT mcscriptid                       AS node_id
      ,mcpackageid                          AS parent_node_id
      ,'P'                                  AS parent_node_type
      ,CAST(mcscriptname AS VARCHAR2(4000)) AS node_name
      ,'S'                                  AS node_type
      ,mcpackageid                          as node_pkg
    FROM mc_package_scripts
    )--nodes
  ,tree
    -- ORA requires list of column aliases in CTE definition, MSS doesn't
    (node_id,node_type,node_name,node_pkg,parent_node_id,parent_node_type,node_path ,path_len) AS
    (SELECT node_id
      ,node_type
      ,node_name
      ,node_pkg
      ,parent_node_id
      ,parent_node_type
      ,'/'
        || node_id
        || ':'
        || node_name AS node_path
      ,0             AS path_len
    FROM nodes
    WHERE parent_node_id IS NULL
    UNION ALL
    SELECT n.node_id
      ,n.node_type
      ,n.node_name
      ,n.node_pkg
      ,n.parent_node_id
      ,n.parent_node_type
      ,t.node_path
        || '/'
        || n.node_id
        || ':'
        || n.node_name AS node_path
      ,t.path_len + 1  AS path_len
        -- DB2 CTEs require pre-ANSI JOIN syntax (equivalent to INNER JOIN)
    FROM nodes n
      , tree t
    WHERE t.node_id=n.parent_node_id
    AND t.node_type=n.parent_node_type
        -- Guard against infinite recursion in case of cyclic links.
        -- The below will query to a maximum depth of 99, which will
        -- work fine with MSSQL's default maxrecursion limit of 100.
    AND t.path_len<100
    )
,tree_pkg AS (
SELECT 
    a.*
    ,b.mcqualifiedname AS node_pkg_name
    FROM tree a
    LEFT OUTER JOIN mc_package b
    ON a.node_pkg=b.mcpackageid
)
SELECT a.*
    ,b.node_pkg_name
    ,b.node_path
    FROM all_text_cte a
    LEFT OUTER JOIN tree_pkg b
    ON a.node_type=b.node_type
    AND a.node_id=b.node_id
    WHERE 
        CASE 
            WHEN (SELECT st FROM search_term_cte) IS NOT NULL
                THEN instr(upper(match_location_text)
                           ,upper((SELECT st FROM search_term_cte)))
            else 1
        end > 0
    -- Note that "null not like 'pattern'" is ALWAYS false
    AND ( b.node_path IS NULL OR lower(b.node_path) NOT LIKE '%obsoleted%' )
    ORDER BY a.node_type, a.node_id;
