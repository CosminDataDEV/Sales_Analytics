# Sales Data Validation

## Purpose and scope

[01_validate_sales_data.sql](../database/tests/01_validate_sales_data.sql) provides repeatable, read-only checks of seed-data expectations, analytical revenue reconciliation, and referential and numeric integrity for SalesAnalytics on SQL Server 2025.

**Fixed counts and amounts apply only to the supplied synthetic seed dataset.** Legitimate changes to the data can fail those expectations without indicating database corruption. Reconciliation and integrity checks remain useful beyond that dataset.

Sources of truth:

- [Schema](../database/schema/01_create_tables.sql)
- [Synthetic seed data](../database/schema/02_seed_data.sql)
- [Monthly revenue query](../database/queries/01_monthly_sales_revenue.sql)
- [Product sales query](../database/queries/02_top_selling_products.sql)
- [Customer sales query](../database/queries/03_customer_sales_analysis.sql)
- [Average order value query](../database/queries/04_average_order_value.sql)

## Validation catalog

Each test returns TestName, ExpectedResult, ActualResult, and Status (PASS or FAIL). Numeric comparisons use exact DECIMAL values, not formatted strings or tolerances. Counts display with two decimal places because results share a common numeric representation.

| Test | Purpose | Expected result for supplied seed |
| --- | --- | --- |
| 1. Customer count | Detect missing or extra customers | 5.00 |
| 2. Product count | Detect missing or extra products | 6.00 |
| 3. Order count | Detect missing or extra orders, across all statuses | 10.00 |
| 4. Order item count | Detect missing or extra order lines | 11.00 |
| 5. Completed order count | Confirm the report denominator | 8.00 |
| 6. Completed revenue | Confirm completed-order sales amount | 14950.00 |
| 7. Average order value | Confirm rounded revenue per completed order | 1868.75 |
| 8. Monthly reconciliation | Sum monthly completed revenue and compare with computed total revenue | 14950.00 |
| 9. Product reconciliation | Sum product completed revenue and compare with computed total revenue | 14950.00 |
| 10. Customer reconciliation | Sum customer completed revenue and compare with computed total revenue | 14950.00 |
| 11. Orders without a customer | Detect missing parent Customers records | 0.00 |
| 12. Items without an order | Detect missing parent Orders records | 0.00 |
| 13. Items without a product | Detect missing parent Products records | 0.00 |
| 14. Invalid quantities | Detect Quantity <= 0 or NULL | 0.00 |
| 15. Invalid unit prices | Detect UnitPrice < 0 or NULL | 0.00 |
| 16. Invalid product prices | Detect Price < 0 or NULL | 0.00 |

The nine validation areas are split into 16 detail tests so failures identify the affected table, relationship, or field. The final SUMMARY row reports passed, failed, and total tests, with overall PASS only when every detail test passes. Expected seed output contains **17 rows: 16 PASS detail rows and one PASS summary**, with `Passed: 16; Failed: 0; Total: 16`.

## Manual verification record

The project owner's manually verified SSMS run recorded **16 passed, 0 failed**, with summary `Passed: 16; Failed: 0; Total: 16`. The AOV result supplied from SSMS also shows 8 completed orders, 14950.00 revenue, and 1868.75 AOV. Amounts use RON as the project reporting convention; the schema stores no currency field. This record is based on the owner's manual verification, not a new automated database run. No test-output artifact is bundled with this documentation.

## Calculation and assumptions

CompletedOrderTotals produces one row per Completed order using a LEFT JOIN to OrderItems. Each line amount is Quantity multiplied by its stored UnitPrice. Itemless Completed orders have zero value and still count in the AOV denominator. Pending and Cancelled orders are excluded from revenue and completed-order count.

Quantity is cast to DECIMAL(10,0), giving DECIMAL(21,2) products with UnitPrice DECIMAL(10,2); SUM returns DECIMAL(38,2). AOV uses exact decimal division, ROUND to two decimal places, and a final DECIMAL(38,2) cast. NULLIF prevents division by zero, and COALESCE reports zero revenue and AOV for no completed orders. Fixed seed checks then fail appropriately on an empty database, even though reconciliation totals can all be zero and pass.

Monthly, product, and customer CTEs reproduce the aggregation logic and joins in the analytical reports. Monthly totals use order year/month; product totals preserve ProductID; customer totals retain all customers. Reconciliation compares each dimension total against the computed completed-order total, independently of the fixed 14950.00 seed expectation.

Orphan and invalid-value checks inspect all rows, regardless of order status. The supplied foreign keys, CHECK constraints, and NOT NULL constraints normally prevent these errors. Explicit checks are still useful when reviewing imported data or databases whose constraints may have been disabled. An item missing both an order and a product is counted in both relationship tests.

## Expected reconciliation

```text
Completed orders = 8
Completed revenue = 14950.00
AOV = ROUND(14950.00 / 8, 2) = 1868.75

Monthly:  4700 + 2850 + 5300 + 1200 + 900 = 14950.00
Products: 7000 + 3600 + 1800 + 1350 + 900 + 300 = 14950.00
Customers: 7300 + 3600 + 2700 + 900 + 450 = 14950.00
```

These expectations follow the supplied seed file and the existing report reconciliations. The Pending order contributes 450.00 and the Cancelled order 900.00; both are excluded from completed revenue. The project owner reports manually verified SSMS results of **16 checks passed and 0 failed** on the supplied synthetic dataset. This documents the manual run; no SQL was executed during the portfolio documentation update.

## How to run

1. In an authorized SQL Server client, connect to the instance containing the already prepared SalesAnalytics database.
2. Select `SalesAnalytics` as the active database. All four tables must already exist; missing tables or insufficient SELECT permissions produce SQL errors rather than PASS/FAIL rows.
3. Open `database/tests/01_validate_sales_data.sql` and execute the entire statement, including all CTEs and the final SELECT.
4. Review any FAIL rows and compare ExpectedResult with ActualResult. Check the final summary for passed and failed counts.
5. For the unchanged supplied seed data, expect 16 passed tests and zero failed tests.

The script consists of a single read-only CTE/SELECT statement. It creates no persistent objects, temporary tables, or table variables and performs no inserts, updates, deletes, or schema changes. It can be rerun without changing data. Do not rerun schema or seed scripts against populated tables to run validation.

Run against stable data when comparing totals. The script does not change transaction isolation or lock settings; concurrent writes under the session's isolation level can affect consistency. It returns diagnostic results rather than raising an error for failed tests; automated consumers must inspect Status or the summary.

## Limits

These checks validate counts, aggregate metrics, reconciliation, and the listed integrity rules. They do not prove every seeded name, date, category, status, rank, or individual value matches the seed, nor do they test the report files by executing them dynamically. Coordinated changes can preserve totals while altering underlying details. The suite does not change data to simulate invalid or edge-case records.
