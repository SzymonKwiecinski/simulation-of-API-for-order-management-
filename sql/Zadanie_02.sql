/*
Zadanie 02
Szymon Kwieciński nr. indeksu: 324159


-- Podpunkt 1,2,3,
1. Wszystkie tabele oraz relacje wraz z kluczami modelu implementacyjnego
z poprzedniego zadania. Uwaga: osoby, które nie otrzymały 25pkt za
Zadanie 01 powinny poprawić model i jego implementację bazując na otrzymanym
komentarzu do przesłanego modelu. W materiałach umieszczone zostały również
przykładowe rozwiązania Zadania 01.
2. Określenie obowiązkowych wartości we wszystkich kolumnach
(NULL lub NOT NULL)
3. Co najmniej jedno ograniczenie typu UNIQUE
(np. na kolumnie Order ID reprezentującej wartość biznesową zamówienia)
oraz co najmniej dwa ograniczenia CHECK
(np. brak możliwości wprowadzenia zamówienia z wartością ujemną
w kolumnie Quantity)
*/
CREATE DATABASE OrderDB;
GO
USE OrderDB;

CREATE TABLE categories(
    id SMALLINT PRIMARY KEY IDENTITY,
    category VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE sub_categories (
    id SMALLINT PRIMARY KEY IDENTITY,
    sub_category VARCHAR(50) NOT NULL UNIQUE,
    category_id SMALLINT NOT NULL,
    CONSTRAINT FK_sub_categories_categories FOREIGN KEY (category_id) REFERENCES categories (id)
);

CREATE TABLE products (
    id INTEGER PRIMARY KEY IDENTITY,
    name VARCHAR(255) NOT NULL UNIQUE,
    sub_category_id SMALLINT NOT NULL,
    CONSTRAINT FK_products_sub_categories FOREIGN KEY (sub_category_id) REFERENCES sub_categories (id)
);

-- positions
CREATE TABLE positions (
    id BIGINT PRIMARY KEY IDENTITY,
    product_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    sales SMALLMONEY NOT NULL,
    quantity SMALLINT NOT NULL,
    discount NUMERIC(5,2) NOT NULL,
    profit SMALLMONEY NOT NULL,
    shipping_cost NUMERIC(8,3) NOT NULL,
    CONSTRAINT FK_positions_products FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT CHK_sales CHECK (sales > 0),
    CONSTRAINT CHK_quantity CHECK (quantity > 0),
    CONSTRAINT CHK_discount CHECK (discount >= 0),
    CONSTRAINT CHK_shipping_cost CHECK (shipping_cost >= 0)
    -- order_id constraint as ALTER TABLE below 
);

-- customers 
CREATE TABLE segments (
    id INTEGER PRIMARY KEY IDENTITY,
    segment VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE customers (
    id INTEGER PRIMARY KEY IDENTITY,
    name VARCHAR(100) NOT NULL,
    segment_id INTEGER NOT NULL,
    CONSTRAINT FK_customers_segments FOREIGN KEY (segment_id) REFERENCES segments(id) 
);

-- ship_addresses
CREATE TABLE markets (
    id TINYINT PRIMARY KEY IDENTITY,
    market VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE countries (
    id TINYINT PRIMARY KEY IDENTITY,
    country VARCHAR(100) UNIQUE NOT NULL,
    market_id TINYINT NOT NULL,
    CONSTRAINT FK_countries_markets FOREIGN KEY (market_id) REFERENCES markets(id)
);

CREATE TABLE states (
    id SMALLINT PRIMARY KEY IDENTITY,
    state VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE cities (
    id SMALLINT PRIMARY KEY IDENTITY,
    city VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE ship_addresses (
    id INTEGER PRIMARY KEY IDENTITY,
    city_id SMALLINT NOT NULL,
    state_id SMALLINT NOT NULL,
    country_id TINYINT NOT NULL,
    postal_code CHAR(6),
    CONSTRAINT FK_ship_addresses_cities FOREIGN KEY (city_id) REFERENCES cities(id),
    CONSTRAINT FK_ship_addresses_states FOREIGN KEY (state_id) REFERENCES states(id),
    CONSTRAINT FK_ship_addresses_countries FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT CHK_postal_code CHECK (LEN(postal_code) = 5 OR postal_code is NULL)
);

-- ship_mode
CREATE TABLE ship_modes (
    id TINYINT PRIMARY KEY IDENTITY,
    ship_mode VARCHAR(50) UNIQUE NOT NULL
);

-- orders

CREATE TABLE orders (
    id INTEGER PRIMARY KEY IDENTITY,
    customer_id INTEGER NOT NULL,
    ship_address_id INTEGER NOT NULL,
    ship_mode_id TINYINT NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE,
    CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(id),
    CONSTRAINT FK_orders_ship_addresses FOREIGN KEY (ship_address_id) REFERENCES ship_addresses(id),
    CONSTRAINT FK_orders_ship_modes FOREIGN KEY (ship_mode_id) REFERENCES ship_modes(id),
    CONSTRAINT CHK_date CHECK (order_date <= ship_date)
);

ALTER TABLE positions 
ADD CONSTRAINT FK_positions_orders FOREIGN KEY (order_id) REFERENCES orders(id);

GO

-----------------------------
/*
Podpunkt 4 
4. Implementację procedury (procedur) i/lub funkcji, która umożliwi 
wprowadzenie zamówienia  dla danego klienta, na co najmniej dwa różne 
produkty w ramach konkretnego rynku. Ponadto, należy użyć jawnej transakcji 
w kodzie do obsługi tej logiki wstawiającej zamówienie do bazy danych OrderDB.
Uwaga: niniejsza logika procedury (funkcji) ma realizować możliwość 
wprowadzenia kompletnego zamówienia do bazy danych OrderDB tj. ma dawać 
sposobność wprowadzenia danych do wszystkich zainteresowanych tabel bazy
danych OrderDB tj. kategorie, podkategorie, produkty, rynki, klienci,
zamówienia itp.
*/

DROP PROCEDURE IF EXISTS SelectAddProduct;
GO

/*
Zwraca id produkty jeżeli produkt istnieje,
jeżeli produkt nie istnieje to go tworzy. 
Dla błednych sub_categoty i category zwraca błąd
*/
CREATE PROCEDURE [SelectAddProduct]
    @product VARCHAR(255),
    @sub_category VARCHAR(50),
    @category VARCHAR(50),
    @product_id INT OUTPUT
AS
    DECLARE @sub_category_id INTEGER;
    DECLARE @category_id INTEGER;
    DECLARE @flag AS SMALLINT;
    DECLARE @OutputTbl TABLE (id INT);


    SELECT @product_id = id
    FROM OrderDB.dbo.products
    WHERE name = @product;  
    
    SELECT @category_id = id
    FROM OrderDB.dbo.categories
    WHERE category = @category;

    SELECT @sub_category_id = id
    FROM OrderDB.dbo.sub_categories
    WHERE sub_category = @sub_category;  
    

    IF ((@product_id IS NOT NULL)) -- produkt instnieje
        BEGIN
            SET @flag = NULL;

            SELECT @flag = pro.id
            FROM OrderDB.dbo.products as pro
            LEFT JOIN OrderDB.dbo.sub_categories as sub
                ON pro.sub_category_id = sub.id 
            LEFT JOIN OrderDB.dbo.categories as cat
                ON sub.category_id = cat.id
            WHERE
                cat.category = @category
                AND sub.sub_category = @sub_category;

            IF @flag IS NULL
                BEGIN
                    SET @product_id = NULL
                    RAISERROR('Blad 2!!',1,1);
                END
            ELSE
                BEGIN
                    SET @product_id = @flag;
                END
        END

    IF ((@product_id IS NULL) AND (@sub_category_id IS NOT NULL) ) -- subkategoria istnieje
        BEGIN
            SET @flag = NULL;

            SELECT @flag = sub.id
            FROM OrderDB.dbo.sub_categories as sub
            LEFT JOIN OrderDB.dbo.categories as cat
                ON sub.category_id = cat.id
            WHERE
                cat.category = @category
                AND sub.sub_category = @sub_category;

            IF @flag IS NULL
                BEGIN
                    SET @product_id = NULL;
                    RAISERROR('Blad!!',1,1);
                END
            ELSE
                BEGIN

                    INSERT INTO OrderDB.dbo.products (name, sub_category_id)
                    OUTPUT inserted.id INTO @OutputTbl(id)
                    VALUES (@product, @sub_category_id);
                    SELECT @product_id = id FROM @OutputTbl;     

                END
        END

    IF ((@product_id IS NULL) AND (@sub_category_id IS NULL) AND (@category_id IS NOT NULL) ) -- kategoria istnieje
        BEGIN

                INSERT INTO OrderDB.dbo.sub_categories (sub_category, category_id)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@sub_category, @category_id);
                SELECT @sub_category_id = id FROM @OutputTbl;                

                INSERT INTO OrderDB.dbo.products (name, sub_category_id)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@product, @sub_category_id);
                SELECT @product_id = id FROM @OutputTbl;  

        END

    IF ((@product_id IS NULL) AND (@sub_category_id IS NULL) AND (@category_id IS NULL) ) -- nic nie istnieje
        BEGIN

                INSERT INTO OrderDB.dbo.categories (category)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@category);
                SELECT @category_id = id FROM @OutputTbl;

                INSERT INTO OrderDB.dbo.sub_categories (sub_category, category_id)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@sub_category, @category_id);
                SELECT @sub_category_id = id FROM @OutputTbl;                

                INSERT INTO OrderDB.dbo.products (name, sub_category_id)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@product, @sub_category_id);
                SELECT @product_id = id FROM @OutputTbl;  
        END
GO

---------------------------------------
-- CUSTOMER
USE OrderDB;
DROP PROCEDURE IF EXISTS SelectAddCustomer;
GO

/*
Zwraca id klienta jeżeli klient istnieje,
jeżeli klient nie istnieje to go tworzy. 
Dla błednych segmentu dla isniejącego klienta zwraca bład
*/
CREATE PROCEDURE [SelectAddCustomer]
    @customer VARCHAR(255),
    @segment VARCHAR(50),
    @customer_id INT OUTPUT
AS
    DECLARE @segment_id INTEGER;
    DECLARE @flag AS SMALLINT;
    DECLARE @OutputTbl TABLE (id INT);


    SELECT @customer_id = id
    FROM OrderDB.dbo.customers
    WHERE name = @customer;  
    
    SELECT @segment_id = id
    FROM OrderDB.dbo.segments
    WHERE segment = @segment;
    
    IF ((@customer_id IS NOT NULL)) -- klient instnieje
        BEGIN
            SET @flag = NULL;

            SELECT @flag = cus.id
            FROM OrderDB.dbo.customers as cus
            LEFT JOIN OrderDB.dbo.segments as seg
                ON cus.segment_id = seg.id 
            WHERE
                cus.name = @customer
                AND seg.segment = @segment;

            IF @flag IS NULL -- zły segment dla klienta
                BEGIN
                    SET @customer_id = @flag;
                    RAISERROR('Blad !!',1,1);
                END
            ELSE -- dobry segment dla klienta
                BEGIN
                    SET @customer_id = @flag;
                END
        END
    ELSE -- klient nie istnieje
        BEGIN
            IF (@segment_id IS NOT NULL) -- segemnt istnieje
                BEGIN
                    INSERT INTO OrderDB.dbo.customers (name, segment_id)
                    OUTPUT inserted.id INTO @OutputTbl(id)
                    VALUES (@customer, @segment_id);
                    SELECT @customer_id = id FROM @OutputTbl;     
                END
            ELSE -- segemnt nie istnieje
                BEGIN
                    INSERT INTO OrderDB.dbo.segments (segment)
                    OUTPUT inserted.id INTO @OutputTbl(id)
                    VALUES (@segment);
                    SELECT @segment_id = id FROM @OutputTbl;                

                    INSERT INTO OrderDB.dbo.customers (name, segment_id)
                    OUTPUT inserted.id INTO @OutputTbl(id)
                    VALUES (@customer, @segment_id);
                    SELECT @customer_id = id FROM @OutputTbl; 
                END
            END
GO
---------------------------------------
-- Country with Market
USE OrderDB;
DROP PROCEDURE IF EXISTS SelectAddCountryWithMarket;
GO
/*
Zwraca id kraju jeżeli kraj istnieje,
jeżeli kraj nie istnieje to go tworzy. 
Dla błednych marketu dla isniejącego kraju zwraca bład
*/
CREATE PROCEDURE [SelectAddCountryWithMarket]
    @country VARCHAR(255),
    @market VARCHAR(50),
    @country_id INT OUTPUT
AS
    DECLARE @market_id INTEGER;
    DECLARE @flag AS SMALLINT;
    DECLARE @OutputTbl TABLE (id INT);


    SELECT @country_id = id
    FROM OrderDB.dbo.countries
    WHERE country = @country;  
    
    SELECT @market_id = id
    FROM OrderDB.dbo.markets
    WHERE market = @market;
    
    IF ((@country_id IS NOT NULL)) -- państwo instnieje
        BEGIN
            SET @flag = NULL;

            SELECT @flag = cou.id
            FROM OrderDB.dbo.countries as cou
            LEFT JOIN OrderDB.dbo.markets as mar
                ON cou.market_id = mar.id 
            WHERE
                cou.country = @country
                AND mar.market = @market;

            IF @flag IS NULL -- zły market dla kraju
                BEGIN
                    SET @country_id = @flag;
                    RAISERROR('Blad!!',1,1);
                END
            ELSE -- dobry market dla kraju
                BEGIN
                    SET @country_id = @flag;
                END
        END
    ELSE -- kraj nie istnieje
        BEGIN
            IF (@market_id IS NOT NULL) -- market istnieje
                BEGIN
                    INSERT INTO OrderDB.dbo.countries (country, market_id)
                    OUTPUT inserted.id INTO @OutputTbl(id)
                    VALUES (@country, @market_id);
                    SELECT @country_id = id FROM @OutputTbl;     
                END
            ELSE -- market nie istnieje
                BEGIN

                        INSERT INTO OrderDB.dbo.markets(market)
                        OUTPUT inserted.id INTO @OutputTbl(id)
                        VALUES (@market);
                        SELECT @market_id = id FROM @OutputTbl;                

                        INSERT INTO OrderDB.dbo.countries (country, market_id)
                        OUTPUT inserted.id INTO @OutputTbl(id)
                        VALUES (@country, @market_id);
                        SELECT @country_id = id FROM @OutputTbl; 
                END
            END
GO
---------------------------------------
-- Cities
USE OrderDB;
GO
DROP PROCEDURE IF EXISTS SelectAddCity;
GO
/*
Zwraca id miasta jeżeli miasto istnieje,
jeżeli miasto nie istnieje to go tworzy.
*/
CREATE PROCEDURE [SelectAddCity]
    @city VARCHAR(100),
    @city_id INT OUTPUT
AS
    DECLARE @OutputTbl TABLE (id INT);

    SELECT @city_id = id
    FROM OrderDB.dbo.cities
    WHERE city = @city;  
    

    IF (@city_id IS NULL)
        BEGIN
            INSERT INTO OrderDB.dbo.cities(city)
            OUTPUT inserted.id INTO @OutputTbl(id)
            VALUES (@city);
            SELECT @city_id = id FROM @OutputTbl;
        END
  
GO
---------------------------------------
-- States 
USE OrderDB;
GO
DROP PROCEDURE IF EXISTS SelectAddState;
GO
/*
Zwraca id stanu jeżeli stan istnieje,
jeżeli stan nie istnieje to go tworzy.
*/
CREATE PROCEDURE [SelectAddState]
    @state VARCHAR(100),
    @state_id INT OUTPUT
AS
    DECLARE @OutputTbl TABLE (id INT);

    SELECT @state_id = id
    FROM OrderDB.dbo.states
    WHERE state = @state;  
    

    IF (@state_id IS NULL)
        BEGIN
            INSERT INTO OrderDB.dbo.states(state)
            OUTPUT inserted.id INTO @OutputTbl(id)
            VALUES (@state);
            SELECT @state_id = id FROM @OutputTbl;
        END
  
GO
---------------------------------------

-- Ship mode 
DROP PROCEDURE IF EXISTS SelectAddShipMode;
GO
/*
Zwraca id ShipModu jeżeli istnieje,
jeżeli nie istnieje to go tworzy.
*/
CREATE PROCEDURE [SelectAddShipMode]
    @ship_mode VARCHAR(255),
    @ship_mode_id INT OUTPUT
AS
    DECLARE @OutputTbl TABLE (id INT);

    SELECT @ship_mode_id = id
    FROM OrderDB.dbo.ship_modes
    WHERE ship_mode = @ship_mode;  
    

    IF (@ship_mode_id IS NULL)
        BEGIN
            INSERT INTO OrderDB.dbo.ship_modes(ship_mode)
            OUTPUT inserted.id INTO @OutputTbl(id)
            VALUES (@ship_mode);
            SELECT @ship_mode_id = id FROM @OutputTbl;
        END
  
GO
---------------------------------------
DROP PROCEDURE IF EXISTS AddPositionToOrderFromXML;
GO

/*
Na podstawie pliku XML dodaje do stworzonego zamówienia pozycje.
*/
CREATE PROCEDURE [AddPositionToOrderFromXML]
    @positions XML,
    @order_id INT
AS

    DECLARE @i AS INT;
    DECLARE @j AS INT;
    DECLARE @product_id_out AS INT;
    DECLARE @product AS VARCHAR(255);
    DECLARE @sub_category AS VARCHAR(255);
    DECLARE @category AS VARCHAR(255);
    SET @j = @positions.value('(order/number_of_positions)[1]', 'INT');
    SET @i = 1;

    WHILE (@i <= @j)
        BEGIN
            SELECT @product = @positions.value('(order/positions/position[sql:variable("@i")]/product)[1]', 'VARCHAR(255)');
            SELECT @sub_category = @positions.value('(order/positions/position[sql:variable("@i")]/sub_category)[1]', 'VARCHAR(255)');
            SELECT @category = @positions.value('(order/positions/position[sql:variable("@i")]/category)[1]', 'VARCHAR(255)');

            EXEC [SelectAddProduct]
                @product = @product,
                @sub_category = @sub_category,
                @category = @category,
                @product_id = @product_id_out OUTPUT;

            INSERT INTO OrderDB.dbo.positions (product_id, order_id, sales, quantity, discount, profit, shipping_cost) 
            SELECT
                @product_id_out,
                @order_id,
                @positions.value('(order/positions/position[sql:variable("@i")]/sales)[1]', 'SMALLMONEY'),
                @positions.value('(order/positions/position[sql:variable("@i")]/quantity)[1]', 'SMALLINT'),
                @positions.value('(order/positions/position[sql:variable("@i")]/discount)[1]', 'NUMERIC(5,2)'),
                @positions.value('(order/positions/position[sql:variable("@i")]/profit)[1]', 'SMALLMONEY'),
                @positions.value('(order/positions/position[sql:variable("@i")]/shipping_cost)[1]', 'NUMERIC(8,3)');

            SET @i = @i + 1;
        END
GO
---------------------------------------
DROP PROCEDURE IF EXISTS CreateOrderFromXML;
GO

/*
Na podstawie pliku XML tworzy zmówienie.
Jeśli trzeba przy pomocy podprocedur wprowadza dane do bazy danych.
*/
CREATE PROCEDURE CreateOrderFromXML
    @order XML,
    @order_id_out INT OUTPUT
AS
    DECLARE @name AS VARCHAR(100);
    SET @name = @order.value('(order/customer/name)[1]', 'VARCHAR(100)');
    DECLARE @segment AS VARCHAR(50);
    SET @segment = @order.value('(order/customer/segment)[1]', 'VARCHAR(50)');
    DECLARE @market AS VARCHAR(50);
    SET @market = @order.value('(order/address/market)[1]', 'VARCHAR(50)');
    DECLARE @country AS VARCHAR(100);
    SET @country = @order.value('(order/address/country)[1]', 'VARCHAR(100)');
    DECLARE @state AS VARCHAR(100);
    SET @state = @order.value('(order/address/state)[1]', 'VARCHAR(100)');
    DECLARE @city AS VARCHAR(100);
    SET @city = @order.value('(order/address/city)[1]', 'VARCHAR(100)');
    DECLARE @postal_code AS CHAR(6) ;
    SET @postal_code = @order.value('(order/address/postal_code)[1]', 'CHAR(6)');
    DECLARE @ship_mode AS VARCHAR(50);
    SET @ship_mode = @order.value('(order/ship_mode)[1]', 'VARCHAR(50)');
    DECLARE @order_date AS DATE;
    SET @order_date = @order.value('(order/order_date)[1]', 'DATE');
    DECLARE @ship_date AS DATE;
    SET @ship_date = @order.value('(order/ship_date)[1]', 'DATE');

    DECLARE @customer_id_out AS INTEGER;
    DECLARE @market_id_out AS INT;
    DECLARE @country_id_out AS INT;
    DECLARE @state_id_out AS INT;
    DECLARE @city_id_out AS INT;
    DECLARE @ship_mode_id_out AS INT;
    DECLARE @ship_address_id AS INT;
    DECLARE @OutputTbl TABLE (id INT);

    BEGIN TRANSACTION;

        -- customers
        EXEC [SelectAddCustomer]
            @customer = @name,
            @segment = @segment,
            @customer_id = @customer_id_out OUTPUT;    
     
        -- ship mode
        EXEC [SelectAddShipMode]
            @ship_mode = @ship_mode,
            @ship_mode_id = @ship_mode_id_out OUTPUT;

        -- city
        EXEC [SelectAddCity]
            @city = @city,
            @city_id = @city_id_out OUTPUT;

        -- state
        EXEC [SelectAddState]
            @state = @state,
            @state_id = @state_id_out OUTPUT;

        -- country with market
        EXEC [SelectAddCountryWithMarket]
            @country = @country,
            @market = @market,
            @country_id = @country_id_out OUTPUT;

        SELECT @ship_address_id = id
        FROM OrderDB.dbo.ship_addresses
        WHERE
            city_id = @city_id_out
            AND state_id = @state_id_out
            AND country_id = @country_id_out    
            AND postal_code = @postal_code; 

        IF @ship_address_id IS NULL
            BEGIN
                INSERT INTO OrderDB.dbo.ship_addresses (city_id, state_id, country_id, postal_code)
                OUTPUT inserted.id INTO @OutputTbl(id)
                VALUES (@city_id_out, @state_id_out, @country_id_out, @postal_code);

                SELECT @ship_address_id = id
                FROM @OutputTbl;

                DELETE FROM @OutputTbl;
            END

        BEGIN TRY
            INSERT INTO OrderDB.dbo.orders (customer_id, ship_address_id, ship_mode_id, order_date, ship_date)
            OUTPUT inserted.id INTO @OutputTbl(id)
            VALUES (@customer_id_out, @ship_address_id, @ship_mode_id_out, @order_date, @ship_date);
            SELECT @order_id_out = id FROM @OutputTbl;

            EXEC [AddPositionToOrderFromXML]
                @positions = @order,
                @order_id = @order_id_out;

                COMMIT;

        END TRY
        BEGIN CATCH
            SELECT
                ERROR_PROCEDURE() AS ErrorProcedure,
                ERROR_MESSAGE() AS ErrorMessage;
                ROLLBACK;
        END CATCH

GO
---------------------------------------
/*
Podpunkt 5
5. Implementację procedury i/lub funkcji testującej w całości
   punkt 4 z kompletnym zamówieniem, które będzie można wprowadzić
   do bazy danych OrderDB.

Poniżej znajduje się przykąłdowe zamówienie w formacie XML dodane w celu możłiwości 
przetestowania bazy danych i procedur.
*/

DECLARE @test_order_str NVARCHAR(MAX);
DECLARE @test_order_id INT;
DECLARE @test_order_xml XML;
SET @test_order_str = 
'''
<order>
    <customer>
        <name>John Lee</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-18</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>2</number_of_positions>
    <positions>
        <position>
            <product>12 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
        <position>
            <product>Acco Index Tab, Durable</product>
            <sub_category>Binders</sub_category>
            <category>Office Supplies</category>
            <sales>2330</sales>
            <quantity>1</quantity>
            <discount>0.00</discount>
            <profit>2000</profit>
            <shipping_cost>90.120</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

SELECT
    ord.id AS "Order Id",
    cus.name,
    seg.segment,
    ord.order_date,
    ord.ship_date,
    pro.name,
    s_ca.sub_category,
    cat.category,
    pos.sales,
    pos.quantity,
    pos.discount,
    pos.profit,
    pos.shipping_cost,
    ord.ship_date,
    s_mo.ship_mode,
    cit.city, 
    sta.state, 
    s_ad.postal_code, 
    cou.country, 
    mar.market 
FROM OrderDB.dbo.positions as pos
    LEFT JOIN OrderDB.dbo.orders as ord
        ON pos.order_id = ord.id
        LEFT JOIN OrderDB.dbo.ship_modes as s_mo
            ON ord.ship_mode_id = s_mo.id
        LEFT JOIN OrderDB.dbo.customers as cus
            ON ord.customer_id = cus.id
            LEFT JOIN OrderDB.dbo.segments as seg
                ON cus.segment_id = seg.id
        LEFT JOIN OrderDB.dbo.ship_addresses as s_ad
            ON ord.ship_address_id = s_ad.id
            LEFT JOIN OrderDB.dbo.cities as cit
                ON s_ad.city_id = cit.id
            LEFT JOIN OrderDB.dbo.states as sta
                ON s_ad.state_id = sta.id
            LEFT JOIN OrderDB.dbo.countries as cou
                ON s_ad.country_id = cou.id
                LEFT JOIN OrderDB.dbo.markets as mar
                    ON cou.market_id = mar.id
    LEFT JOIN OrderDB.dbo.products as pro
        ON pos.product_id = pro.id
        LEFT JOIN OrderDB.dbo.sub_categories as s_ca
            ON pro.sub_category_id = s_ca.id
            LEFT JOIN OrderDB.dbo.categories as cat
                ON s_ca.category_id = cat.id
WHERE
    ord.id = @test_order_id;

---------------------------------------
