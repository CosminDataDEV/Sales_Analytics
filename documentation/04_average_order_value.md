# Average Order Value

## Business purpose

Measure the average sales value of a completed order. AOV complements total revenue and order volume by showing the typical contribution per completed order. It is an arithmetic mean, not a median or a measure of profit.

Query: [04_average_order_value.sql](../database/queries/04_average_order_value.sql).

## Sources and formula

The source of truth is [01_create_tables.sql](../database/schema/01_create_tables.sql) for the schema and [02_seed_data.sql](../database/schema/02_seed_data.sql) for the synthetic demonstration dataset.

```text
OrderTotal = SUM(OrderItems.Quantity * OrderItems.UnitPrice)
CompletedOrders = number of orders with Status = 'Completed'
TotalRevenue = SUM(completed OrderTotal)
AverageOrderValue = ROUND(TotalRevenue / CompletedOrders, 2)
```

The `CompletedOrderTotals` CTE filters Orders to Completed and LEFT JOINs OrderItems, producing one row per OrderID. This prevents orders with multiple items from being counted multiple times. Completed orders without items receive an OrderTotal of zero.

The `SalesSummary` CTE counts these order rows with COUNT_BIG and sums their totals. Because it has no GROUP BY, it produces one summary row even when no completed orders exist. The final SELECT safely divides total revenue by order count and rounds to two decimal places.

| Output | Definition | SQL Server result type |
| --- | --- | --- |
| CompletedOrders | Count of completed orders, including those without items | BIGINT |
| TotalRevenue | Sum of completed-order line amounts | DECIMAL(38,2) |
| AverageOrderValue | TotalRevenue / CompletedOrders, rounded to two decimals; zero when count is zero | DECIMAL(38,2) |

## Numeric precision and safe division

Quantity is cast to DECIMAL(10,0) before multiplication by UnitPrice DECIMAL(10,2), yielding DECIMAL(21,2) line amounts. SUM returns DECIMAL(38,2). The order count is converted to DECIMAL(19,0), which accommodates the positive BIGINT range, before division. SQL Server's decimal precision rules give this division a DECIMAL(38,6) result. ROUND applies two-decimal rounding, and the final CAST fixes the displayed scale to two decimal places. No floating-point arithmetic is used.

NULLIF converts a zero order count to NULL, preventing division by zero. COALESCE then returns 0.00 for AOV. TotalRevenue is also explicitly zero when there are no completed orders, so the single output row is `0 | 0.00 | 0.00`. Zero AOV in this situation is a reporting convention rather than an observed average.

## Assumptions and exclusions

- Only orders matching Status = 'Completed' qualify. Pending, Cancelled, and other statuses are excluded from both revenue and the denominator.
- All order dates are included; no reporting-period filter is applied.
- A Completed order without items counts once, contributes zero revenue, and lowers AOV relative to an analysis that excludes such orders.
- Revenue uses the transaction price stored in OrderItems.UnitPrice, not the current Products.Price.
- RON is the project reporting convention; the schema has no currency column and the query performs no currency conversion. Taxes, discounts, refunds, costs, and payments are not modeled; the report measures the defined sales amount, not profit or verified cash receipts.
- Overall AOV is calculated from total revenue and total orders, rather than averaging customer or monthly averages without weighting.

## Expected results and offline validation

For exactly the supplied seed data:

| CompletedOrders | TotalRevenue | AverageOrderValue |
| --- | --- | --- |
| 8 | 14950.00 | 1868.75 |

| Completed order date | Order total |
| --- | --- |
| 2026-01-10 | 3800.00 |
| 2026-01-15 | 900.00 |
| 2026-02-03 | 2400.00 |
| 2026-02-14 | 450.00 |
| 2026-03-01 | 1800.00 |
| 2026-03-18 | 3500.00 |
| 2026-04-20 | 1200.00 |
| 2026-05-25 | 900.00 |

```text
TotalRevenue = 3800 + 900 + 2400 + 450 + 1800 + 3500 + 1200 + 900
             = 14950.00
AOV          = ROUND(14950.00 / 8, 2) = 1868.75
```

The Pending order dated April 5 (450.00) and the Cancelled order dated May 12 (900.00) are excluded. The eight Completed orders contain nine order items, demonstrating why counting item rows would give an incorrect denominator.

Offline validation parsed the seed file, resolved product prices and order statuses, initialized one total per completed order, and accumulated line amounts with decimal arithmetic. Assertions confirmed 8 completed orders, 14950.00 revenue, and 1868.75 AOV. The original calculations were validated offline without executing SQL. The project owner subsequently supplied an SSMS result showing 8 completed orders, 14950.00 revenue, and 1868.75 AOV, matching these expectations. See the [validation guide](05_data_validation.md) for the manual validation summary.

The total reconciles to the [monthly revenue report](01_monthly_sales_revenue.md): 4700 + 2850 + 5300 + 1200 + 900 = 14950.00. It also matches the [customer sales report](03_customer_sales_analysis.md), which totals eight completed orders and 14950.00 spending.

The supplied seed does not contain itemless Completed orders or a zero-order dataset. Their behavior is defined by LEFT JOIN, COALESCE, and NULLIF in the query; it has not been verified by executing SQL.

## How to execute

1. In an authorized SQL Server client, connect to the instance containing the already prepared SalesAnalytics database.
2. Select `SalesAnalytics` as the active database.
3. Open `database/queries/04_average_order_value.sql` and execute the complete CTE and SELECT statement together.
4. If the database contains exactly the supplied seed data, compare the single output row with the expected results above.

This report is read-only and does not create objects or change data. Do not rerun schema or seed scripts against populated tables to execute the report.
