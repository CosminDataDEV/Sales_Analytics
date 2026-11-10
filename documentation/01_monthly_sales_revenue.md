# Monthly Sales Revenue

## Business purpose

Track monthly sales from completed orders to understand revenue trends and compare calendar months. The report returns one row per year and month with qualifying order items, sorted chronologically.

Query: [01_monthly_sales_revenue.sql](../database/queries/01_monthly_sales_revenue.sql).

## Source of truth

- [01_create_tables.sql](../database/schema/01_create_tables.sql) defines the table columns, types, and relationships.
- [02_seed_data.sql](../database/schema/02_seed_data.sql) supplies the synthetic demonstration dataset used for the expected results below.

The report joins `dbo.Orders` to `dbo.OrderItems` on `OrderID`. No customer or product join is required.

## Calculation and output

Filter orders to `Status = N'Completed'`, then calculate:

```text
Revenue = SUM(Quantity * UnitPrice)
```

Revenue uses the price stored on each order item, preserving the transaction price independently of future changes to the product catalog. Reporting periods use `Orders.OrderDate`, not customer creation dates or a completion timestamp.

| Column | Meaning | SQL Server result type |
| --- | --- | --- |
| SalesYear | Calendar year of the order date | INT |
| SalesMonth | Calendar month number, from 1 to 12 | INT |
| Revenue | Sum of qualifying order-line amounts | DECIMAL(38,2) |

The query explicitly casts `Quantity` to `DECIMAL(10,0)`, which accommodates the full `INT` range. Multiplying it by `UnitPrice DECIMAL(10,2)` produces `DECIMAL(21,2)`, and `SUM` returns `DECIMAL(38,2)`. This keeps exact decimal arithmetic and two fractional digits without using floating-point values or narrowing the aggregate.

## Exclusions and limitations

- Pending, Cancelled, and any other statuses that do not match Completed are excluded.
- Orders without order items contribute no revenue because the report uses an inner join.
- Months without qualifying items are omitted rather than returned as zero; an empty qualifying dataset returns no rows.
- No date restriction is applied: all qualifying years and months are included.
- The schema has no currency, tax, discount, refund, or payment fields. Results represent the defined order-line sales measure, not cash receipts or a financial accounting revenue-recognition calculation. Amounts are reported in RON by project convention; the schema has no currency column and the query performs no currency conversion.

## Expected results for the supplied seed data

| SalesYear | SalesMonth | Revenue |
| --- | --- | --- |
| 2026 | 1 | 4700.00 |
| 2026 | 2 | 2850.00 |
| 2026 | 3 | 5300.00 |
| 2026 | 4 | 1200.00 |
| 2026 | 5 | 900.00 |

### Reconciliation

| Month | Included order dates and line calculations | Revenue |
| --- | --- | --- |
| January | Jan 10: 1 x 3500 + 2 x 150; Jan 15: 1 x 900 | 4700.00 |
| February | Feb 03: 2 x 1200; Feb 14: 1 x 450 | 2850.00 |
| March | Mar 01: 1 x 1800; Mar 18: 1 x 3500 | 5300.00 |
| April | Apr 20: 1 x 1200 | 1200.00 |
| May | May 25: 2 x 450 | 900.00 |

Total included revenue is **14950.00**, representing **8 completed orders and 9 order items**. The Pending order dated April 5 contributes 450.00 (3 x 150) and is excluded. The Cancelled order dated May 12 contributes 900.00 (1 x 900) and is excluded. All seeded order items total 16300.00; subtracting 1350.00 of exclusions reconciles to 14950.00.

Validation was performed offline by parsing the existing seed file, resolving product prices and order statuses, and aggregating line amounts using decimal arithmetic. All five monthly totals matched the results above. The original expected-results calculation was performed offline without a SQL Server connection. The tables above present seed expectations; see the [validation guide](05_data_validation.md) for the project owner's subsequent manual SSMS verification.

## How to execute the report

1. Use an authorized SQL Server client, such as SQL Server Management Studio, to connect to an instance containing the already prepared `SalesAnalytics` database.
2. Select `SalesAnalytics` as the active database in the query window.
3. Open `database/queries/01_monthly_sales_revenue.sql` and execute the report query.
4. If the database contains exactly the supplied seed data, compare the five returned rows with the expected results above. Different underlying data can produce different results.

The query contains a single read-only `SELECT` statement. It does not create objects or insert, update, or delete data. Do not rerun the schema or seed scripts against a populated database to execute this report.
