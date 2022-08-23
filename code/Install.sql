/*

Description: Lightweight T-SQL Framework for managing your Business logic
Author: Tomaz Kastrun
Date: 20.Aug.2022

List of created objects:
- dbo.BusinessRules_Query
- dbo.BusinessRules_Parameters
- dbo.BusinessRules_Executions
- dbo.sp_Create_ScriptObjects
- dbo.sp_Update_Parameters
*/


-- ===== TABLES


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
);
GO



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
,parameter_active TINYINT DEFAULT(1) -- 1-is active; 0 - is not active
,CONSTRAINT PK_BussinesRulesParameters_QueryID_queryKey_Version
               PRIMARY KEY CLUSTERED (query_id, query_key, parameter_version)
               WITH (IGNORE_DUP_KEY = OFF)
);
GO



 IF object_id ('BusinessRules_Executions', 'U') IS NOT  NULL
DROP TABLE dbo.BusinessRules_Executions

CREATE TABLE dbo.BusinessRules_Executions
(
 id INT IDENTITY(1,1) NOT NULL
,query_id INT NOT NULL  
,query_execution TINYINT NOT NULL DEFAULT(0) -- 0 - rule is on; 1 - rule is off
,store_version TINYINT NOT NULL DEFAULT(0) -- 0 - storing version is on; 1 - storing version if off
,user_created VARCHAR(50) NOT NULL DEFAULT (suser_name())
,date_created DATETIME NOT NULL DEFAULT (GETDATE())
,CONSTRAINT PK_BussinesRulesExecution_QueryID PRIMARY KEY CLUSTERED (query_id)
);
GO




-- ===== PROCEDURES



IF object_id ('dbo.sp_Create_ScriptObjects', 'P') IS NOT  NULL
DROP PROCEDURE dbo.sp_Create_ScriptObjects;


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
	DECLARE @tip CHAR(1)		= (SELECT query_type FROM dbo.BusinessRules_Query WHERE query_id = @query_ID)
	DECLARE @ime VARCHAR(200)	= (SELECT query_object_name FROM dbo.BusinessRules_Query WHERE query_id = @query_ID)
	DECLARE @nof_params INT = (SELECT count(*) FROM dbo.BusinessRules_Parameters as P JOIN  dbo.BusinessRules_Query as R ON P.Query_ID = R.query_id WHERE R.query_id = @query_ID)


	IF OBJECT_ID('tempdb..#temp123','U') IS NOT NULL
	DROP TABLE #temp123

	SELECT 
		 row_number() over (ORDER BY (SELECT 1)) as RN
		,query_id
		,[query_key]
		,[query_value]

		INTO #temp123
	
		FROM dbo.BusinessRules_Parameters
		WHERE [query_id] = @query_id
		ORDER BY ID ASC

	DECLARE @sqlUkaz NVARCHAR(MAX) = (SELECT [query_text_withParameters] FROM [dbo].[BusinessRules_Query] WHERE query_id = @Query_ID)
    DECLARE @ObjectType NVARCHAR(30) = (SELECT [query_type] FROM [dbo].[BusinessRules_Query] WHERE query_id = @Query_ID)

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


IF object_id ('sp_Update_Parameters', 'P') IS NOT  NULL
DROP PROCEDURE dbo.sp_Update_Parameters;


CREATE OR ALTER PROCEDURE dbo.sp_Update_Parameters
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
			,@new_query_parameter_Description = ''
			,@new_query_table_related = ''
			,@is_enabled = 0
Change Log:
*/

AS
BEGIN
	
-------------------------------------
-- Only when disabling the parameter!
-------------------------------------

IF (@is_enabled = 0)
BEGIN

	DECLARE @pam_ver0 INT = (SELECT max(parameter_version) from BusinessRules_Parameters where [query_id] = @query_id AND query_key =  @Query_key)

	UPDATE dbo.BusinessRules_Parameters 
	SET parameter_active = 0
	WHERE
		query_id = @query_id
	and query_key = @Query_key
	and parameter_version = @pam_ver0

-- Update procedure and replace the parameter with "1=1"
	UPDATE dbo.BusinessRules_Query
	SET query_text_withParameters = REPLACE(query_text_withParameters, @Query_key, ' 1=1 ' )

	WHERE 
			query_id = @query_id

END

-------------------------------------
-- When parameter exists & is updated
-------------------------------------

-- INSERT NEW VALUE FOR PARAMETER
IF (@is_enabled = 1)
BEGIN
	
		DECLARE @pam_ver1 INT = (SELECT max(parameter_version) from BusinessRules_Parameters where [query_id] = @query_id AND query_key =  @Query_key)


		UPDATE dbo.BusinessRules_Parameters 
		SET @is_enabled = 0
		WHERE
			query_id = @query_id
		AND query_key = @Query_key
		AND parameter_version = @pam_ver1



	 INSERT INTO dbo.BusinessRules_Parameters ([query_id], [query_parameter_Description], [query_parameter_tableRelated], [query_key], [query_value], parameter_version, parameter_active)
	 SELECT 
		 @query_id AS query_id
		,@new_query_parameter_Description AS query_parameter_Description
		,@new_query_table_related AS query_parameter_tableRelated
		,@Query_key  AS query_key
		,@new_query_value AS query_value
		,@pam_ver1 + 1 AS parameter_version
		,@is_enabled AS Parameter_active

END

--Run CREATE procedure
EXEC dbo.sp_Create_ScriptObjects
			@query_id = @query_id

END;
GO

