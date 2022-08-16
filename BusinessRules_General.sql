-- USE businessRules;
-- GO


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

/***********************************************
*
*  Framework definitions
*  Tables and procedure
*
*
************************************************/

IF object_id ('BusinessRules_Query', 'U') IS NOT  NULL
DROP TABLE dbo.BusinessRules_Query


CREATE TABLE dbo.BusinessRules_Query
(
 id INT IDENTITY(1,1) NOT NULL
,query_type VARCHAR(15) NOT NULL -- P-procedure, F-function, V-view
,query_object_name VARCHAR(200) NULL -- enter the procedure/function/view name
,query_id INT NOT NULL  -- Object_id() ???
,query_text NVARCHAR(MAX)  -- query 
,query_text_withParameters NVARCHAR(MAX)  -- query with parameters
-- housekeeping
,user_created VARCHAR(50) NOT NULL DEFAULT (suser_name())
,date_created DATETIME NOT NULL DEFAULT (GETDATE())
,Rule_version INT DEFAULT(1)
,CONSTRAINT PK_BussinesRulesQuery_QueryID_Version
               PRIMARY KEY CLUSTERED (query_id, Rule_version)
               WITH (IGNORE_DUP_KEY = OFF)
)



IF object_id ('BusinessRules_Parameters', 'U') IS NOT  NULL
DROP TABLE dbo.BusinessRules_Parameters


CREATE TABLE dbo.BusinessRules_Parameters
(
 id INT IDENTITY(1,1) NOT NULL
,query_id INT NOT NULL  
,query_parameter_Description VARCHAR(500) 
,query_parameter_tableRelated VARCHAR(500) --  more tables separated with semi-colon ";"
,query_key VARCHAR(20) -- eg.: $selectkey1 $wherekey1
,query_value NVARCHAR(MAX) -- query part
-- housekeeping
,user_created VARCHAR(50) NOT NULL DEFAULT (suser_name())
,date_created DATETIME NOT NULL DEFAULT (GETDATE())
,parameter_version INT DEFAULT(1)
,CONSTRAINT PK_BussinesRulesParameters_QueryID_queryKey_Version
               PRIMARY KEY CLUSTERED (query_id, query_key, parameter_version)
               WITH (IGNORE_DUP_KEY = OFF)
)



/*******************
Populate table
*******************/



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
	
    EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10200
        ,@ScriptObject = 0

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
    DECLARE @ObjectType NVARCHAR(30) = (SELECT [query_type] FROM [dbo].[Bus_Rule_query] WHERE query_id = @Query_ID)

	WHILE (@i <= @nof_params)
		BEGIN
			DECLARE @param_key VARCHAR(100) = (SELECT [query_key] FROM #temp123 WHERE rn = @i)
			DECLARE @param_value VARCHAR(MAX) = (SELECT [query_value] FROM #temp123 WHERE rn = @i)

			
			SET @sqlUkaz = (SELECT REPLACE( @sqlUkaz, @param_key, @param_value))
			SET @i = @i +1
			
		END

	IF (@ScriptObject = 1) 	SELECT @sqlUkaz
    IF (@ScriptObject = 0)
    BEGIN
        DECLARE @DropSQL NVARCHAR(100) = 'DROP ' + @ObjectType + ' IF EXISTS ' + @ime
        exec sp_executesql @DropSQL
        exec sp_executesql @sqlUkaz
    END
	
END;
GO




--- Execute

EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10203;

EXEC dbo.sp_Create_ScriptObjects 
		@query_id = 10200
        ,@ScriptObject = 0;








ALTER PROCEDURE dbo.sp_Update_Parameters
	(
	 @Query_ID INT
	,@Query_key VARCHAR(20)
	,@new_query_value NVARCHAR(MAX) = NULL
	,@new_query_parameter_Description VARCHAR(500) = NULL
	,@new_query_table_related VARCHAR(500) = NULL
	,@is_enabled TINYINT = 1
	)
/*
Usage:

	EXEC dbo.sp_Update_Parameters 
			@query_id = 10203
			,@Query_key = '$wherekey2'
			,@new_query_value = ' '
			,@new_query_parameter_Description = '
			,@new_query_table_related = '
			,@is_enabled = 1


Change Log:
*/

AS
BEGIN
	
	--DECLARE @query_ID INT = 10203
	--DECLARE @Query_key VARCHAR(20) = '$wherekey2'


	IF OBJECT_ID('tempdb..#temp123','U') IS NOT NULL
	DROP TABLE #temp123

	SELECT  
		 id
		,parameter_version
		,parameter_Active
		,query_id
		,[query_key]
		,[query_value]

		INTO #temp123
	
	FROM dbo.BusinessRules_Parameters
	WHERE 
		[query_id] = @query_id
	AND query_key =  @Query_key
	ORDER BY ID ASC


SELECT * FROM #temp123
DECLARE @pam_ver INT = (SELECT max(parameter_version) from BusinessRules_Parameters where [query_id] = @query_id AND query_key =  @Query_key)
declare @pam_row_id INT = (select max(id) from  BusinessRules_Parameters where [query_id] = @query_id AND query_key =  @Query_key)


-- only to disable parameter!

-- Update procedure and replace the parameter with "1=1" or smth.

IF (@is_enabled = 0)
BEGIN
	UPDATE dbo.BusinessRules_Parameters 
	SET parameter_active = 0
	WHERE
		query_id = @query_id
	and query_key = @Query_key
	and id = @pam_row_id
END


-->>>>>>>>>>>>>>> BEGIN TRAN

-- INSERT NEW VaLUE
IF (@is_enabled = 1)
BEGIN
	 INSERT INTO dbo.BusinessRules_Parameters ([query_id], [query_parameter_Description], [query_parameter_tableRelated], [query_key], [query_value], parameter_version, parameter_active)
	 SELECT 
		 @query_id 
		,@new_query_parameter_Description
		,@new_query_table_related
		,@Query_key 
		,@new_query_value 
		,@pam_ver + 1
		,@is_enabled 

	-- UPDATE OLD VALUEs

END

--Run CREATE procedure


EXEC dbo.sp_Create_Objects 
			@query_id = @query_id
			,@persistObject = 2


---- >>>>>>>>>>>>>>> COMMIT TRAN	
	
END;
GO
