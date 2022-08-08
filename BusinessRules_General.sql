USE businessRules;
GO


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
AND c.ORDINAL_POSITION <= 10

/***********************************************
*
*  Framework definitions
*  Tables and procedure
*
*
************************************************/



IF object_id ('Bus_Rule_query', 'U') IS NOT  NULL
DROP TABLE dbo.Bus_Rule_query


CREATE TABLE dbo.Bus_Rule_query
(
 id INT IDENTITY(1,1) NOT NULL
,query_type CHAR(1) NOT NULL -- P-procedure, F-function, V-view
,query_object_name VARCHAR(200) NULL -- enter the procedure/function/view name
,query_id INT NOT NULL  -- Object_id() ???
,query_text NVARCHAR(MAX)  -- query 
,query_text_withParameters NVARCHAR(MAX)  -- query with parameters
-- housekeeping
,user_created VARCHAR(50) NOT NULL DEFAULT (suser_name())
,date_created DATETIME NOT NULL DEFAULT (GETDATE())
,Rule_version INT DEFAULT(1)
)



IF object_id ('Bus_Rules_parameters', 'U') IS NOT  NULL
DROP TABLE dbo.Bus_Rules_parameters


CREATE TABLE dbo.Bus_Rules_parameters
(
 id INT IDENTITY(1,1) NOT NULL
,query_id INT NOT NULL  -- FK on table dbo.Bus_Rule_query
,query_parameter_Description VARCHAR(500) -- opis
,query_parameter_tableRelated VARCHAR(500) --  more tables separated with semi-colon ";"
,query_key VARCHAR(20) -- $selectkey1
,query_value NVARCHAR(MAX) -- query part
-- housekeeping
,user_created VARCHAR(50) NOT NULL DEFAULT (suser_name())
,date_created DATETIME NOT NULL DEFAULT (GETDATE())
,Rule_version INT DEFAULT(1)
)
-- primarni kljuc: query_id, query_key,rule_version



/*******************
Populate table
*******************/



 INSERT INTO dbo.Bus_Rule_query ([query_type], [query_object_name], [query_id], [query_text], [query_text_withParameters])
 SELECT 'P','dbo.sp_SampleQuery1', 10203
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
 SELECT 'V','dbo.vw_SampleQuery2', 10200
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



 
  INSERT INTO dbo.Bus_Rules_parameters ([query_id], [query_parameter_Description], [query_parameter_tableRelated], [query_key], [query_value])
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





/*
Combine the key:value pairs and build objects (procedure, view, functions)
Run procedure
*/ 




CREATE OR ALTER PROCEDURE dbo.sp_Create_ScriptObjects
	(
	@Query_ID INT 
	,@ScriptObject TINYINT = 1 -- 1 default value; returns script; set to 0, generates object!
	)
/*
Description: Procedure for generating scripts for objects
Project: Framework  
Created: TK
Date: 06.08.2022

Usage:
	EXEC dbo.sp_Create_ScriptObjects 
			@query_id = 10203
			--@query_id = 10200

Change Log:
*/

AS
BEGIN
	
	--DECLARE @query_ID INT = 10200

	DECLARE @i INT = 1
	DECLARE @tip CHAR(1)		= (SELECT query_type FROM dbo.Bus_Rule_query WHERE query_id = @query_ID)
	DECLARE @ime VARCHAR(200)	= (SELECT query_object_name FROM dbo.Bus_Rule_query WHERE query_id = @query_ID)
	DECLARE @nof_params INT = (SELECT count(*) FROM dbo.Bus_Rules_parameters as P JOIN  dbo.Bus_Rule_query as R ON P.Query_ID = R.query_id WHERE R.query_id = @query_ID)


	IF OBJECT_ID('tempdb..#temp123','U') IS NOT NULL
	DROP TABLE #temp123

	SELECT 
		 row_number() over (ORDER BY (SELECT 1)) as RN
		,query_id
		,[query_key]
		,[query_value]

		INTO #temp123
	
		FROM dbo.Bus_Rules_parameters
		WHERE [query_id] = @query_id
		ORDER BY ID ASC

	DECLARE @sqlUkaz NVARCHAR(MAX) = (SELECT [query_text_withParameters] FROM [dbo].[Bus_Rule_query] WHERE query_id = @Query_ID)

	WHILE (@i <= @nof_params)
		BEGIN
			DECLARE @param_key VARCHAR(100) = (SELECT [query_key] FROM #temp123 WHERE rn = @i)
			DECLARE @param_value VARCHAR(MAX) = (SELECT [query_value] FROM #temp123 WHERE rn = @i)

			
			SET @sqlUkaz = (SELECT REPLACE( @sqlUkaz, @param_key, @param_value))
			SET @i = @i +1
			
		END

	SELECT @sqlUkaz
	
END;
GO




--- Execute

EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10203

EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10200


