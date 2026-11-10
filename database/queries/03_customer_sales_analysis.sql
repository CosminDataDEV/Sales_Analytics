/*
    Report: Customer sales analysis | SQL Server 2025
    Run with SalesAnalytics selected as the active database. Read-only.
    Sources: ../schema/01_create_tables.sql and ../schema/02_seed_data.sql.
    Include every customer and count only Completed orders, across all dates.
*/

;WITH CompletedOrderTotals AS
(
    -- One row per completed order prevents line items from inflating counts.
    -- A completed order with no items counts as an order with a zero total.
    SELECT
        o.OrderID,
        o.CustomerID,
        COALESCE(
            SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice),
            CAST(0 AS DECIMAL(38,2))
        ) AS OrderTotal
    FROM dbo.Orders AS o
    LEFT JOIN dbo.OrderItems AS oi
        ON oi.OrderID = o.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY
        o.OrderID,
        o.CustomerID
),
CustomerSales AS
(
    -- Keep the status filter in the prior CTE so this LEFT JOIN retains
    -- customers without completed orders. COUNT_BIG ignores unmatched IDs.
    SELECT
        c.CustomerID,
        c.FullName,
        COUNT_BIG(ot.OrderID) AS CompletedOrders,
        COALESCE(
            SUM(ot.OrderTotal),
            CAST(0 AS DECIMAL(38,2))
        ) AS TotalSpent,
        -- AVG over one row per order equals TotalSpent / CompletedOrders.
        -- Decimal arithmetic is retained; round only the final display to cents.
        CAST(
            COALESCE(AVG(ot.OrderTotal), CAST(0 AS DECIMAL(38,6)))
            AS DECIMAL(38,2)
        ) AS AverageOrderValue
    FROM dbo.Customers AS c
    LEFT JOIN CompletedOrderTotals AS ot
        ON ot.CustomerID = c.CustomerID
    GROUP BY
        c.CustomerID,
        c.FullName
)
SELECT
    cs.CustomerID,
    cs.FullName,
    cs.CompletedOrders,
    cs.TotalSpent,
    cs.AverageOrderValue,
    -- Equal spending receives the same rank, without gaps.
    DENSE_RANK() OVER (ORDER BY cs.TotalSpent DESC) AS CustomerRank
FROM CustomerSales AS cs
ORDER BY
    cs.TotalSpent DESC,
    cs.CustomerID ASC;
