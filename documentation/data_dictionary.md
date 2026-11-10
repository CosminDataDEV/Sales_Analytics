# Data Dictionary

## Scope and conventions

This dictionary follows [01_create_tables.sql](../database/schema/01_create_tables.sql), the repository's actual DDL definitions for SQL Server 2025. It documents the scripts rather than a live database inspection. All tables belong to dbo in SalesAnalytics. All columns are NOT NULL, including primary keys (implicitly non-nullable).

Amounts use DECIMAL(10,2). RON is the portfolio reporting convention; no currency column or currency conversion is implemented. DATETIME2 without an explicit scale means DATETIME2(7); values have no time-zone offset. SYSDATETIME() defaults use the SQL Server host's clock when a value is omitted.

## dbo.Customers

Grain: one customer. Supplied seed rows: 5.

| Column | SQL definition | Nullable | Default / generation | Key or rule | Meaning |
| --- | --- | --- | --- | --- | --- |
| CustomerID | INT | No | IDENTITY(1,1) | Primary key | Customer identifier |
| FullName | NVARCHAR(100) | No | None | None | Customer display name |
| Email | NVARCHAR(150) | No | None | UNIQUE | Customer email; stable lookup key in seed |
| CreatedAt | DATETIME2(7) | No | SYSDATETIME() | None | Record creation timestamp |

Email uniqueness follows the database collation; the schema does not validate email syntax. FullName is not unique.

## dbo.Products

Grain: one catalog product. Supplied seed rows: 6.

| Column | SQL definition | Nullable | Default / generation | Key or rule | Meaning |
| --- | --- | --- | --- | --- | --- |
| ProductID | INT | No | IDENTITY(1,1) | Primary key | Product identifier |
| ProductName | NVARCHAR(150) | No | None | None | Catalog product name |
| Category | NVARCHAR(100) | No | None | None | Product category label |
| Price | DECIMAL(10,2) | No | None | CK_Products_Price: Price >= 0 | Current catalog price in RON by convention |

ProductName is not schema-enforced unique. The seed uses distinct product names for lookups, and its categories are demonstration labels. Category has no separate reference table or controlled vocabulary constraint.

## dbo.Orders

Grain: one order belonging to one customer. Supplied seed rows: 10.

| Column | SQL definition | Nullable | Default / generation | Key or rule | Meaning |
| --- | --- | --- | --- | --- | --- |
| OrderID | INT | No | IDENTITY(1,1) | Primary key | Order identifier |
| CustomerID | INT | No | None | FK_Orders_Customers | Parent customer |
| OrderDate | DATETIME2(7) | No | SYSDATETIME() | None | Order timestamp; monthly reporting basis |
| Status | NVARCHAR(30) | No | 'Pending' | None | Order status; only Completed qualifies for analytics |

Completed, Pending, and Cancelled are seed values, not an enforced enumeration. No CHECK restricts Status to those values. CustomerID plus OrderDate is distinct in this seed but is not a unique key enforced by the schema. An order may have zero items.

## dbo.OrderItems

Grain: one line within one order. Supplied seed rows: 11.

| Column | SQL definition | Nullable | Default / generation | Key or rule | Meaning |
| --- | --- | --- | --- | --- | --- |
| OrderItemID | INT | No | IDENTITY(1,1) | Primary key | Order-line identifier |
| OrderID | INT | No | None | FK_OrderItems_Orders | Parent order |
| ProductID | INT | No | None | FK_OrderItems_Products | Referenced catalog product |
| Quantity | INT | No | None | CK_OrderItems_Quantity: Quantity > 0 | Units on this line |
| UnitPrice | DECIMAL(10,2) | No | None | CK_OrderItems_UnitPrice: UnitPrice >= 0 | Stored transaction unit price in RON by convention |

UnitPrice is stored independently of Products.Price. The seed copies the catalog price at insertion time; the schema does not enforce ongoing equality. The same product can appear on multiple lines of an order because no unique constraint covers (OrderID, ProductID).

## Relationships and constraint behavior

| Foreign key | Child column | Parent column | Cardinality |
| --- | --- | --- | --- |
| FK_Orders_Customers | dbo.Orders.CustomerID | dbo.Customers.CustomerID | One customer to zero or many orders |
| FK_OrderItems_Orders | dbo.OrderItems.OrderID | dbo.Orders.OrderID | One order to zero or many items |
| FK_OrderItems_Products | dbo.OrderItems.ProductID | dbo.Products.ProductID | One product to zero or many items |

All child references are required. No cascading actions are declared, so SQL Server uses NO ACTION for updates and deletes of referenced keys. Primary key, Email UNIQUE, and default constraints are declared without explicit names; SQL Server assigns their constraint names. Only foreign key and CHECK constraints are explicitly named in the DDL. No additional indexes are explicitly defined beyond those associated with primary/unique constraints.

## Derived analytical measures

| Measure | Definition |
| --- | --- |
| Line revenue | Quantity x stored UnitPrice |
| Completed-order total | Sum of line revenue for an order with Status = Completed; zero if itemless |
| Total completed revenue | Sum of completed-order totals |
| Units sold | Sum of quantities on completed-order items |
| Average order value | Completed revenue / completed orders, rounded to two decimals; zero for no completed orders |
| Revenue/customer rank | DENSE_RANK by revenue/spending descending |

Queries widen Quantity to an exact decimal before revenue multiplication and aggregate to DECIMAL(38,2). Order-level aggregation prevents multi-line orders from inflating order counts. Customer analysis retains all customers; monthly and product reports include qualifying items only.

The supplied dataset produces 8 completed orders, 14,950.00 RON revenue, and 1,868.75 RON AOV. See the [validation guide](05_data_validation.md) for reconciliation and integrity checks. Costs, profit, refunds, discounts, tax, payment settlement, and currency conversion are outside the model.
