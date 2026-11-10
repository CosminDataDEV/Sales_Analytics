/*
    Sales Analytics data validation | SQL Server 2025 | Read-only
    Select SalesAnalytics as the active database before running this statement.
    Fixed counts and amounts apply ONLY to the supplied synthetic seed dataset.
    Sources: ../schema/01_create_tables.sql, ../schema/02_seed_data.sql,
             and ../queries/01 through 04 analytical reports.
    No objects, temporary tables, or records are created or modified.
    Run against stable data; concurrent changes can affect reconciliation.
*/

;WITH CompletedOrderTotals AS
(
    -- One row per completed order, including itemless zero-value orders.
    SELECT
        o.OrderID,
        o.CustomerID,
        COALESCE(
            SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice),
            CAST(0 AS DECIMAL(38,2))
        ) AS OrderTotal
    FROM dbo.Orders AS o
    LEFT JOIN dbo.OrderItems AS oi ON oi.OrderID = o.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY o.OrderID, o.CustomerID
),
CompletedSummary AS
(
    SELECT
        COUNT_BIG(*) AS CompletedOrders,
        COALESCE(SUM(ot.OrderTotal), CAST(0 AS DECIMAL(38,2))) AS TotalRevenue
    FROM CompletedOrderTotals AS ot
),
MonthlySales AS
(
    -- Reproduce the monthly report's joins, filter, and grouping.
    SELECT
        YEAR(o.OrderDate) AS SalesYear,
        MONTH(o.OrderDate) AS SalesMonth,
        SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice) AS Revenue
    FROM dbo.Orders AS o
    INNER JOIN dbo.OrderItems AS oi ON oi.OrderID = o.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
),
ProductSales AS
(
    SELECT
        p.ProductID,
        p.ProductName,
        p.Category,
        SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice) AS Revenue
    FROM dbo.Products AS p
    INNER JOIN dbo.OrderItems AS oi ON oi.ProductID = p.ProductID
    INNER JOIN dbo.Orders AS o ON o.OrderID = oi.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY p.ProductID, p.ProductName, p.Category
),
CustomerSales AS
(
    SELECT
        c.CustomerID,
        c.FullName,
        COALESCE(SUM(ot.OrderTotal), CAST(0 AS DECIMAL(38,2))) AS Revenue
    FROM dbo.Customers AS c
    LEFT JOIN CompletedOrderTotals AS ot ON ot.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, c.FullName
),
Metrics AS
(
    SELECT
        (SELECT COUNT_BIG(*) FROM dbo.Customers) AS Customers,
        (SELECT COUNT_BIG(*) FROM dbo.Products) AS Products,
        (SELECT COUNT_BIG(*) FROM dbo.Orders) AS Orders,
        (SELECT COUNT_BIG(*) FROM dbo.OrderItems) AS OrderItems,
        s.CompletedOrders,
        s.TotalRevenue,
        CAST(COALESCE(
            ROUND(s.TotalRevenue
                / NULLIF(CAST(s.CompletedOrders AS DECIMAL(19,0)), 0), 2),
            CAST(0 AS DECIMAL(38,6))
        ) AS DECIMAL(38,2)) AS AverageOrderValue,
        COALESCE((SELECT SUM(Revenue) FROM MonthlySales), 0) AS MonthlyRevenue,
        COALESCE((SELECT SUM(Revenue) FROM ProductSales), 0) AS ProductRevenue,
        COALESCE((SELECT SUM(Revenue) FROM CustomerSales), 0) AS CustomerRevenue,
        -- Check every record, including non-completed orders and their items.
        (SELECT COUNT_BIG(*) FROM dbo.Orders AS o
         WHERE NOT EXISTS (SELECT 1 FROM dbo.Customers AS c
                           WHERE c.CustomerID = o.CustomerID)) AS OrphanOrders,
        (SELECT COUNT_BIG(*) FROM dbo.OrderItems AS oi
         WHERE NOT EXISTS (SELECT 1 FROM dbo.Orders AS o
                           WHERE o.OrderID = oi.OrderID)) AS ItemsWithoutOrder,
        (SELECT COUNT_BIG(*) FROM dbo.OrderItems AS oi
         WHERE NOT EXISTS (SELECT 1 FROM dbo.Products AS p
                           WHERE p.ProductID = oi.ProductID)) AS ItemsWithoutProduct,
        (SELECT COUNT_BIG(*) FROM dbo.OrderItems
         WHERE Quantity <= 0 OR Quantity IS NULL) AS InvalidQuantities,
        (SELECT COUNT_BIG(*) FROM dbo.OrderItems
         WHERE UnitPrice < 0 OR UnitPrice IS NULL) AS InvalidUnitPrices,
        (SELECT COUNT_BIG(*) FROM dbo.Products
         WHERE Price < 0 OR Price IS NULL) AS InvalidProductPrices
    FROM CompletedSummary AS s
),
NumericTests AS
(
    -- Normalize values to exact decimals for numeric PASS/FAIL comparisons.
    -- Reconciliation expectations use the computed total, not a fixed amount.
    SELECT
        t.TestOrder,
        t.TestName,
        CAST(t.ExpectedValue AS DECIMAL(38,2)) AS ExpectedValue,
        CAST(t.ActualValue AS DECIMAL(38,2)) AS ActualValue
    FROM Metrics AS m
    CROSS APPLY (VALUES
        (1, N'Customer count (seed only)', 5, m.Customers),
        (2, N'Product count (seed only)', 6, m.Products),
        (3, N'Order count (seed only)', 10, m.Orders),
        (4, N'Order item count (seed only)', 11, m.OrderItems),
        (5, N'Completed order count (seed only)', 8, m.CompletedOrders),
        (6, N'Completed revenue (seed only)', 14950.00, m.TotalRevenue),
        (7, N'Average order value (seed only)', 1868.75, m.AverageOrderValue),
        (8, N'Monthly revenue reconciliation', m.TotalRevenue, m.MonthlyRevenue),
        (9, N'Product revenue reconciliation', m.TotalRevenue, m.ProductRevenue),
        (10, N'Customer revenue reconciliation', m.TotalRevenue, m.CustomerRevenue),
        (11, N'Orders without a customer', 0, m.OrphanOrders),
        (12, N'Order items without an order', 0, m.ItemsWithoutOrder),
        (13, N'Order items without a product', 0, m.ItemsWithoutProduct),
        (14, N'Invalid item quantities', 0, m.InvalidQuantities),
        (15, N'Invalid item unit prices', 0, m.InvalidUnitPrices),
        (16, N'Invalid product prices', 0, m.InvalidProductPrices)
    ) AS t (TestOrder, TestName, ExpectedValue, ActualValue)
),
TestResults AS
(
    SELECT
        nt.TestOrder,
        nt.TestName,
        CONVERT(NVARCHAR(100), nt.ExpectedValue) AS ExpectedResult,
        CONVERT(NVARCHAR(100), nt.ActualValue) AS ActualResult,
        CASE WHEN nt.ActualValue = nt.ExpectedValue THEN N'PASS'
             ELSE N'FAIL' END AS Status
    FROM NumericTests AS nt
),
OutputRows AS
(
    SELECT TestOrder, TestName, ExpectedResult, ActualResult, Status
    FROM TestResults
    UNION ALL
    -- Summary follows all detail tests in the same four-column result set.
    SELECT
        17,
        N'SUMMARY',
        N'Passed: 16; Failed: 0; Total: 16',
        CONCAT(N'Passed: ', SUM(CASE WHEN Status = N'PASS' THEN 1 ELSE 0 END),
               N'; Failed: ', SUM(CASE WHEN Status = N'FAIL' THEN 1 ELSE 0 END),
               N'; Total: ', COUNT_BIG(*)),
        CASE WHEN SUM(CASE WHEN Status = N'FAIL' THEN 1 ELSE 0 END) = 0
             THEN N'PASS' ELSE N'FAIL' END
    FROM TestResults
)
SELECT
    TestName,
    ExpectedResult,
    ActualResult,
    Status
FROM OutputRows
ORDER BY TestOrder;
