# Customer Sales Analysis

## Business purpose

Compare customer spending and order frequency to identify high-value customers while retaining customers who have not completed a purchase. Average order value provides context for spending alongside completed-order counts.

Query: [03_customer_sales_analysis.sql](../database/queries/03_customer_sales_analysis.sql).

## Sources and calculation

The report follows [01_create_tables.sql](../database/schema/01_create_tables.sql) and uses [02_seed_data.sql](../database/schema/02_seed_data.sql) for expected demonstration results.

1. `CompletedOrderTotals` filters Orders to `Status = N'Completed'`, LEFT JOINs OrderItems, and calculates each order total as `SUM(Quantity * UnitPrice)`. Grouping by OrderID and CustomerID produces exactly one row per completed order, regardless of its number of items.
2. `CustomerSales` LEFT JOINs all Customers to these order totals. It counts matched OrderIDs rather than joined line items, sums order totals, and averages those totals. Unmatched customers receive zero counts, spending, and average order value.
3. The final SELECT assigns `DENSE_RANK()` by TotalSpent descending and sorts by TotalSpent descending, then CustomerID ascending. Equal spending receives equal ranks without gaps; CustomerID breaks display ties only.

| Output | Meaning | Result type |
| --- | --- | --- |
| CustomerID | Actual database customer identifier | INT |
| FullName | Customer name | NVARCHAR(100) |
| CompletedOrders | Number of completed orders, counted once each | BIGINT |
| TotalSpent | Sum of completed-order totals | DECIMAL(38,2) |
| AverageOrderValue | Mean completed-order total, rounded to two decimals | DECIMAL(38,2) |
| CustomerRank | Dense rank by spending, highest first | BIGINT |

Quantity is cast to `DECIMAL(10,0)` before multiplication by `UnitPrice DECIMAL(10,2)`, producing exact `DECIMAL(21,2)` line amounts. SUM returns `DECIMAL(38,2)`. AVG of the decimal order totals returns `DECIMAL(38,6)` and is cast to two decimals for presentation. No floating-point arithmetic or integer division is used. AVG is equivalent to TotalSpent divided by CompletedOrders when at least one completed order exists, without a divide-by-zero expression.

## Assumptions and edge cases

- All customers appear, including those with no orders or only Pending/Cancelled orders. These customers receive CompletedOrders = 0, TotalSpent = 0.00, and AverageOrderValue = 0.00. Their zero spending participates in ranking normally.
- A Completed order without items is counted once with a zero order total and is included in the average denominator. This makes order count reflect order status independently of item availability. Such orders do not change revenue reconciliation.
- The Completed filter is applied before joining customers. An outer WHERE filter on joined order status would incorrectly remove unmatched customers.
- All dates are included. Spending uses the stored OrderItems.UnitPrice rather than current catalog prices.
- CustomerID, rather than FullName, defines customer identity. Customers with identical names remain separate.
- The schema does not identify currency, refunds, taxes, discounts, costs, or payments. TotalSpent is the defined sales measure, not verified cash received or profit. Amounts are interpreted as RON by project convention; no currency column or conversion is implemented.
- Customer ranks depend on the current data. Customers sharing zero or positive spending share a rank.

## Expected results for the supplied seed data

| CustomerID* | FullName | CompletedOrders | TotalSpent | AverageOrderValue | CustomerRank |
| --- | --- | --- | --- | --- | --- |
| 1 | Andrei Popescu | 2 | 7300.00 | 3650.00 | 1 |
| 3 | Alex Dumitrescu | 2 | 3600.00 | 1800.00 | 2 |
| 5 | Mihai Stan | 2 | 2700.00 | 1350.00 | 3 |
| 2 | Maria Ionescu | 1 | 900.00 | 900.00 | 4 |
| 4 | Ioana Georgescu | 1 | 450.00 | 450.00 | 5 |

*The displayed IDs assume newly created tables with untouched IDENTITY(1,1) values and the customer insertion sequence in the seed script. Empty tables can have advanced identity counters, so actual IDs may differ. The query uses actual IDs and does not assume these numeric values; names, counts, and monetary expectations follow the supplied business-key mappings.*

| Customer | Completed order totals | Reconciliation |
| --- | --- | --- |
| Andrei Popescu | Jan 10: 3500 + 2 x 150 = 3800; Mar 18: 3500 | 3800 + 3500 = 7300.00 |
| Alex Dumitrescu | Feb 03: 2 x 1200 = 2400; Apr 20: 1200 | 2400 + 1200 = 3600.00 |
| Mihai Stan | Mar 01: 1800; May 25: 2 x 450 = 900 | 1800 + 900 = 2700.00 |
| Maria Ionescu | Jan 15: 900 | 900.00 |
| Ioana Georgescu | Feb 14: 450 | 450.00 |

Maria's Pending order on April 5 (450.00) and Ioana's Cancelled order on May 12 (900.00) are excluded from spending, counts, and averages.

## Reconciliation with monthly revenue

The [monthly revenue report](01_monthly_sales_revenue.md) and this report aggregate the same completed-order line amounts along different dimensions:

```text
Customer totals: 7300 + 3600 + 2700 + 900 + 450 = 14950.00
Monthly totals:  4700 + 2850 + 5300 + 1200 + 900 = 14950.00
Completed orders: 2 + 2 + 2 + 1 + 1 = 8
```

Validation was performed offline by parsing the existing seed file, resolving product prices and order statuses, calculating each completed order total, and aggregating by customer and month using decimal arithmetic. Five customers and eight completed orders reconcile to **14950.00** in both aggregations. The original calculations were validated offline without executing SQL. These are seed expectations; see the [validation guide](05_data_validation.md) for the project owner's subsequent manual SSMS verification.

All seeded customers have at least one completed order and distinct spending totals. The dataset therefore does not exercise customers without completed orders, empty completed orders, or spending ties; their behavior is defined by the LEFT JOINs, COALESCE expressions, and DENSE_RANK in the query.

## How to execute

1. In an authorized SQL Server client, connect to the instance containing the already prepared SalesAnalytics database.
2. Select `SalesAnalytics` as the active database.
3. Open `database/queries/03_customer_sales_analysis.sql` and execute the entire CTE and SELECT statement together.
4. For the supplied seed data, compare the returned customer metrics and verify that TotalSpent sums to 14950.00.

This is a read-only report. Do not rerun schema or seed scripts against populated tables to execute it.
