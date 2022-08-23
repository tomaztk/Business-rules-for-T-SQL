/*

Description: Lightweight showcase of T-SQL Framework for managing your Business logic
Author: Tomaz Kastrun
Date: 20.Aug.2022
URL: https://github.com/tomaztk/Business-rules-for-T-SQL

*/

----------------------------------------------------------------------------------------------------
--- Step 1. Create Sample procedure and sample view
----------------------------------------------------------------------------------------------------

CREATE PROCEDURE dbo.sp_SampleQuery1
AS

SELECT 
* 
FROM
(
	SELECT 
		name
		,number
		,CASE WHEN name like 'DB %' THEN 'ORACLE' ELSE 'SYBASE' END As dbms_name
	FROM 
		master..spt_values
	WHERE
	[type] IN ('DBR','DC','O9T')
	AND status = 0
) AS x
join msdb..MSdatatype_mappings as m
ON m.dbms_name =  x.dbms_name 
;
GO



CREATE VIEW dbo.vw_SampleQuery2
AS
SELECT 
	 t.TABLE_CATALOG
	,t.table_name
	,t.TABLE_SCHEMA
	,c.COLUMN_NAME
	,c.ORDINAL_POSITION
	,c.IS_NULLABLE
	,c.DATA_TYPE
	,c.NUMERIC_PRECISION
	,(c.NUMERIC_PRECISION * c.ORDINAL_POSITION) AS Some_calucation_for_Size

FROM
MASTER.[INFORMATION_SCHEMA].[COLUMNS] AS c
JOIN MASTER.[INFORMATION_SCHEMA].[TABLES] AS t
ON t.TABLE_NAME = c.TABLE_NAME
AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
AND t.TABLE_CATALOG = c.TABLE_CATALOG
WHERE
	c.DATA_TYPE IN ('int','smallint','bigint','tinyint')
AND c.ORDINAL_POSITION <= 10 ;
GO



----------------------------------------------------------------------------------------------------
-- Step 2. Populate table with parametrised queries and values for procedure and view from step 1.
----------------------------------------------------------------------------------------------------

 INSERT INTO dbo.BusinessRules_Query ([query_type], [query_object_name], [query_id], [query_text], [query_text_withParameters])
 SELECT 'Procedure','dbo.sp_SampleQuery1', 10203
 ,NULL
,
'CREATE PROCEDURE dbo.sp_SampleQuery1
AS

SELECT 
* 
FROM
(
	SELECT 
		name
		,number
		,$selectkey1
	FROM 
		master..spt_values
	WHERE
	
	$wherekey1
	AND status = 0
) AS x
join msdb..MSdatatype_mappings as m
ON m.dbms_name =  x.dbms_name
'
UNION ALL 
 SELECT 'View','dbo.vw_SampleQuery2', 10200
 ,NULL
,
'CREATE VIEW dbo.vw_SampleQuery2
AS
SELECT 
	 t.TABLE_CATALOG
	,t.table_name
	,t.TABLE_SCHEMA
	,c.COLUMN_NAME
	,c.ORDINAL_POSITION
	,c.IS_NULLABLE
	,c.DATA_TYPE
	,c.NUMERIC_PRECISION
	,$selectkey1

FROM
MASTER.[INFORMATION_SCHEMA].[COLUMNS] AS c
JOIN MASTER.[INFORMATION_SCHEMA].[TABLES] AS t
ON t.TABLE_NAME = c.TABLE_NAME
AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
AND t.TABLE_CATALOG = c.TABLE_CATALOG
WHERE
	$wherekey1
AND $wherekey2'



 
  INSERT INTO dbo.BusinessRules_Parameters ([query_id], [query_parameter_Description], [query_parameter_tableRelated], [query_key], [query_value])
 SELECT 10203
 ,'CASE Statement to determine if ORACLE or SYBASE type'
 ,'master..spt_values'
 ,'$selectkey1'
 ,'CASE WHEN name like ''DB %'' THEN ''ORACLE'' ELSE ''SYBASE'' END As dbms_name'
 UNION ALL
  SELECT 10203
 ,'Define the type of names query will be returning'
 ,'master..spt_values'
 ,'$wherekey1'
 ,'[type] IN (''DBR'',''DC'',''O9T'')'

  UNION ALL
  SELECT 10200
 ,'Calculating some random size as business rule'
 ,'MASTER.[INFORMATION_SCHEMA].[COLUMNS]'
 ,'$selectkey1'
 ,'(c.NUMERIC_PRECISION * c.ORDINAL_POSITION) AS Some_calucation_for_Size'


   UNION ALL
  SELECT 10200
 ,'Selecting only numerical data types'
 ,'MASTER.[INFORMATION_SCHEMA].[COLUMNS]'
 ,'$wherekey1'
 ,'c.DATA_TYPE IN (''int'',''smallint'',''bigint'',''tinyint'')'

    UNION ALL
  SELECT 10200
 ,'Omitting the number of columns per table'
 ,'MASTER.[INFORMATION_SCHEMA].[COLUMNS]'
 ,'$wherekey2'
 ,'c.ORDINAL_POSITION <= 10'



----------------------------------------------------------------------------------------------------
--- Step 3. Execute the object creation!
----------------------------------------------------------------------------------------------------

-- Execute
EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10203;

EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10200;

-- Disable the parameter for QueryID 10203
EXEC dbo.sp_Update_Parameters 
        @query_id = 10203
        ,@Query_key = '$wherekey2'
        ,@new_query_value = ' '
        ,@new_query_parameter_Description = ''
        ,@new_query_table_related = ''
        ,@is_enabled = 0


-- Update the parameter for QueryID 10203
EXEC dbo.sp_Update_Parameters 
        @query_id = 10203
        ,@Query_key = '$wherekey1'
        ,@new_query_value = ' [type] IN (''DBR'',''DC'') '
        ,@new_query_parameter_Description = 'Define the type of names query will be returning'
        ,@new_query_table_related = 'master..spt_values'
        ,@is_enabled = 1


----------------------------------------------------------------------------------------------------
-- Step 4.  Scheduling and  running SQL Server Job
----------------------------------------------------------------------------------------------------


INSERT INTO dbo.BusinessRules_Executions (query_id, Query_execution)
SELECT 
 10200, 0



 --- Creating SQL Server Job:
USE msdb ;  
GO  
EXEC dbo.sp_add_job  
    @job_name = N'Weekly Object Creations' ;  
GO  
EXEC sp_add_jobstep  
    @job_name = N'Weekly Object Creations',  
    @step_name = N'Create objects from BusinessRules queries',  
    @subsystem = N'TSQL',  
    @command = N'
	
DECLARE @var1 INT
DECLARE @cur CURSOR
SET @cur = CURSOR STATIC FOR
    SELECT query_id FROM dbo.BusinessRules_Executions WHERE query_execution = 0


OPEN @cur
WHILE 1 = 1
BEGIN
     FETCH @cur INTO @var1
     IF @@fetch_status <> 0
        BREAK
    EXEC dbo.sp_Create_ScriptObjects 
		@query_id = @var1
		,@ScriptObject = 0
END
',   
    @retry_attempts = 5,  
    @retry_interval = 5 ;  
GO  
EXEC dbo.sp_add_schedule  
    @schedule_name = N'RunOnce',  
    @freq_type = 1,  
    @active_start_time = 003000 ;  
USE msdb ;  
GO  
EXEC sp_attach_schedule  
   @job_name = N'Weekly Object Creations',  
   @schedule_name = N'RunOnce';  
GO  
EXEC dbo.sp_add_jobserver  
    @job_name = N'Weekly Object Creations';  
GO  



