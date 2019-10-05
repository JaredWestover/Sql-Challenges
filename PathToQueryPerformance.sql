USE [ABCCompany];
GO


-- How big are our tables?
sp_spaceused 'Salesorder';
GO

sp_spaceused 'SalesPerson';
GO

/*

- Part 1 -

Why Indexes Make Everything Better
*/

-- A great tool to see how many pages we are reading back
-- Let's turn on the actual execution plan
SET STATISTICS IO ON;


-- Can we add an index here?
-- Singleton lookup (only returning one row)
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE sp.Email = 'AllyRickis@ABCCorp.com';






-- Easy way to check the indexes on SalesPerson
EXECUTE sp_help 'SalesPerson';
GO




-- What do we want to create an index on?






-- Good idea to add an index on a column in a where clause
CREATE NONCLUSTERED INDEX IX_SalesPerson_Email ON SalesPerson (Email);
GO








-- Let's see what it did
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE sp.Email = 'AllyRickis@ABCCorp.com';
GO








-- Covering Index
-- Include columns added to leaf level of an index
CREATE NONCLUSTERED INDEX IX_SalesPerson_Email_Name ON SalesPerson (Email)
	INCLUDE (LastName,FirstName);
GO









-- This one should be a bit better
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE sp.Email = 'AllyRickis@ABCCorp.com';
GO









-- Once it's in place don't invalidate the seek!
-- Invalidate with a LIKE operator
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE sp.Email LIKE '%AllyRickis@ABCCorp.com';
GO









-- This will work sometimes
-- Place the wild card operator on the right
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE sp.Email LIKE 'AllyRickis@ABCCorp.com%';
GO










-- Invalidate with a function
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE LOWER(sp.Email) = 'AllyRickis@ABCCorp.com';
GO




-- Invalidate with a function
SELECT	Id AS 'EmployeeId'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
FROM dbo.SalesPerson sp
WHERE LTRIM(RTRIM((sp.Email))) = 'AllyRickis@ABCCorp.com';
GO







-- The last time a sales person made a sale
-- Covering Index
-- What do we want to create an index on?
SELECT	CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
		,MAX(so.SalesDate) AS 'LastSalesDate'
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
WHERE sp.Email = 'AllyRickis@ABCCorp.com'
GROUP BY sp.LastName, sp.FirstName;
GO





-- Easy way to check the indexes on SalesOrder
EXECUTE sp_help 'SalesOrder';
GO


-- What do you think we should create an index on?







CREATE NONCLUSTERED INDEX IX_SalesOrder_SalesPersonSalesDate ON SalesOrder (SalesPerson)
INCLUDE (SalesDate);
GO







-- The last time a sales person made a sale
-- Covering Index
-- What do we want to create an index on?
SELECT	CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPerson'
		,MAX(so.SalesDate) AS 'LastSalesDate'
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
WHERE sp.Email = 'AllyRickis@ABCCorp.com'
GROUP BY sp.LastName, sp.FirstName;
GO










-- Filtered Index
-- Sales information for the year 2019
SELECT	
		so.CreateDate
		,sp.FirstName
		,sp.lastName
		,SUM(so.SalesAmount)
FROM SalesOrder so 
INNER JOIN SalesPerson sp ON sp.Id = so.SalesPerson
WHERE YEAR(so.CreateDate) = 2019
GROUP BY so.CreateDate ,sp.FirstName ,sp.lastName;
GO






-- Create the index and see if it works now
CREATE NONCLUSTERED INDEX IX_SalesOrder_Year2019 ON SalesOrder (SalesPerson, CreateDate)
INCLUDE (SalesAmount) WHERE CreateDate >= '1/1/2019' AND CreateDate <= '12/31/2019';
GO






-- Let rerun and see what we get
SELECT	
		so.CreateDate
		,sp.FirstName
		,sp.lastName
		,SUM(so.SalesAmount)
FROM SalesOrder so 
INNER JOIN SalesPerson sp ON sp.Id = so.SalesPerson
WHERE YEAR(so.CreateDate) = 2019
GROUP BY so.CreateDate ,sp.FirstName ,sp.lastName;
GO








-- Much Better!
SELECT	
		so.CreateDate
		,sp.Id
		,SUM(so.SalesAmount)
FROM SalesOrder so 
INNER JOIN SalesPerson sp ON sp.Id = so.SalesPerson
WHERE so.CreateDate >= '1/1/2019' AND so.CreateDate <= '12/31/2019'
GROUP BY so.CreateDate ,sp.Id







-- Missing Index Script
-- Original Author: Pinal Dave 
SELECT TOP 25
dm_mid.database_id AS DatabaseID,
dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) Avg_Estimated_Impact,
dm_migs.last_user_seek AS Last_User_Seek,
dm_migs.user_scans,
dm_migs.user_seeks,
OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) AS [TableName],
'CREATE INDEX [IX_' + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) + '_'
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''),', ','_'),'[',''),']','') 
+ CASE
WHEN dm_mid.equality_columns IS NOT NULL
AND dm_mid.inequality_columns IS NOT NULL THEN '_'
ELSE ''
END
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''),', ','_'),'[',''),']','')
+ ']'
+ ' ON ' + dm_mid.statement
+ ' (' + ISNULL (dm_mid.equality_columns,'')
+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns 
IS NOT NULL THEN ',' ELSE
'' END
+ ISNULL (dm_mid.inequality_columns, '')
+ ')'
+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '') AS Create_Statement
FROM sys.dm_db_missing_index_groups dm_mig
INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
ON dm_migs.group_handle = dm_mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details dm_mid
ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
ORDER BY Avg_Estimated_Impact DESC
GO


-- Unused Index Script
-- Original Author: Pinal Dave 
SELECT TOP 25
o.name AS ObjectName
, i.name AS IndexName
, i.index_id AS IndexID
, dm_ius.user_seeks AS UserSeek
, dm_ius.user_scans AS UserScans
, dm_ius.user_lookups AS UserLookups
, dm_ius.user_updates AS UserUpdates
, p.TableRows
FROM sys.dm_db_index_usage_stats dm_ius
INNER JOIN sys.indexes i ON i.index_id = dm_ius.index_id 
AND dm_ius.OBJECT_ID = i.OBJECT_ID
INNER JOIN sys.objects o ON dm_ius.OBJECT_ID = o.OBJECT_ID
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
INNER JOIN (SELECT SUM(p.rows) TableRows, p.index_id, p.OBJECT_ID
FROM sys.partitions p GROUP BY p.index_id, p.OBJECT_ID) p
ON p.index_id = dm_ius.index_id AND dm_ius.OBJECT_ID = p.OBJECT_ID
WHERE OBJECTPROPERTY(dm_ius.OBJECT_ID,'IsUserTable') = 1
AND dm_ius.database_id = DB_ID()
AND i.type_desc = 'nonclustered'
AND i.is_primary_key = 0
AND i.is_unique_constraint = 0
ORDER BY (dm_ius.user_seeks + dm_ius.user_scans + dm_ius.user_lookups) ASC








-- How big the indexes are
SELECT
    i.name AS IndexName,
    SUM(s.page_count * 8) AS IndexSizeKB
FROM sys.dm_db_index_physical_stats(
    db_id(), object_id('dbo.TableName'), NULL, NULL, 'DETAILED') AS s
JOIN sys.indexes AS i
ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
GROUP BY i.name
ORDER BY i.name





-- How fragmented they are
SELECT OBJECT_NAME(ips.OBJECT_ID) AS 'TableName'
 ,i.NAME
 ,index_type_desc
 ,avg_fragmentation_in_percent
 ,page_count
 ,page_count * 8 AS 'size in kb'
 ,ips.record_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
INNER JOIN sys.indexes i ON (ips.object_id = i.object_id)
 AND (ips.index_id = i.index_id)
WHERE page_count > 1000
ORDER BY avg_fragmentation_in_percent DESC;
GO




ALTER INDEX PK_SalesOrder ON dbo.SalesOrder
REBUILD;
GO


ALTER INDEX PK_SalesOrder ON dbo.SalesOrder
REORGANIZE;
GO





/*
- Part 2 -

Exploring Columnstore Indexes
*/


SET STATISTICS IO ON;

-- Sales by salesperson per month
SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName







-- Lets create our nonclustered columnstore index
CREATE NONCLUSTERED COLUMNSTORE INDEX CS_SalesAmount_SalesDate ON SalesOrder (SalesAmount, SalesDate);
GO






-- Rerun and see what happen

SET STATISTICS IO ON;

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName





-- Why didn't it use the new index?







-- Lets include all the columns
CREATE NONCLUSTERED COLUMNSTORE INDEX CS_SalesAmount_SalesDate ON SalesOrder (SalesAmount, SalesDate, SalesPerson)
WITH (DROP_EXISTING = ON);
GO





-- We read segments with columnstore around 1 million rows.
SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName







--What if I want to create a second columnstore index? 
CREATE NONCLUSTERED COLUMNSTORE INDEX CS_SalesAmount_IsShipped ON SalesOrder (SalesAmount, IsShipped);
GO






-- All of 2018 & 2019 
-- Should see some segements skipped
SET STATISTICS IO ON;

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
WHERE so.SalesDate >='1/1/2018' AND so.SalesDate <= '1/1/2019'
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName;
GO






-- Create same index but use row store
CREATE NONCLUSTERED INDEX IX_SalesAmount_SalesDate ON [dbo].[SalesOrder] ([SalesDate])
INCLUDE ([SalesPerson],[SalesAmount])
GO




-- Compare the Columnstore index with the b-tree
SET STATISTICS IO ON;

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so WITH (INDEX = CS_SalesAmount_SalesDate)
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
WHERE so.SalesDate >='1/1/2018' AND so.SalesDate <= '1/1/2019'
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName;
GO

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so --WITH (INDEX = IX_SalesAmount_SalesDate)
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
WHERE so.SalesDate >='1/1/2018' AND so.SalesDate <= '1/1/2019'
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName;
GO





-- Let's checkout the size between the two
SELECT i.[name] AS IndexName
    ,SUM(s.[used_page_count]) * 8 AS IndexSizeKB
FROM sys.dm_db_partition_stats AS s
INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
WHERE i.[name] IN ('CS_SalesAmount_SalesDate','IX_SalesAmount_SalesDate')
GROUP BY i.[name]
ORDER BY i.[name];
GO







-- Check to see how fragmented the CS index is
SELECT i.object_id,   
    object_name(i.object_id) AS TableName,   
    i.index_id,   
    i.name AS IndexName,  
    100*(ISNULL(SUM(CSRowGroups.deleted_rows),0))/NULLIF(SUM(CSRowGroups.total_rows),0) AS 'Fragmentation'
FROM sys.indexes AS i  
INNER JOIN sys.dm_db_column_store_row_group_physical_stats AS CSRowGroups  
    ON i.object_id = CSRowGroups.object_id 
	  AND i.index_id = CSRowGroups.index_id   
GROUP BY i.object_id, i.index_id, i.name 
ORDER BY object_name(i.object_id), i.name;
GO







-- Hack to use Batch Mode
-- Should not need the hack in 2019
DROP TABLE IF EXISTS #TestTable;
GO

CREATE TABLE #TestTable (Id int);
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX IX_TestTable ON #TestTable (id);
GO

SET STATISTICS IO ON;

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so WITH (INDEX = IX_SalesAmount_SalesDate)
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
WHERE so.SalesDate >='1/1/2018' AND so.SalesDate <= '1/1/2019'
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName;
GO

SELECT	SUM(so.SalesAmount) AS 'SalesAmount'
		,MONTH(so.SalesDate) AS 'Month'
		,YEAR(so.SalesDate) AS 'Year'
		,CONCAT(sp.LastName,', ',sp.FirstName) AS 'SalesPersonName'
FROM SalesOrder so WITH (INDEX = IX_SalesAmount_SalesDate)
LEFT OUTER JOIN #TestTable ON 1=0
INNER JOIN SalesPerson sp ON so.SalesPerson = sp.Id
WHERE so.SalesDate >='1/1/2018' AND so.SalesDate <= '1/1/2019'
GROUP BY MONTH(so.SalesDate), YEAR(so.SalesDate), sp.LastName, sp.FirstName;
GO




-- We can see the various segments
SELECT 
OBJECT_NAME(c.OBJECT_ID) AS 'Table Name',
i.[name] AS 'Index Name',
c.total_rows AS 'Total Rows',
c.size_in_bytes/1000 AS 'Size in KB',
c.state_desc,
c.trim_reason_desc
FROM sys.dm_db_column_store_row_group_physical_stats c
INNER JOIN sys.indexes i ON c.index_id = i.index_id;
GO





-- Niko Neugebauer
-- Tons of information on http://www.nikoport.com/columnstore/ 100+ Blog post




/*
- Part 3 -

Reading an Execution Plan
*/

-- First came out in 2016
-- Let's checkout the live query
-- SSMS 18 has the actual and estimates
SELECT * FROM SalesOrder;
GO






--- Physical Joins
---- Nested Loop
---- Merge 
---- Hash Match
---- New - Adaptive Join






-- Hash Match?
-- SalesPersonLevel only has 3 rows in it

SELECT sp.Email, spl.LevelName 
FROM SalesPerson sp
INNER JOIN SalesPersonLevel spl ON sp.LevelId = spl.Id;
GO











-- Let's see if adding the index helps
CREATE NONCLUSTERED INDEX IX_SalesPerson_LevelId ON SalesPerson (LevelId)
INCLUDE (Email)
GO





-- Which one is better?
SELECT sp.Email, spl.LevelName 
FROM SalesPerson sp WITH (INDEX = PK_SalesPerson)
INNER JOIN SalesPersonLevel spl  ON sp.LevelId = spl.Id;
GO
SELECT sp.Email, spl.LevelName 
FROM SalesPerson sp WITH (INDEX = IX_SalesPerson_LevelId)
INNER JOIN SalesPersonLevel spl  ON sp.LevelId = spl.Id;
GO








-- Implicit Conversion
-- Causes an issue with the seek
SELECT sp.Email, spl.LevelName FROM dbo.BadSalesPerson sp
INNER JOIN SalesPersonLevel spl ON sp.LevelId = spl.Id
WHERE sp.Id = 1;
GO









-- Estimates vs Actuals OFF
-- Statistics
DBCC SHOW_STATISTICS ("dbo.SalesPerson", IX_SalesPerson_Email_Name);  
GO







-- Estimate will be way off with Table Variable
DECLARE @SlowVariable AS TABLE (SalesPerson int, Amount decimal(16,2));

INSERT INTO @SlowVariable (SalesPerson, Amount) 
	SELECT Salesperson, SalesAmount FROM SalesOrder
	WHERE ID < 1000000;

SELECT SUM(Amount) FROM @SlowVariable t
JOIN dbo.SalesPerson sp ON sp.Id = t.SalesPerson


-- Now with a temp table
DROP TABLE IF EXISTS #FasterTempTable

SELECT Salesperson, SalesAmount 
INTO #FasterTempTable FROM SalesOrder 
	WHERE ID < 1000000;


SELECT SUM(t.SalesAmount) FROM #FasterTempTable t
JOIN dbo.SalesPerson sp ON sp.Id = t.SalesPerson


ALTER INDEX CS_SalesAmount_SalesDate ON SalesOrder  
DISABLE; 
GO


-- Parameter Sniffing
-- Please do not run this in production
DBCC FREEPROCCACHE;
GO







CREATE OR ALTER PROCEDURE dbo.GenerateSalesReport
@StartDate date,
@EndDate date
AS
SELECT SUM(so.SalesAmount) AS 'SalesAmount'
	   ,spl.LevelName AS 'Level'
	   ,CONCAT(sp.LastName,', ',sp.FirstName) AS 'FullName'
	   ,YEAR(so.SalesDate) AS 'SalesYear'
	   ,MONTH(so.SalesDate) AS 'SalesMonth' 
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
INNER JOIN dbo.SalesPersonLevel spl ON spl.Id = sp.LevelId
WHERE so.SalesDate >= @StartDate AND so.SalesDate <= @EndDate
GROUP BY spl.LevelName, sp.LastName, sp.FirstName, YEAR(so.SalesDate), MONTH(so.SalesDate);
GO





-- Only a couple of days
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '01/02/2019';
GO







-- Now one year
-- Lets look at the execution plan
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '12/31/2019';
GO





-- Recompile at runtime
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '12/31/2019'
								  WITH RECOMPILE;
GO





-- Recompile every time
CREATE OR ALTER PROCEDURE dbo.GenerateSalesReport
@StartDate date,
@EndDate date
WITH RECOMPILE
AS
SELECT SUM(so.SalesAmount) AS 'SalesAmount'
	   ,spl.LevelName AS 'Level'
	   ,CONCAT(sp.LastName,', ',sp.FirstName) AS 'FullName'
	   ,YEAR(so.SalesDate) AS 'SalesYear'
	   ,MONTH(so.SalesDate) AS 'SalesMonth' 
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
INNER JOIN dbo.SalesPersonLevel spl ON spl.Id = sp.LevelId
WHERE so.SalesDate >= @StartDate AND so.SalesDate <= @EndDate
GROUP BY spl.LevelName, sp.LastName, sp.FirstName, YEAR(so.SalesDate), MONTH(so.SalesDate);
GO




-- At the statement level
CREATE OR ALTER PROCEDURE dbo.GenerateSalesReport
@StartDate date,
@EndDate date
AS
SELECT SUM(so.SalesAmount) AS 'SalesAmount'
	   ,spl.LevelName AS 'Level'
	   ,CONCAT(sp.LastName,', ',sp.FirstName) AS 'FullName'
	   ,YEAR(so.SalesDate) AS 'SalesYear'
	   ,MONTH(so.SalesDate) AS 'SalesMonth' 
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
INNER JOIN dbo.SalesPersonLevel spl ON spl.Id = sp.LevelId
WHERE so.SalesDate >= @StartDate AND so.SalesDate <= @EndDate
GROUP BY spl.LevelName, sp.LastName, sp.FirstName, YEAR(so.SalesDate), MONTH(so.SalesDate)
OPTION (RECOMPILE);
GO



-- Only one day
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '01/02/2019';
GO




-- Now one year
-- Lets look at the execution plan
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '12/31/2019';
GO





ALTER INDEX CS_SalesAmount_SalesDate ON SalesOrder  
REBUILD; 
GO



CREATE OR ALTER PROCEDURE dbo.GenerateSalesReport
@StartDate date,
@EndDate date
AS
SELECT SUM(so.SalesAmount) AS 'SalesAmount'
	   ,spl.LevelName AS 'Level'
	   ,CONCAT(sp.LastName,', ',sp.FirstName) AS 'FullName'
	   ,YEAR(so.SalesDate) AS 'SalesYear'
	   ,MONTH(so.SalesDate) AS 'SalesMonth' 
FROM dbo.SalesPerson sp
INNER JOIN dbo.SalesOrder so ON so.SalesPerson = sp.Id
INNER JOIN dbo.SalesPersonLevel spl ON spl.Id = sp.LevelId
WHERE so.SalesDate >= @StartDate AND so.SalesDate <= @EndDate
GROUP BY spl.LevelName, sp.LastName, sp.FirstName, YEAR(so.SalesDate), MONTH(so.SalesDate);
GO


DBCC FREEPROCCACHE;
GO



-- Just one day
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '01/02/2019';
GO




-- Now one year
-- Lets look at the execution plan
EXECUTE dbo.GenerateSalesReport @StartDate = '01/01/2019',
								  @EndDate = '12/31/2019';
GO





-- Let's check our stats
-- In process executions will not show up
SELECT	ps.cached_time AS 'Cached',
		ps.execution_count AS 'Execution Count',
		ps.last_execution_time AS 'Last Execution Time',
		ps.last_logical_reads AS 'Last Logical Reads',
		ps.max_logical_reads AS 'Max Logical Reads',
		ps.min_logical_reads AS 'Min Logical Reads',
		ps.last_logical_writes AS 'Last Logical Writes',
		(ps.last_elapsed_time / 1000) AS 'Last Elapsed Time',
		(ps.max_elapsed_time / 1000) AS 'Max Elapsed Time',
		(ps.min_elapsed_time / 1000) AS 'Min Elapsed Time'
FROM [sys].[dm_exec_procedure_stats] ps
WHERE [object_id] = object_id('dbo.GenerateSalesReport');
GO






-- A lot more coming in 2019 with Adaptive Query Processing















SELECT cp.usecounts 'Execution Counts'
	   ,cp.size_in_bytes 'Size in Bytes'
	   ,cp.objtype 'Type'
	   ,st.text 'SQL Text'
	   ,cp.plan_handle
 FROM [sys].[dm_exec_cached_plans] cp
CROSS APPLY [sys].[dm_exec_sql_text](cp.plan_handle) st
WHERE text like '%@StartDate AND%' AND cp.objtype = 'Proc';
GO


DBCC FREEPROCCACHE(0x05001500A12B1401D042C1B1FB01000001000000000000000000000000000000000000000000000000000000)



DROP  INDEX IF EXISTS IX_SalesPerson_Email ON SalesPerson;
GO

DROP  INDEX IF EXISTS IX_SalesPerson_Email_Name ON SalesPerson;
GO

DROP  INDEX IF EXISTS IX_SalesOrder_Year2019 ON SalesOrder;
GO

DROP  INDEX IF EXISTS IX_SalesOrder_IsShipped ON SalesOrder;
GO

DROP INDEX IF EXISTS IX_SalesOrder_SalesPersonSalesDate ON SalesOrder;
GO

DROP INDEX IF EXISTS CS_SalesAmount_SalesDate ON SalesOrder;
GO

DROP INDEX IF EXISTS IX_SalesAmount_SalesDate ON SalesOrder;
GO

DROP INDEX IF EXISTS CS_SalesAmount_IsShipped ON SalesOrder;
GO


DROP INDEX IF EXISTS IX_SalesPerson_LevelId ON SalesPerson;
GO




DBCC IND ('ABCCompany','SalesPerson',1);


DBCC TRACEON (3604)
DBCC PAGE ('ABCCompany',1,1016112,3)


SELECT * FROM sys.[column_store_segments]

SELECT * FROM sys.[dm_db_partition_stats]
WHERE partition_id = 72057594049331200