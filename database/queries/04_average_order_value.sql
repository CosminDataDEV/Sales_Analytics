/*
    Report: Average order value (AOV) | SQL Server 2025
    Run with SalesAnalytics selected as the active database. Read-only.
    Sources: ../schema/01_create_tables.sql and ../schema/02_seed_data.sql.
    Include Completed orders across all dates, including orders without items.
*/

;WITH CompletedOrderTotals AS
(
    -- Reduce items to one row per completed order before counting orders.
    -- LEFT JOIN retains itemless orders, whose total is explicitly zero.
    SELECT
        o.OrderID,
        COALESCE(
            SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice),
            CAST(0 AS DECIMAL(38,2))
        ) AS OrderTotal
    FROM dbo.Orders AS o
    LEFT JOIN dbo.OrderItems AS oi
        ON oi.OrderID = o.OrderID
    WHERE o.Status = N'Completed'
    GROUP BY
        o.OrderID
),
SalesSummary AS
(
    -- An aggregate without GROUP BY returns one row even with no orders.
    SELECT
        COUNT_BIG(*) AS CompletedOrders,
        COALESCE(
            SUM(ot.OrderTotal),
            CAST(0 AS DECIMAL(38,2))
        ) AS TotalRevenue
    FROM CompletedOrderTotals AS ot
)
SELECT
    ss.CompletedOrders,
    ss.TotalRevenue,
    -- Decimal division avoids integer truncation. NULLIF prevents division
    -- by zero; COALESCE reports zero AOV when no completed orders exist.
    -- ROUND applies two-place rounding; CAST fixes the output scale to two.
    CAST(
        COALESCE(
            ROUND(
                ss.TotalRevenue
                / NULLIF(CAST(ss.CompletedOrders AS DECIMAL(19,0)), 0),
                2
            ),
            CAST(0 AS DECIMAL(38,6))
        )
        AS DECIMAL(38,2)
    ) AS AverageOrderValue
FROM SalesSummary AS ss;
