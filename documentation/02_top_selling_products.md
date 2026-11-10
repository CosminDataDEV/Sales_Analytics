# Top-Selling Products

## Business purpose

Identify which products generate the most revenue from completed orders and compare their sales volumes. This report supports product assortment and sales performance reviews. Products are ranked by revenue, while UnitsSold provides a separate measure of demand; the ranking does not measure profit.

Query: [02_top_selling_products.sql](../database/queries/02_top_selling_products.sql).

## Sources and calculation

The source of truth is [01_create_tables.sql](../database/schema/01_create_tables.sql) for table definitions and [02_seed_data.sql](../database/schema/02_seed_data.sql) for the synthetic demonstration data.

The `ProductSales` CTE joins `dbo.Products` to `dbo.OrderItems` by `ProductID` and to `dbo.Orders` by `OrderID`. It filters to `Status = N'Completed'` before aggregating. Grouping includes ProductID, ProductName, and Category to preserve distinct products even if their descriptive attributes match.

| Output | Definition |
| --- | --- |
| ProductName | Product name from the catalog |
| Category | Product category from the catalog |
| UnitsSold | SUM of order-item Quantity, cast to BIGINT before aggregation |
| TotalRevenue | SUM of Quantity multiplied by the stored order-item UnitPrice |
| RevenueRank | DENSE_RANK over TotalRevenue descending |

`Quantity` is cast to `DECIMAL(10,0)` for revenue multiplication. With `UnitPrice DECIMAL(10,2)`, each line amount is `DECIMAL(21,2)` and the sum is `DECIMAL(38,2)`, retaining exact two-decimal arithmetic. Casting quantity to BIGINT separately for UnitsSold avoids the INT aggregate limit. RevenueRank is BIGINT.

Revenue uses the transaction price stored in OrderItems, independent of future changes to Products.Price. The outer query ranks the aggregated revenue and sorts by TotalRevenue descending, then ProductName ascending. Equal revenues share a rank without gaps; ProductName controls display order within a revenue tie and does not affect ranking. If both revenue and product name match, their relative display order is unspecified.

## Scope and exclusions

- Only Completed orders qualify; Pending, Cancelled, and other statuses are excluded.
- All order dates are included. There is no top-N restriction: all products with qualifying order items are returned.
- Inner joins omit products without completed-order items. A qualifying product with zero-priced items can still appear with zero revenue.
- The schema provides no currency, costs, taxes, discounts, refunds, or payment amounts. The measure represents order-line sales revenue, not profit or cash receipts, with amounts interpreted as RON by project convention. No currency column or conversion is implemented.

## Expected results

For exactly the supplied seed data, the report should return:

| ProductName | Category | UnitsSold | TotalRevenue | RevenueRank |
| --- | --- | --- | --- | --- |
| Laptop Lenovo | Computers | 2 | 7000.00 | 1 |
| Samsung Monitor | Monitors | 3 | 3600.00 | 2 |
| Standing Desk | Office Furniture | 1 | 1800.00 | 3 |
| Mechanical Keyboard | Accessories | 3 | 1350.00 | 4 |
| Office Chair | Office Furniture | 1 | 900.00 | 5 |
| Logitech Mouse | Accessories | 2 | 300.00 | 6 |

### Offline validation

The seed file was parsed locally to resolve product prices and categories, match order items to order statuses by customer email and date, and sum completed-order quantities and amounts using decimal arithmetic. The resulting totals and revenue ranks match the table above.

| Product | Included quantity calculation | Revenue calculation |
| --- | --- | --- |
| Laptop Lenovo | 1 + 1 = 2 | 2 x 3500 = 7000.00 |
| Samsung Monitor | 2 + 1 = 3 | 3 x 1200 = 3600.00 |
| Standing Desk | 1 | 1 x 1800 = 1800.00 |
| Mechanical Keyboard | 1 + 2 = 3 | 3 x 450 = 1350.00 |
| Office Chair | 1 | 1 x 900 = 900.00 |
| Logitech Mouse | 2 | 2 x 150 = 300.00 |

The report reconciles to **12 units and 14950.00 revenue** across **9 order items from 8 Completed orders**, matching the total of the monthly revenue report. The Pending order dated April 5 excludes 3 Logitech Mouse units worth 450.00; the Cancelled order dated May 12 excludes 1 Office Chair worth 900.00. All seeded items total 16 units and 16300.00; removing those exclusions gives the report totals.

All six revenue totals are distinct, so the seed dataset does not exercise tie behavior. The use of DENSE_RANK defines shared ranks for future revenue ties. The original calculations were validated offline without executing SQL. The table contains seed expectations; see the [validation guide](05_data_validation.md) for the project owner's subsequent manual SSMS verification.

## How to execute

1. In an authorized SQL Server client, connect to the instance containing the already prepared SalesAnalytics database.
2. Select `SalesAnalytics` as the active database.
3. Open `database/queries/02_top_selling_products.sql` and execute the complete CTE and SELECT statement together.
4. Compare the output with the expected results if the database contains exactly the supplied seed data.

The report is read-only and does not modify data or create objects. Do not rerun the schema or seed scripts against populated tables to run this report.
