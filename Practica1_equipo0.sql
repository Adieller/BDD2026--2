use AdventureWorks2022;
GO
-- =========================================
-- CONSULTA 1: Encuentra los 10 productos más vendidos en 2014, mostrando nombre del producto, cantidad total vendida y nombre del cliente.
-- =========================================
-- Variante final con análisis de precio:
WITH ProductSales2014 AS (
    SELECT
        pr.ProductID, pr.Name AS ProductName, pr.ListPrice,
        sod.SalesOrderID, soh.OrderDate, c.CustomerID,
        CONCAT(p.FirstName, ', ', p.LastName) AS CustomerName,
        sod.OrderQty, sod.UnitPrice
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON sod.SalesOrderID = soh.SalesOrderID
    JOIN Production.Product pr ON pr.ProductID = sod.ProductID
    JOIN Sales.Customer c ON c.CustomerID = soh.CustomerID
    JOIN Person.Person p ON p.BusinessEntityID = c.PersonID
    WHERE soh.OrderDate >= '20140101' AND soh.OrderDate < '20150101'
),
Agg AS (
    SELECT
        ProductID, ProductName, ListPrice,
        SUM(OrderQty) AS AmountOfSales, avg(UnitPrice) as AvgUnitPrice
    FROM ProductSales2014
    GROUP BY ProductID, ProductName, ListPrice
),
SalesByCustomer as (
    select distinct (CustomerName), sum(OrderQty) as TotalBought
    from ProductSales2014
    group by CustomerName
),
T10Products as (
    select top 10 ProductID
    from Agg
    where ListPrice >= 1000
    order by AmountOfSales desc
)
select
    a.ProductName, a.AmountOfSales, sbc.CustomerName,
    sbc.TotalBought, a.AvgUnitPrice, a.ListPrice
from Agg a
join ProductSales2014 ps on a.ProductID = ps.ProductID
join SalesByCustomer sbc on ps.CustomerName = sbc.CustomerName
where a.ProductID in (select * from T10Products)
group by a.ProductName, a.AmountOfSales, sbc.CustomerName, sbc.TotalBought, a.AvgUnitPrice, a.ListPrice
order by a.AmountOfSales desc, sbc.TotalBought desc;

-- =========================================
-- CONSULTA 2: Lista los empleados que han vendido más que el promedio de ventas por empleado en el territorio 'Northwest'. 
-- 1. Requisito adicional: aplicar subconsultas. 
-- 2. Una vez resuelta la consulta convierte la subconsulta en un CTE (Common Table Expresión). 
-- 3. Documenta la solución inicial y solución con la variante solicitada. 
-- =========================================

-- Solución optimizada usando CTEs:
WITH SumaXEmpleado AS (
    Select sum(TotalDue) as SumaPorEmpleado, Person.BusinessEntityID as IDVendedor
    from Sales.SalesOrderHeader 
    join Person.Person on Sales.SalesOrderHeader.SalesPersonID = Person.BusinessEntityID
    where SalesOrderHeader.TerritoryID = 1 and Person.PersonType = 'SP'
    group by Person.BusinessEntityID
),
PromedioEmpleado as (
    select AVG(SumaPorEmpleado) as PromedioXEmpleado
    from SumaXEmpleado
)
Select SumaPorEmpleado, IDVendedor
from SumaXEmpleado, PromedioEmpleado
where SumaPorEmpleado > PromedioXEmpleado;

-- =========================================
-- CONSULTA 3:  Calcula ventas totales por territorio y año, mostrando solo aquellos con más de 5 órdenes y ventas > $1,000,000, ordenado por ventas descendente. 
-- 1. Una vez resuelta la consulta agrega desviación estándar de ventas 
-- 2. Documenta la solución inicial y solución con la variante solicitada. 
-- =========================================
-- Variante con cálculo de Desviación Estándar:
with OrderTotals as (
    select
        st.Name, year(soh.OrderDate) as OrderYear, soh.SalesOrderID,
        sum(sod.LineTotal) as OrderTotal
    from Sales.SalesTerritory st
    join Sales.SalesOrderHeader soh on soh.TerritoryID = st.TerritoryID
    join Sales.SalesOrderDetail sod on sod.SalesOrderID = soh.SalesOrderID
    group by st.Name, year(soh.OrderDate), soh.SalesOrderID
)
select
    Name, OrderYear, sum(OrderTotal) as totalSales,
    count(*) as orderCount, stdev(OrderTotal) as stdevOrderSales
from OrderTotals
group by Name, OrderYear
having count(*) >= 5
order by stdevOrderSales desc;

-- =========================================
-- CONSULTA 4: Encuentra vendedores que han vendido TODOS los productos de la categoría "Bikes". 
-- 1. Cambia a categoría "Clothing" (ID=4). 
-- 2. Cuenta cuántos productos por categoría maneja cada vendedor. 
-- 3. Documenta la solución inicial y solución con las variantes solicitadas. 
-- =========================================
-- Solución para la categoría "Bikes" (ID=1):
WITH NoProdBikes AS (
    select COUNT(Productos.ProductID) as TotalArticulosBikes
    from Production.ProductSubcategory as SubCat
    join Production.ProductCategory as Cat on SubCat.ProductCategoryID = Cat.ProductCategoryID
    JOIN Production.Product as Productos on Productos.ProductSubcategoryID = SubCat.ProductSubcategoryID
    where Cat.ProductCategoryID = 1
),
ProdDistintXVende AS (
    SELECT CabezaVenta.SalesPersonID, COUNT(DISTINCT Productos.ProductID) as ProdDistintos
    from Sales.SalesOrderHeader as CabezaVenta
    join Person.Person as Empleados on CabezaVenta.SalesPersonID = Empleados.BusinessEntityID
    join Sales.SalesOrderDetail as DetalleVenta on CabezaVenta.SalesOrderID = DetalleVenta.SalesOrderID
    join Production.Product as Productos on Productos.ProductID = DetalleVenta.ProductID
    join Production.ProductSubcategory as SubCat on Productos.ProductSubcategoryID = SubCat.ProductSubcategoryID
    join Production.ProductCategory as CategoriP on CategoriP.ProductCategoryID = SubCat.ProductCategoryID
    where CategoriP.ProductCategoryID = 1
    group by CabezaVenta.SalesPersonID
)
Select *
from ProdDistintXVende, NoProdBikes
where ProdDistintXVende.ProdDistintos = NoProdBikes.TotalArticulosBikes;

-- =========================================
-- CONSULTA 5: Determinar el producto más vendido de cada categoría de producto, considerando el escenario de que el esquema SALES se encuentra en una instancia (servidor) A y el esquema PRODUCTION en otra instancia (servidor) B. 
-- =========================================
-- Solución con simulación de Servidores Vinculados:
WITH ProductSales AS (
    SELECT
        pc.ProductCategoryID, 
        pc.Name AS CategoryName,
        p.ProductID, 
        p.Name AS ProductName,
        SUM(sod.OrderQty) AS TotalSold
    FROM Sales.SalesOrderDetail sod -- Se quitó SV_P1.
    JOIN Production.Product p 
        ON p.ProductID = sod.ProductID -- Se quitó SV_P2.
    JOIN Production.ProductSubcategory ps 
        ON ps.ProductSubcategoryID = p.ProductSubcategoryID
    JOIN Production.ProductCategory pc 
        ON pc.ProductCategoryID = ps.ProductCategoryID
    GROUP BY 
        pc.ProductCategoryID, 
        pc.Name, 
        p.ProductID, 
        p.Name
),
RankedProducts AS (
    SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY ProductCategoryID
        ORDER BY TotalSold DESC
    ) AS rn
    FROM ProductSales
)
SELECT 
    CategoryName, 
    ProductName, 
    TotalSold
FROM RankedProducts
WHERE rn = 1
ORDER BY CategoryName;