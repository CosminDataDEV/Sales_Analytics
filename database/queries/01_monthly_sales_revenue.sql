/*
    Report: Monthly sales revenue
    Platform: SQL Server 2025 | Database: SalesAnalytics
    Sources: dbo.Orders and dbo.OrderItems; see ../schema/01_create_tables.sql.
    Read-only: run with SalesAnalytics selected as the active database.

    Attribute revenue to the calendar year/month of OrderDate.
    Include only Completed orders; Pending and Cancelled orders are excluded.
    Use the stored order-line UnitPrice, not the current Products.Price.
    Months without qualifying order items are omitted.
*/

SELECT
    YEAR(o.OrderDate) AS SalesYear,
    MONTH(o.OrderDate) AS SalesMonth,
    -- DECIMAL(10,0) holds the full INT quantity range. Multiplication by
    -- DECIMAL(10,2) yields DECIMAL(21,2); SUM returns DECIMAL(38,2).
    -- Exact decimal arithmetic preserves cents without floating-point rounding.
    SUM(CAST(oi.Quantity AS DECIMAL(10,0)) * oi.UnitPrice) AS Revenue
FROM dbo.Orders AS o
INNER JOIN dbo.OrderItems AS oi
    ON oi.OrderID = o.OrderID
WHERE o.Status = N'Completed'
GROUP BY
    YEAR(o.OrderDate),
    MONTH(o.OrderDate)
ORDER BY
    SalesYear ASC,
    SalesMonth ASC;
