-- Copyright 2016 Lambert Boskamp
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
--    THIS IS THE VERSION FOR SAP(R) IDM 8.0 ON ORACLE
-- ========================================================================
-- The latest version of this code, as well as versions for
-- other SAP(R) IDM releases and other databases can be found at
--
--    https://github.com/boskamp/idm-devtools-whereused/
--
-- ========================================================================
--
-- Synopsis: Query to find locations of packages, tasks, jobs
--           groups and scripts in SAP(R) Identity Management
--
--           Locations are represented by column NODE_PATH of this
--           query's result set. NODE_PATH is a character string
--           loosely resembling a file system path.
--
--           If you have any jobs are tasks that are linked from
--           multiple locations, one row is returned per location,
--           each with a different NODE_PATH.
--
-- Usage:    Running this query AS IS will return the locations of
--           all packages, tasks, jobs and groups in the current database.
--           The runtime user (MXMC_RT) normally has sufficient
--           permissions to execute it.
--
--           You'll typically uncomment the "NODE_TYPE=...",
--           "NODE_ID=..." and/or "NODE_NAME=..." predicates in the
--           WHERE clause of the outer query at the very end
--           of this file. See section "Examples" below.
--
--           NODE_TYPE = [ 'J' -- Job
--                       | 'T' -- Task
--                       | 'G' -- Group (aka folder)
--                       | 'I' -- Identity Store
--                       | 'P' -- Package
--                       ]
--
--           NODE_ID = [job_id|task_id|group_id|ids_id|package_id]
--
--           NODE_NAME = [job_name|task_name|group_name|ids_name|package_name]
--
-- Examples: TODO
--
-- Notes:    TODO
-- *******************************************************************
WITH nodes
    -- ORA requires a list of column aliases, SQL Server doesn't
    (node_id, parent_node_id, parent_node_type, node_name, node_type) AS
    (
    -- Identity Stores
    SELECT is_id   AS node_id
      ,NULL        AS parent_node_id
      ,NULL        AS parent_node_type
      ,idstorename AS node_name
      ,'I'         AS node_type
    FROM mxi_idstores
    -- Top Level Package Folders for Identity Store
    UNION ALL
    SELECT group_id AS node_id
      ,idstore      AS parent_node_id
      ,'I'          AS parent_node_type
      ,group_name   AS node_name
      ,'G'          AS node_type
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
    FROM mc_jobs j
    WHERE j.provision=0
    -- Package Scripts
    UNION ALL
    SELECT mcscriptid                       AS node_id
      ,mcpackageid                          AS parent_node_id
      ,'P'                                  AS parent_node_type
      ,CAST(mcscriptname AS VARCHAR2(4000)) AS node_name
      ,'S'                                  AS node_type
    FROM mc_package_scripts
    )--nodes
  ,tree
    -- ORA requires list of column aliases in CTE definition, MSS doesn't
    (node_id,node_type,node_name,parent_node_id,parent_node_type,node_path ,path_len) AS
    (SELECT node_id
      ,node_type
      ,node_name
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
SELECT node_id
  ,node_type
  ,node_name
  ,node_path
  ,path_len
FROM tree
WHERE 1=1
    -- Uncomment and adapt any or all of the below lines
    --AND node_id   = 35
    --AND node_type = 'T'
    --AND node_name = 'Provision'
    --AND node_path like '%com.sap.provisioning.engine%'
ORDER BY path_len
  ,node_path ;