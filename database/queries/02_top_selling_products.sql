/*
    Report: Top-selling products by completed-order revenue
    Platform: SQL Server 2025 | Active database: SalesAnalytics
    Read-only report; includes all dates and all qualifying products.
    Sources: ../schema/01_create_tables.sql and ../schema/02_seed_data.sql.
*/

;WITH ProductSales AS
(
    -- Aggregate by ProductID as well as descriptive attributes so distinct
    -- catalog products are not merged if their names and categories match.
    SELECT
        p.ProductID,
        p.ProductName,
        p.Category,
        -- Widen quantities before SUM to avoid the INT aggregate limit.
        SUM(CAST(oi.Quantity AS BIGINT)) AS UnitsSold,
        -- Exact decimal multiplication yields DECIMAL(21,2), and SUM returns
        -- DECIMAL(38,2). Use the stored sale price, not current catalog price.
        SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice) AS TotalRevenue
    FROM dbo.Products AS p
    INNER JOIN dbo.OrderItems AS oi
        ON oi.ProductID = p.ProductID
    INNER JOIN dbo.Orders AS o
        ON o.OrderID = oi.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY
        p.ProductID,
        p.ProductName,
        p.Category
)
SELECT
    ps.ProductName,
    ps.Category,
    ps.UnitsSold,
    ps.TotalRevenue,
    -- Equal revenues share a rank, with no gaps between distinct ranks.
    DENSE_RANK() OVER (ORDER BY ps.TotalRevenue DESC) AS RevenueRank
FROM ProductSales AS ps
ORDER BY
    ps.TotalRevenue DESC,
    ps.ProductName ASC;
