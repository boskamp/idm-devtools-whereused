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
-- Synopsis: UNINSTALL where-used query for use with SAP(R) IDM.
--
-- Usage:    Use any SQL client, such as Oracle(R) SQL Developer,
--           to connect to the SAP(R) IDM database and execute this
--           script as OPER user (MXMC_OPER, by default).
--
-- Result:   All schema objects created by the installer
--           have been removed from the SAP(R) IDM database.
--
-- ========================================================================
begin
    execute immediate 'DROP PACKAGE z_idmwu';
    dbms_output.put_line('Package dropped');
exception 
    when others then
        if sqlcode != -4043 then
            raise;
        else
            dbms_output.put_line('Package not found, nothing to do');
        end if;
end;
/
begin
    execute immediate 'DROP TYPE z_idmwu_clob_tab';
    dbms_output.put_line('Table type dropped');
exception 
    when others then
        if sqlcode != -4043 then
            raise;
        else
            dbms_output.put_line('Table type not found, nothing to do');
        end if;
end;
/
begin
    execute immediate 'DROP TYPE z_idmwu_clob_obj';
    dbms_output.put_line('Object type dropped');
exception 
    when others then
        if sqlcode != -4043 then
            raise;
        else
            dbms_output.put_line('Object type not found, nothing to do');
        end if;
end;
/
