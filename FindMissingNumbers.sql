-- Find the missing numbers from 1-20
-- Creates a table and inserts a few values
DROP TABLE IF EXISTS #MissingNumber;

CREATE TABLE #MissingNumber (Number int);

INSERT INTO #MissingNumber VALUES (1),(2),(3),(5),(8),(11),(16),(20);
GO

-- Recursive CTE to generate numbers 1-20
WITH NumberCte
AS
(
SELECT 1 AS Number
UNION ALL
SELECT Number + 1 FROM NumberCte WHERE Number < 20
)
-- Compare to our table missing numbers
SELECT cte.Number 
FROM NumberCte cte
LEFT OUTER JOIN #MissingNumber mn ON mn.Number = cte.Number
WHERE mn.Number IS NULL;

