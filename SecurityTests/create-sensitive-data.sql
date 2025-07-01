-- SQL Script to Create Test Data for Defender CSPM Sensitive Data Detection
-- This script creates normalized tables with realistic fake sensitive data
-- Purpose: Test Defender for Cloud's sensitive data classification capabilities

USE master;
GO

-- Create a test database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SensitiveDataTest')
BEGIN
    CREATE DATABASE SensitiveDataTest;
END
GO

USE SensitiveDataTest;
GO

-- ========================================
-- THIRD NORMAL FORM DESIGN
-- ========================================

-- 1. STATES TABLE (Reference table for normalization)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'States')
BEGIN
    CREATE TABLE States (
        StateID INT IDENTITY(1,1) PRIMARY KEY,
        StateCode CHAR(2) NOT NULL UNIQUE,
        StateName NVARCHAR(50) NOT NULL,
        CreatedDate DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- 2. CREDIT CARD TYPES TABLE (Reference table)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CreditCardTypes')
BEGIN
    CREATE TABLE CreditCardTypes (
        CardTypeID INT IDENTITY(1,1) PRIMARY KEY,
        CardTypeName NVARCHAR(20) NOT NULL UNIQUE,
        CardPattern NVARCHAR(20) NOT NULL, -- For reference only
        CreatedDate DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- 3. DEPARTMENTS TABLE (Reference table)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Departments')
BEGIN
    CREATE TABLE Departments (
        DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
        DepartmentName NVARCHAR(50) NOT NULL,
        DepartmentCode CHAR(4) NOT NULL UNIQUE,
        CreatedDate DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- 4. EMPLOYEES TABLE (Main entity)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Employees')
BEGIN
    CREATE TABLE Employees (
        EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        SSN CHAR(11) NOT NULL UNIQUE, -- Format: XXX-XX-XXXX
        DateOfBirth DATE NOT NULL,
        HireDate DATE NOT NULL,
        DepartmentID INT NOT NULL,
        Salary DECIMAL(10,2) NOT NULL,
        PhoneNumber NVARCHAR(15),
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME2 DEFAULT GETDATE(),
        ModifiedDate DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (DepartmentID) REFERENCES Departments(DepartmentID)
    );
END
GO

-- 5. USER PROFILES TABLE (Extended user information)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserProfiles')
BEGIN
    CREATE TABLE UserProfiles (
        ProfileID INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeID INT NOT NULL UNIQUE,
        DriversLicenseNumber NVARCHAR(20) NOT NULL,
        LicenseStateID INT NOT NULL,
        LicenseExpirationDate DATE NOT NULL,
        Address1 NVARCHAR(100) NOT NULL,
        Address2 NVARCHAR(100),
        City NVARCHAR(50) NOT NULL,
        StateID INT NOT NULL,
        ZipCode NVARCHAR(10) NOT NULL,
        EmergencyContactName NVARCHAR(100),
        EmergencyContactPhone NVARCHAR(15),
        CreatedDate DATETIME2 DEFAULT GETDATE(),
        ModifiedDate DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
        FOREIGN KEY (LicenseStateID) REFERENCES States(StateID),
        FOREIGN KEY (StateID) REFERENCES States(StateID)
    );
END
GO

-- 6. CREDIT CARD INFORMATION TABLE (Payment methods)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EmployeeCreditCards')
BEGIN
    CREATE TABLE EmployeeCreditCards (
        CreditCardID INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeID INT NOT NULL,
        CardTypeID INT NOT NULL,
        CardNumber NVARCHAR(19) NOT NULL, -- Format: XXXX-XXXX-XXXX-XXXX
        CardHolderName NVARCHAR(100) NOT NULL,
        ExpirationMonth TINYINT NOT NULL CHECK (ExpirationMonth BETWEEN 1 AND 12),
        ExpirationYear SMALLINT NOT NULL,
        CVV CHAR(4) NOT NULL, -- 3 digits for most cards, 4 for Amex
        BillingAddress1 NVARCHAR(100) NOT NULL,
        BillingAddress2 NVARCHAR(100),
        BillingCity NVARCHAR(50) NOT NULL,
        BillingStateID INT NOT NULL,
        BillingZipCode NVARCHAR(10) NOT NULL,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME2 DEFAULT GETDATE(),
        ModifiedDate DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
        FOREIGN KEY (CardTypeID) REFERENCES CreditCardTypes(CardTypeID),
        FOREIGN KEY (BillingStateID) REFERENCES States(StateID)
    );
END
GO

-- ========================================
-- INSERT REFERENCE DATA
-- ========================================

-- Insert US States
IF NOT EXISTS (SELECT * FROM States WHERE StateCode = 'AL')
BEGIN
    INSERT INTO States (StateCode, StateName) VALUES 
    ('AL', 'Alabama'), ('AK', 'Alaska'), ('AZ', 'Arizona'), ('AR', 'Arkansas'), ('CA', 'California'),
    ('CO', 'Colorado'), ('CT', 'Connecticut'), ('DE', 'Delaware'), ('FL', 'Florida'), ('GA', 'Georgia'),
    ('HI', 'Hawaii'), ('ID', 'Idaho'), ('IL', 'Illinois'), ('IN', 'Indiana'), ('IA', 'Iowa'),
    ('KS', 'Kansas'), ('KY', 'Kentucky'), ('LA', 'Louisiana'), ('ME', 'Maine'), ('MD', 'Maryland'),
    ('MA', 'Massachusetts'), ('MI', 'Michigan'), ('MN', 'Minnesota'), ('MS', 'Mississippi'), ('MO', 'Missouri'),
    ('MT', 'Montana'), ('NE', 'Nebraska'), ('NV', 'Nevada'), ('NH', 'New Hampshire'), ('NJ', 'New Jersey'),
    ('NM', 'New Mexico'), ('NY', 'New York'), ('NC', 'North Carolina'), ('ND', 'North Dakota'), ('OH', 'Ohio'),
    ('OK', 'Oklahoma'), ('OR', 'Oregon'), ('PA', 'Pennsylvania'), ('RI', 'Rhode Island'), ('SC', 'South Carolina'),
    ('SD', 'South Dakota'), ('TN', 'Tennessee'), ('TX', 'Texas'), ('UT', 'Utah'), ('VT', 'Vermont'),
    ('VA', 'Virginia'), ('WA', 'Washington'), ('WV', 'West Virginia'), ('WI', 'Wisconsin'), ('WY', 'Wyoming');
END
GO

-- Insert Credit Card Types
IF NOT EXISTS (SELECT * FROM CreditCardTypes WHERE CardTypeName = 'Visa')
BEGIN
    INSERT INTO CreditCardTypes (CardTypeName, CardPattern) VALUES
    ('Visa', '4XXX-XXXX-XXXX-XXXX'),
    ('MasterCard', '5XXX-XXXX-XXXX-XXXX'),
    ('American Express', '3XXX-XXXXXX-XXXXX'),
    ('Discover', '6XXX-XXXX-XXXX-XXXX'),
    ('JCB', '35XX-XXXX-XXXX-XXXX'),
    ('Diners Club', '30XX-XXXX-XXXX-XX');
END
GO

-- Insert Departments
IF NOT EXISTS (SELECT * FROM Departments WHERE DepartmentCode = 'IT')
BEGIN
    INSERT INTO Departments (DepartmentName, DepartmentCode) VALUES
    ('Information Technology', 'IT'),
    ('Human Resources', 'HR'),
    ('Finance', 'FIN'),
    ('Marketing', 'MKT'),
    ('Sales', 'SAL'),
    ('Operations', 'OPS'),
    ('Legal', 'LEG'),
    ('Research & Development', 'RND'),
    ('Customer Service', 'CS'),
    ('Security', 'SEC');
END
GO

-- ========================================
-- GENERATE REALISTIC FAKE DATA
-- ========================================

-- Function to generate realistic SSN (avoiding invalid ranges)
-- Note: These are fake SSNs following valid format patterns but are not real

DECLARE @EmployeeCounter INT = 1;
DECLARE @TotalEmployees INT = 95; -- Between 10-350 as requested

-- Generate Employee Records
WHILE @EmployeeCounter <= @TotalEmployees
BEGIN
    DECLARE @FirstName NVARCHAR(50);
    DECLARE @LastName NVARCHAR(50);
    DECLARE @SSN CHAR(11);
    DECLARE @Email NVARCHAR(100);
    DECLARE @DeptID INT;
    DECLARE @DOB DATE;
    DECLARE @HireDate DATE;
    DECLARE @Salary DECIMAL(10,2);
    DECLARE @Phone NVARCHAR(15);
    
    -- Generate realistic first names
    SELECT @FirstName = CASE (@EmployeeCounter % 20)
        WHEN 0 THEN 'John' WHEN 1 THEN 'Jane' WHEN 2 THEN 'Michael' WHEN 3 THEN 'Sarah'
        WHEN 4 THEN 'David' WHEN 5 THEN 'Lisa' WHEN 6 THEN 'Robert' WHEN 7 THEN 'Jennifer'
        WHEN 8 THEN 'William' WHEN 9 THEN 'Michelle' WHEN 10 THEN 'James' WHEN 11 THEN 'Emily'
        WHEN 12 THEN 'Christopher' WHEN 13 THEN 'Amanda' WHEN 14 THEN 'Daniel' WHEN 15 THEN 'Jessica'
        WHEN 16 THEN 'Matthew' WHEN 17 THEN 'Ashley' WHEN 18 THEN 'Anthony' WHEN 19 THEN 'Stephanie'
    END;
    
    -- Generate realistic last names
    SELECT @LastName = CASE (@EmployeeCounter % 25)
        WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams' WHEN 3 THEN 'Brown'
        WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia' WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis'
        WHEN 8 THEN 'Rodriguez' WHEN 9 THEN 'Martinez' WHEN 10 THEN 'Hernandez' WHEN 11 THEN 'Lopez'
        WHEN 12 THEN 'Gonzalez' WHEN 13 THEN 'Wilson' WHEN 14 THEN 'Anderson' WHEN 15 THEN 'Thomas'
        WHEN 16 THEN 'Taylor' WHEN 17 THEN 'Moore' WHEN 18 THEN 'Jackson' WHEN 19 THEN 'Martin'
        WHEN 20 THEN 'Lee' WHEN 21 THEN 'Perez' WHEN 22 THEN 'Thompson' WHEN 23 THEN 'White' WHEN 24 THEN 'Harris'
    END;
    
    -- Generate realistic SSN (avoiding invalid area numbers like 000, 666, 900-999)
    DECLARE @Area INT = 100 + (@EmployeeCounter % 665); -- Valid area numbers
    DECLARE @Group INT = 10 + (@EmployeeCounter % 89); -- Valid group numbers (01-99)
    DECLARE @Serial INT = 1000 + (@EmployeeCounter % 8999); -- Valid serial numbers (0001-9999)
    
    SET @SSN = FORMAT(@Area, '000') + '-' + FORMAT(@Group, '00') + '-' + FORMAT(@Serial, '0000');
    
    -- Generate email
    SET @Email = LOWER(@FirstName) + '.' + LOWER(@LastName) + '@company.com';
    
    -- Random department
    SET @DeptID = 1 + (@EmployeeCounter % 10);
    
    -- Random DOB (age 22-65)
    SET @DOB = DATEADD(YEAR, -22 - (@EmployeeCounter % 43), GETDATE());
    
    -- Random hire date (within last 10 years)
    SET @HireDate = DATEADD(DAY, -(@EmployeeCounter % 3650), GETDATE());
    
    -- Random salary ($35K - $150K)
    SET @Salary = 35000 + (@EmployeeCounter % 115000);
    
    -- Random phone number
    SET @Phone = '(' + FORMAT(200 + (@EmployeeCounter % 799), '000') + ') ' + 
                 FORMAT(200 + (@EmployeeCounter % 799), '000') + '-' + 
                 FORMAT(@EmployeeCounter % 9999, '0000');
    
    INSERT INTO Employees (FirstName, LastName, Email, SSN, DateOfBirth, HireDate, DepartmentID, Salary, PhoneNumber)
    VALUES (@FirstName, @LastName, @Email, @SSN, @DOB, @HireDate, @DeptID, @Salary, @Phone);
    
    SET @EmployeeCounter = @EmployeeCounter + 1;
END
GO

-- Generate User Profiles with Driver's License Information
DECLARE @ProfileCounter INT = 1;
DECLARE @MaxEmployeeID INT = (SELECT MAX(EmployeeID) FROM Employees);

WHILE @ProfileCounter <= @MaxEmployeeID
BEGIN
    DECLARE @LicenseNumber NVARCHAR(20);
    DECLARE @LicenseStateID INT;
    DECLARE @LicenseExp DATE;
    DECLARE @Addr1 NVARCHAR(100);
    DECLARE @City NVARCHAR(50);
    DECLARE @StateID INT;
    DECLARE @Zip NVARCHAR(10);
    DECLARE @EmergencyName NVARCHAR(100);
    DECLARE @EmergencyPhone NVARCHAR(15);
    
    -- Generate realistic driver's license number patterns by state
    SET @LicenseStateID = 1 + (@ProfileCounter % 50);
    
    -- Different license number patterns based on state
    SELECT @LicenseNumber = CASE (@LicenseStateID % 5)
        WHEN 0 THEN CHAR(65 + (@ProfileCounter % 26)) + FORMAT(@ProfileCounter + 1000000, '0000000') -- Letter + 7 digits
        WHEN 1 THEN FORMAT(@ProfileCounter + 10000000, '00000000') -- 8 digits
        WHEN 2 THEN CHAR(65 + (@ProfileCounter % 26)) + CHAR(65 + ((@ProfileCounter + 5) % 26)) + FORMAT(@ProfileCounter + 100000, '000000') -- 2 letters + 6 digits
        WHEN 3 THEN FORMAT(@ProfileCounter + 100000000, '000000000') -- 9 digits
        WHEN 4 THEN CHAR(65 + (@ProfileCounter % 26)) + FORMAT(@ProfileCounter + 10000000, '00000000') -- Letter + 8 digits
    END;
    
    -- License expiration (1-5 years from now)
    SET @LicenseExp = DATEADD(YEAR, 1 + (@ProfileCounter % 5), GETDATE());
    
    -- Generate address
    SET @Addr1 = FORMAT(@ProfileCounter * 10 + 100, '0000') + ' ' + 
                 CASE (@ProfileCounter % 10)
                     WHEN 0 THEN 'Main St' WHEN 1 THEN 'Oak Ave' WHEN 2 THEN 'First St'
                     WHEN 3 THEN 'Second Ave' WHEN 4 THEN 'Park Rd' WHEN 5 THEN 'Elm St'
                     WHEN 6 THEN 'Maple Ave' WHEN 7 THEN 'Cedar Ln' WHEN 8 THEN 'Pine St'
                     WHEN 9 THEN 'Washington Blvd'
                 END;
    
    SET @City = CASE (@ProfileCounter % 15)
        WHEN 0 THEN 'Springfield' WHEN 1 THEN 'Franklin' WHEN 2 THEN 'Georgetown'
        WHEN 3 THEN 'Madison' WHEN 4 THEN 'Clayton' WHEN 5 THEN 'Bristol'
        WHEN 6 THEN 'Fairview' WHEN 7 THEN 'Kingston' WHEN 8 THEN 'Riverside'
        WHEN 9 THEN 'Brookfield' WHEN 10 THEN 'Centerville' WHEN 11 THEN 'Greenwood'
        WHEN 12 THEN 'Highland' WHEN 13 THEN 'Midway' WHEN 14 THEN 'Oakwood'
    END;
    
    SET @StateID = 1 + (@ProfileCounter % 50);
    SET @Zip = FORMAT(10000 + (@ProfileCounter % 89999), '00000');
    
    -- Emergency contact
    SET @EmergencyName = CASE (@ProfileCounter % 5)
        WHEN 0 THEN 'Emergency Contact ' + CAST(@ProfileCounter AS NVARCHAR(10))
        WHEN 1 THEN 'Spouse Contact ' + CAST(@ProfileCounter AS NVARCHAR(10))
        WHEN 2 THEN 'Family Member ' + CAST(@ProfileCounter AS NVARCHAR(10))
        WHEN 3 THEN 'Parent Contact ' + CAST(@ProfileCounter AS NVARCHAR(10))
        WHEN 4 THEN 'Sibling Contact ' + CAST(@ProfileCounter AS NVARCHAR(10))
    END;
    
    SET @EmergencyPhone = '(' + FORMAT(200 + (@ProfileCounter % 799), '000') + ') ' + 
                         FORMAT(200 + (@ProfileCounter % 799), '000') + '-' + 
                         FORMAT((@ProfileCounter + 1000) % 9999, '0000');
    
    IF EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @ProfileCounter)
    BEGIN
        INSERT INTO UserProfiles (EmployeeID, DriversLicenseNumber, LicenseStateID, LicenseExpirationDate,
                                 Address1, City, StateID, ZipCode, EmergencyContactName, EmergencyContactPhone)
        VALUES (@ProfileCounter, @LicenseNumber, @LicenseStateID, @LicenseExp,
                @Addr1, @City, @StateID, @Zip, @EmergencyName, @EmergencyPhone);
    END
    
    SET @ProfileCounter = @ProfileCounter + 1;
END
GO

-- Generate Credit Card Information
DECLARE @CCCounter INT = 1;
DECLARE @MaxEmpID INT = (SELECT MAX(EmployeeID) FROM Employees);

-- Generate 1-3 credit cards per employee
WHILE @CCCounter <= @MaxEmpID
BEGIN
    DECLARE @CardsForEmployee INT = 1 + (@CCCounter % 3); -- 1-3 cards per employee
    DECLARE @CardNum INT = 1;
    
    WHILE @CardNum <= @CardsForEmployee
    BEGIN
        DECLARE @CardTypeID INT;
        DECLARE @CardNumber NVARCHAR(19);
        DECLARE @CardHolderName NVARCHAR(100);
        DECLARE @ExpMonth TINYINT;
        DECLARE @ExpYear SMALLINT;
        DECLARE @CVV CHAR(4);
        DECLARE @BillAddr1 NVARCHAR(100);
        DECLARE @BillCity NVARCHAR(50);
        DECLARE @BillStateID INT;
        DECLARE @BillZip NVARCHAR(10);
        
        -- Random card type
        SET @CardTypeID = 1 + ((@CCCounter + @CardNum) % 6);
        
        -- Generate realistic card numbers based on type
        SELECT @CardNumber = CASE @CardTypeID
            WHEN 1 THEN '4' + FORMAT(ABS(CHECKSUM(NEWID())) % 1000, '000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') -- Visa
            WHEN 2 THEN '5' + FORMAT(ABS(CHECKSUM(NEWID())) % 1000, '000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') -- MasterCard
            WHEN 3 THEN '34' + FORMAT(ABS(CHECKSUM(NEWID())) % 100, '00') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 1000000, '000000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 100000, '00000') -- Amex
            WHEN 4 THEN '6011-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') -- Discover
            WHEN 5 THEN '35' + FORMAT(ABS(CHECKSUM(NEWID())) % 100, '00') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') -- JCB
            WHEN 6 THEN '30' + FORMAT(ABS(CHECKSUM(NEWID())) % 100, '00') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000') + '-' + 
                       FORMAT(ABS(CHECKSUM(NEWID())) % 100, '00') -- Diners Club
        END;
        
        -- Get cardholder name from employee
        SELECT @CardHolderName = FirstName + ' ' + LastName 
        FROM Employees WHERE EmployeeID = @CCCounter;
        
        -- Random expiration (1-5 years from now)
        SET @ExpMonth = 1 + (@CCCounter % 12);
        SET @ExpYear = YEAR(GETDATE()) + 1 + (@CCCounter % 5);
        
        -- CVV based on card type (Amex = 4 digits, others = 3 digits)
        SET @CVV = CASE WHEN @CardTypeID = 3 
                   THEN FORMAT(ABS(CHECKSUM(NEWID())) % 10000, '0000')
                   ELSE FORMAT(ABS(CHECKSUM(NEWID())) % 1000, '000')
                   END;
        
        -- Billing address (often same as employee address)
        SET @BillAddr1 = FORMAT((@CCCounter + @CardNum) * 10 + 200, '0000') + ' ' + 
                        CASE ((@CCCounter + @CardNum) % 8)
                            WHEN 0 THEN 'Billing St' WHEN 1 THEN 'Payment Ave' WHEN 2 THEN 'Card Ln'
                            WHEN 3 THEN 'Credit Rd' WHEN 4 THEN 'Finance Blvd' WHEN 5 THEN 'Money St'
                            WHEN 6 THEN 'Bank Ave' WHEN 7 THEN 'Account Dr'
                        END;
        
        SET @BillCity = CASE ((@CCCounter + @CardNum) % 12)
            WHEN 0 THEN 'Creditville' WHEN 1 THEN 'Paymentburg' WHEN 2 THEN 'Cardton'
            WHEN 3 THEN 'Financefield' WHEN 4 THEN 'Bankstown' WHEN 5 THEN 'Moneyville'
            WHEN 6 THEN 'Accountburg' WHEN 7 THEN 'Billingham' WHEN 8 THEN 'Chargeton'
            WHEN 9 THEN 'Debitville' WHEN 10 THEN 'Transactionburg' WHEN 11 THEN 'Purchaseville'
        END;
        
        SET @BillStateID = 1 + ((@CCCounter + @CardNum) % 50);
        SET @BillZip = FORMAT(20000 + ((@CCCounter + @CardNum) % 79999), '00000');
        
        IF EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @CCCounter)
        BEGIN
            INSERT INTO EmployeeCreditCards (EmployeeID, CardTypeID, CardNumber, CardHolderName,
                                           ExpirationMonth, ExpirationYear, CVV, BillingAddress1,
                                           BillingCity, BillingStateID, BillingZipCode)
            VALUES (@CCCounter, @CardTypeID, @CardNumber, @CardHolderName,
                    @ExpMonth, @ExpYear, @CVV, @BillAddr1,
                    @BillCity, @BillStateID, @BillZip);
        END
        
        SET @CardNum = @CardNum + 1;
    END
    
    SET @CCCounter = @CCCounter + 1;
END
GO

-- ========================================
-- CREATE VIEWS FOR EASIER DATA ACCESS
-- ========================================

-- Comprehensive Employee View
CREATE OR ALTER VIEW vw_EmployeeDetails AS
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.Email,
    e.SSN,
    e.DateOfBirth,
    e.HireDate,
    d.DepartmentName,
    e.Salary,
    e.PhoneNumber,
    up.DriversLicenseNumber,
    ls.StateName AS LicenseState,
    up.LicenseExpirationDate,
    up.Address1,
    up.City,
    s.StateName AS State,
    up.ZipCode,
    up.EmergencyContactName,
    up.EmergencyContactPhone
FROM Employees e
    INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
    LEFT JOIN UserProfiles up ON e.EmployeeID = up.EmployeeID
    LEFT JOIN States s ON up.StateID = s.StateID
    LEFT JOIN States ls ON up.LicenseStateID = ls.StateID
WHERE e.IsActive = 1;
GO

-- Credit Card Summary View
CREATE OR ALTER VIEW vw_CreditCardSummary AS
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    cct.CardTypeName,
    cc.CardNumber,
    cc.CardHolderName,
    cc.ExpirationMonth,
    cc.ExpirationYear,
    cc.CVV,
    cc.BillingAddress1,
    cc.BillingCity,
    s.StateName AS BillingState,
    cc.BillingZipCode,
    cc.IsActive
FROM EmployeeCreditCards cc
    INNER JOIN Employees e ON cc.EmployeeID = e.EmployeeID
    INNER JOIN CreditCardTypes cct ON cc.CardTypeID = cct.CardTypeID
    INNER JOIN States s ON cc.BillingStateID = s.StateID
WHERE cc.IsActive = 1;
GO

-- ========================================
-- DATA VERIFICATION QUERIES
-- ========================================

-- Check record counts
SELECT 'Employees' AS TableName, COUNT(*) AS RecordCount FROM Employees
UNION ALL
SELECT 'UserProfiles' AS TableName, COUNT(*) AS RecordCount FROM UserProfiles
UNION ALL
SELECT 'EmployeeCreditCards' AS TableName, COUNT(*) AS RecordCount FROM EmployeeCreditCards
UNION ALL
SELECT 'States' AS TableName, COUNT(*) AS RecordCount FROM States
UNION ALL
SELECT 'CreditCardTypes' AS TableName, COUNT(*) AS RecordCount FROM CreditCardTypes
UNION ALL
SELECT 'Departments' AS TableName, COUNT(*) AS RecordCount FROM Departments;

-- Sample sensitive data verification
SELECT TOP 5 
    'SSN Sample' AS DataType,
    SSN AS SampleValue
FROM Employees
UNION ALL
SELECT TOP 5
    'Credit Card Sample' AS DataType,
    CardNumber AS SampleValue
FROM EmployeeCreditCards
UNION ALL
SELECT TOP 5
    'Driver License Sample' AS DataType,
    DriversLicenseNumber AS SampleValue
FROM UserProfiles;

PRINT 'Test database and tables created successfully!';
PRINT 'This data is designed to trigger Defender CSPM sensitive data detection.';
PRINT 'Tables follow Third Normal Form with realistic fake sensitive data patterns.';
PRINT 'Monitor Defender for Cloud for data classification alerts.';

GO
