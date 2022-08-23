# Business rules for T-SQL

<h1 style="font-weight:normal">
  <a href="https://sourcerer.io/start"><img src=https://img.shields.io/badge/SQLBusiness-Rules-brightgreen.svg?colorA=087c08></a>
 <a href="https://github.com/tomaztk/Business-rules-for-T-SQL/blob/main/LICENSE"><img src=https://img.shields.io/github/license/sourcerer-io/sourcerer-app.svg?colorB=ff0000></a>
</h1>

A lightweight framework for managing your business rules and logic in Transact SQL for Microsoft SQL Server and Azure SQL Database / Azure MI SQL.


Have you ever found yourself with T-SQL queries and hard-coded values? In SELECT or in WHERE clauses. The framework will help you with values parametrisation and an easier way to manage the rules.



Features
========
* Store your hard-coded values in SQL tables
* Parametrise your business rules and business logic
* Keeping versions of all parameters
* Leverage data transparency
* Learn interesting facts about your data



Get started
===========
The easiest way to get started is with your open code folder. Go to [github/code](https://github.com/tomaztk/Business-rules-for-T-SQL/tree/main/code), and run the *Install.sql* in your SQL Server database. 


Showcase
===========

There is a showcase sample file prepared to get started with the framework. Go to [github/code](https://github.com/tomaztk/Business-rules-for-T-SQL/tree/main/code), and run the *Showcase.sql* in your SQL Server database. 


Parameters
============

The parametrisation is the core concept of the framework. Without hardcoding the values and attributes to your T-SQL Code, you can store the parameters separately and operate them without tedious code dive.

A simple T-SQL procedure 

```
CREATE PROCEDURE dbo.sp_SampleQuery1
AS
SELECT *  FROM
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
JOIN msdb..MSdatatype_mappings AS m
ON m.dbms_name =  x.dbms_name 
;
GO
```

is converted to parametrised query:

```
CREATE PROCEDURE dbo.sp_SampleQuery1
AS
SELECT * FROM
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
JOIN msdb..MSdatatype_mappings AS m
ON m.dbms_name =  x.dbms_name
```

And the values are separately inserted into table `dbo.BusinessRules_Parameters` with all values:

```
  INSERT INTO dbo.BusinessRules_Parameters ([query_id], [query_parameter_Description], [query_parameter_tableRelated], [query_key], [query_value])
 SELECT 10203
 ,'CASE Statement to determine if ORACLE or SYBASE type'
 ,'master..spt_values'
 ,'$selectkey1'
 ,'CASE WHEN name like ''DB %'' THEN ''ORACLE'' ELSE ''SYBASE'' END As dbms_name'
```


Requirements
============
The framework works with any of the following versions:

* Microsoft SQL Server database (works on all versions and editions) 
* Azure SQL Database 
* Azure SQL Server 
* Azure SQL MI 

and

* queries, views, functions or procedures with hard-coded values :smile: 
* lost documentation and angry data engineers :worried:

Philosophy
=====

The framework should be fun and light, not stern and stressful. Using the framework without explaining to everyone why you shouldn't use it for better results. And it should not be a scary mammoth - if anything, the better choice around.

We believe that parametrisation is the best philosophy.

Clone or fork repository 
=====

If you are interested in collaborating project, feel free to clone or fork the repository. Read about the collaboration [github/collaborate](https://https://github.com/tomaztk/Business-rules-for-T-SQL/blob/main/collaborate.md).

```
git clone https://github.com/tomaztk/Business-rules-for-T-SQL.git
```


License
=======
Sourcerer is under the MIT license. See the [LICENSE](https://github.com/tomaztk/Business-rules-for-T-SQL/blob/main/LICENSE.md) for more information.

Links
=====
* [SQLServer Central Article](https://www.sqlservercentral.com/) published September 2nd, 2022


