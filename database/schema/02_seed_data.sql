
USE [SalesAnalytics];
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Fail before inserting if any target table already contains data.
    IF EXISTS (SELECT 1 FROM dbo.Customers)
        OR EXISTS (SELECT 1 FROM dbo.Products)
        OR EXISTS (SELECT 1 FROM dbo.Orders)
        OR EXISTS (SELECT 1 FROM dbo.OrderItems)
    BEGIN
        THROW 50001, 'Seed aborted: all four SalesAnalytics tables must be empty.', 1;
    END;

    INSERT INTO dbo.Customers (FullName, Email)
    VALUES
        (N'Andrei Popescu', N'andrei.popescu@example.com'),
        (N'Maria Ionescu', N'maria.ionescu@example.com'),
        (N'Alex Dumitrescu', N'alex.dumitrescu@example.com'),
        (N'Ioana Georgescu', N'ioana.georgescu@example.com'),
        (N'Mihai Stan', N'mihai.stan@example.com');

    INSERT INTO dbo.Products (ProductName, Category, Price)
    VALUES
        (N'Laptop Lenovo', N'Computers', 3500.00),
        (N'Samsung Monitor', N'Monitors', 1200.00),
        (N'Logitech Mouse', N'Accessories', 150.00),
        (N'Mechanical Keyboard', N'Accessories', 450.00),
        (N'Office Chair', N'Office Furniture', 900.00),
        (N'Standing Desk', N'Office Furniture', 1800.00);

    -- Chronological customer assignment cycles through the five customers twice.
    INSERT INTO dbo.Orders (CustomerID, OrderDate, Status)
    SELECT c.CustomerID, CONVERT(DATETIME2, s.OrderDate, 112), s.Status
    FROM (VALUES
        (N'andrei.popescu@example.com', '20260110', N'Completed'),
        (N'maria.ionescu@example.com', '20260115', N'Completed'),
        (N'alex.dumitrescu@example.com', '20260203', N'Completed'),
        (N'ioana.georgescu@example.com', '20260214', N'Completed'),
        (N'mihai.stan@example.com', '20260301', N'Completed'),
        (N'andrei.popescu@example.com', '20260318', N'Completed'),
        (N'maria.ionescu@example.com', '20260405', N'Pending'),
        (N'alex.dumitrescu@example.com', '20260420', N'Completed'),
        (N'ioana.georgescu@example.com', '20260512', N'Cancelled'),
        (N'mihai.stan@example.com', '20260525', N'Completed')
    ) AS s (Email, OrderDate, Status)
    INNER JOIN dbo.Customers AS c ON c.Email = s.Email;

    -- Store the current product price explicitly as the order-line UnitPrice.
    -- No identity values are assumed for customers, products, or orders.
    INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
    SELECT o.OrderID, p.ProductID, s.Quantity, p.Price
    FROM (VALUES
        (N'andrei.popescu@example.com', '20260110', N'Laptop Lenovo', 1),
        (N'andrei.popescu@example.com', '20260110', N'Logitech Mouse', 2),
        (N'maria.ionescu@example.com', '20260115', N'Office Chair', 1),
        (N'alex.dumitrescu@example.com', '20260203', N'Samsung Monitor', 2),
        (N'ioana.georgescu@example.com', '20260214', N'Mechanical Keyboard', 1),
        (N'mihai.stan@example.com', '20260301', N'Standing Desk', 1),
        (N'andrei.popescu@example.com', '20260318', N'Laptop Lenovo', 1),
        (N'maria.ionescu@example.com', '20260405', N'Logitech Mouse', 3),
        (N'alex.dumitrescu@example.com', '20260420', N'Samsung Monitor', 1),
        (N'ioana.georgescu@example.com', '20260512', N'Office Chair', 1),
        (N'mihai.stan@example.com', '20260525', N'Mechanical Keyboard', 2)
    ) AS s (Email, OrderDate, ProductName, Quantity)
    INNER JOIN dbo.Customers AS c ON c.Email = s.Email
    INNER JOIN dbo.Orders AS o
        ON o.CustomerID = c.CustomerID
        AND o.OrderDate = CONVERT(DATETIME2, s.OrderDate, 112)
    INNER JOIN dbo.Products AS p ON p.ProductName = s.ProductName;

    -- Roll back rather than commit an incomplete or unexpectedly multiplied seed.
    IF (SELECT COUNT(*) FROM dbo.Customers) <> 5
        OR (SELECT COUNT(*) FROM dbo.Products) <> 6
        OR (SELECT COUNT(*) FROM dbo.Orders) <> 10
        OR (SELECT COUNT(*) FROM dbo.OrderItems) <> 11
    BEGIN
        THROW 50002, 'Seed aborted: inserted row counts do not match the expected dataset.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
