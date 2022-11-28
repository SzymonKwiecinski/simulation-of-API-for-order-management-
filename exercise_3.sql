/*
Zadanie 03
Szymon Kwieciński nr. indeksu: 324159

*/


/*#####################################################################################################
1. Utworzenie indeksu zgrupowanego oraz indeksu niezgrupowanego (w komentarzu skryptu wynikowego dla Zadanie 03
należy uzasadnić powód założenia konkretnego typu indeksu na wybranej strukturze)


Indeks zgrupowny (cluster index) tworzy się przy automatycznie prz definiowaniu PRIMARY KEY i może być zdefiniowany tylko jeden dla tabeli.
Przykładem jest indeks w tabeli 'orders' dla columny 'id'. Dzięki temu indeksowi SQL server podczas wykonywania zapytań
nie będzie skanował całej tabli wiersz po wierszu tylko użyje algorytmu który na posortowanych wartościach, podzielonych na strony szybko znajdzie 
dane zamówienie/zamówienia po numerze id

    Skrypt który tworzy indeks znajduje się poniżej jest zakomentowany, jednak nie jest on potrzebny,
    ponieważ przy tworzeniu tabeli indeks zgrupowany został stworzony automatycznie
*/
-- CREATE CLUSTERED INDEX clustered_index_orders_id
-- ON OrderDB.dbo.orders (id ASC);
-- GO

/*
Indeks niezgrupowany (noncluster index) zostaje tworzony automatycznie dla kolumny z warunkiem UNIQUE nie będącymi kluczem głównym.
Nie ma ograniczeń co do ich ilości. Dodatkowo zajmują dodatkowe miejsce w pamięci co trzeba zawsze mieć na uwadze.

Przykładowo tworze index w tabeli 'customers' dla columny 'name'. Dzięki indeksowi niezgrupowanemu
znalezienie szukanego id klienta poprzez jego nazwę (imię i nazwisko) będzie szybsze 
*/
CREATE NONCLUSTERED INDEX noclustered_index_unique_customer_name
ON OrderDB.dbo.customers (name ASC);
GO

/*#####################################################################################################
2. Utworzenie indeksu gęstego i rzadkiego (w komentarzu skryptu wynikowego dla Zadanie 03
należy uzsadnić powód założenia konretnego typu indeksu na wybranej strukturze)


Indeks gęsty (dense) – zawiera wpis dla każdej wartości klucza wyszukiwania, czyli dla każdego rekordu.
    -każdy indeks niezgrupowany (unclustered) jest indeksem gęstym

    Przykładem indeksu gęstego w mojej bazie danych jest indeks w tabeli 'customers' dla kolumny 'name'
	(jak w podpunkcie 1) Dzięki indeksowi niezgrupowanemu znalezienie szukanego id klienta poprzez jego nazwę (imię i nazwisko) będzie szybsze.


Indeks rzadki (sparse) – posiada wpis jedynie dla niektórych wartości wyszukiwania (np. bloków).
    -każdy indeks zgrupowany (clustered) jest indeksem rzadkim

    Przykładem indeksu rzadkiego w mojej bazie danych jest indeks w tabeli 'orders' dla kolumny 'id'
	(jak w podpunkcie 1) Dzięki temu indeksowi SQL server podczas wykonywania zapytań
	nie będzie skanował całej tabli wiersz po wierszu tylko użyje algorytmu który na posortowanych wartościach, podzielonych na strony szybko znajdzie 
	dane zamówienie/zamówienia po numerze id
*/


/*#####################################################################################################
3. Utworzenie indeksu kolumnego (w komentarzu skryptu wynikowego dla Zadanie 03 należy uzsadnić w
jakich sytuacjach indeks kolumnowy odgrywa istotne znaczenie w strojeniu baz danych)

Indeks columnowy stosuje się aby zwiększyć szybkość przeszukiwania dużych tabel, czyli do zastosowań analizy danych.
Zgodnie z dokumentacją Microsoft rekomendowane jest używanie "clustred column indexes" dla tabel faktów oraz bardzo
dużych tabel "dimension". Zwiększa szybkość zapytań do około 10 razy przy poprawym użyciu.

W przypadku mojej bazy danych zastosuje index kolumnowy do tabeli positions, jest to największa tabela w mojej bazie danych, zawięrająca wiele danych liczbowych.
Dla tej tabeli w przyszłości mogą być przeprowadzane zapytania analizy danych na przykład: średnia sprzedaż miesięczna itp..

*/
ALTER TABLE OrderDB.dbo.positions DROP CONSTRAINT [PK__position__3213E83F70CF8C29] WITH ( ONLINE = OFF )
-- UWAGA powyższy indeks został stworzony automatycznie dla mojej bazy danych, aby znaleźć nazwe indeku należy wykonać polecenie jak poniżęj
-- EXECUTE sp_helpindex OrderDB.dbo.positions;
GO

-- stworzenie columnstore index
CREATE CLUSTERED COLUMNSTORE INDEX ClusteredColumneStoreIndex_positions ON OrderDB.dbo.positions;
-- nałożenie warunku unikatowości na pole id po tym jak usuneliśmy z tego pola indeks PRIMARY KEY
ALTER TABLE OrderDB.dbo.positions ADD UNIQUE (id);
GO


/*#####################################################################################################
Podpunkt 4
    Utworzenie procedury lub funkcji zwracającej wszystkie zamówienia
    wymagane kolumny wynikowe: order id, order date, ship date, product name, sales, quantity, profit)
    dla konkretnej podkategorii (subcategory) w konkretnym kraju (country)

    Skrypt pozwalający dodać do bazy danych dane które pozwolą przetestować tę procedurę znajduje się na samym dole skryptu (Dodatek A)
*/

DROP PROCEDURE IF EXISTS SelectFilteredOrders;
GO

CREATE PROCEDURE SelectFilteredOrders
    @subcategory_product VARCHAR(50),
    @country VARCHAR(100)
AS
    SELECT
        ord.id AS "order id",--
        ord.order_date AS "order date",--
        ord.ship_date AS "ship date",--
        pro.name AS "product name",--
        pos.sales AS "sales",--
        pos.quantity AS "quantity",--
        pos.profit AS "profit"--
    FROM OrderDB.dbo.positions as pos
        LEFT JOIN OrderDB.dbo.orders as ord
            ON pos.order_id = ord.id
            LEFT JOIN OrderDB.dbo.ship_addresses as s_ad
                ON ord.ship_address_id = s_ad.id
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
        cou.country = @country
        AND s_ca.sub_category = @subcategory_product
GO

EXEC [SelectFilteredOrders]
    @country = 'United States',
    @subcategory_product = 'Art';
GO


/*#####################################################################################################
Podpunkt 5
    Utworzenie procedury lub funkcji zwracającej dwa najnowsze zamówienia
    (wymagane kolumny wynikowe: order id, order date, product name, sales, customer name)
    dla każdego klienta w segmencie Consumer (segment = Consumer).

Od Autora:
    Dwa najnowsze zamówienia zostają wybrane według najbliższej daty (order_date),
    a w przypadku kiedy jest wiele zamówień dla danej daty,
    to zostają zwrócone zamówienia o najwiekszym numerze order_id,
    ponieważ zamówienie z większym numerem id jest zamówieniem nowszym.

    Skrypt pozwalający dodać do bazy danych dane które pozwolą przetestować tę procedurę znajduje się na samym dole skryptu (Dodatek A)
*/

DROP PROCEDURE IF EXISTS SelectLastTwoOrdersForEachConsumer
GO

CREATE PROCEDURE SelectLastTwoOrdersForEachConsumer
AS

    WITH last_two_orders AS (
        SELECT
            ord.id,
            ord.order_date,
            cus.name,
            ROW_NUMBER() OVER( PARTITION BY cus.id ORDER BY ord.order_date DESC, ord.id DESC) AS "number"
            FROM OrderDB.dbo.orders as ord
                LEFT JOIN OrderDB.dbo.customers as cus
                    ON ord.customer_id = cus.id
                    LEFT JOIN OrderDB.dbo.segments as seg
                        ON cus.segment_id = seg.id
        WHERE
            seg.segment = 'Consumer'

    )
    SELECT
        ord.id AS "order id",
        ord.order_date AS "order date",
        pro.name AS "product name",
        pos.sales AS "sales",
        ord.name AS "customer name"
    FROM 
        last_two_orders AS ord
        RIGHT JOIN OrderDB.dbo.positions AS pos
            ON ord.id = pos.order_id
            LEFT JOIN OrderDB.dbo.products AS pro
                ON pos.product_id = pro.id
    WHERE
        number IN (1,2)
    ORDER BY
        ord.name,
        ord.order_date DESC,
        ord.id DESC

GO

EXEC [SelectLastTwoOrdersForEachConsumer];




/*#####################################################################################################
--Dodatek A
--Skrypt pozwalający zapisać do bazy danych po trzy zamówienia dla dwóch kupujących z segmentu=Consumer

USE OrderDB;
DECLARE @test_order_str NVARCHAR(MAX);
DECLARE @test_order_id INT;
DECLARE @test_order_xml XML;
SET @test_order_str = 
'''
<order>
    <customer>
        <name>Szymon Kwiecinski</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-17</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
    <positions>
        <position>
            <product>44 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

SET @test_order_str = 
'''
<order>
    <customer>
        <name>Szymon Kwiecinski</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-16</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
    <positions>
        <position>
            <product>2 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

SET @test_order_str = 
'''
<order>
    <customer>
        <name>Szymon Kwiecinski</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-16</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
    <positions>
        <position>
            <product>122 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

----------------

SET @test_order_str = 
'''
<order>
    <customer>
        <name>John Lee</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-17</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
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
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

SET @test_order_str = 
'''
<order>
    <customer>
        <name>John Lee</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-16</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
    <positions>
        <position>
            <product>15 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;

SET @test_order_str = 
'''
<order>
    <customer>
        <name>John Lee</name>
        <segment>Consumer</segment>
    </customer>
    <order_date>2022-10-16</order_date>
    <address>
        <city>Arlington</city>
        <state>Texas</state>
        <country>United States</country>
        <market>USCA</market>
        <postal_code>76017</postal_code>
    </address>
    <ship_mode>Standard Class</ship_mode>
    <ship_date>2022-10-20</ship_date>
    <number_of_positions>1</number_of_positions>
    <positions>
        <position>
            <product>10 Colored Short Pencils</product>
            <sub_category>Art</sub_category>
            <category>Office Supplies</category>
            <sales>200</sales>
            <quantity>2</quantity>
            <discount>0.10</discount>
            <profit>180</profit>
            <shipping_cost>20</shipping_cost>
        </position>
    </positions>
</order>
'''
SET @test_order_xml = CAST(@test_order_str AS XML);


EXEC [CreateOrderFromXML]
    @order = @test_order_xml,
    @order_id_out = @test_order_id OUTPUT;
GO

*/
