#Business requests
	
#1
SELECT DISTINCT FE.PRODUCT_CODE,PRODUCT_NAME,BASE_PRICE FROM FACT_EVENTS FE
JOIN DIM_PRODUCTS DP ON FE.PRODUCT_CODE=DP.PRODUCT_CODE
WHERE BASE_PRICE>500 AND PROMO_TYPE LIKE 'BOGOF'
ORDER BY BASE_PRICE DESC;

#2
SELECT CITY,COUNT(STORE_ID) FROM DIM_STORES
GROUP BY CITY
ORDER BY 2 DESC;

#3
with cte as(
SELECT campaign_name,promo_type,sum(base_price*`quantity_sold(before_promo)`) as `total_revenue(before_promo)`,
case
	when promo_type like '50%' or promo_type like 'BOGOF%' then sum(base_price*(1-0.5)*`quantity_sold(after_promo)`) 
	when promo_type like '25%' then sum(base_price*(1-0.25)*`quantity_sold(after_promo)`) 
	when promo_type like '33%' then sum(base_price*(1-0.33)*`quantity_sold(after_promo)`) 
	when promo_type like '500%' then sum((base_price-500)*`quantity_sold(after_promo)`)
end	`total_revenue(after_promo)`
from dim_campaigns dc
JOIN fact_events fe 
ON DC.CAMPAIGN_ID=FE.CAMPAIGN_ID
group by 1,promo_type)
select campaign_name,round(sum(`total_revenue(before_promo)`/1000000),2) as 'total_revenue(before_promo) in million',
round(sum(`total_revenue(after_promo)`/1000000),2) as 'total_revenue(after_promo) in million' from cte
group by 1 ;


#4
with cte as(
select category,c.campaign_name,
sum(`quantity_sold(before_promo)`) qty_before_promo,
sum(`quantity_sold(after_promo)`) qty_after_promo
from fact_events e
join dim_products p on e.product_code=p.product_code
join dim_campaigns c on e.campaign_id=c.campaign_id 
group by 1,2
having c.campaign_name like 'Diwali'
order by 3,4 desc)
select campaign_name,category,round(((qty_after_promo-qty_before_promo)/qty_before_promo * 100),2) as Incremental_sold_qty_pct,row_number() over() as rank_order
from cte order by 3 desc;

#5 
WITH cte AS (
    SELECT
        product_name,
        category,
        100 * (`total_revenue(after_promo)` - `total_revenue(before_promo)`) / `total_revenue(before_promo)` AS ir_pct,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY 100 * (`total_revenue(after_promo)` - `total_revenue(before_promo)`) / `total_revenue(before_promo)` DESC) AS rn
    FROM (
        SELECT
            p.product_name,
            p.category,
            SUM(base_price * `quantity_sold(before_promo)`) AS `total_revenue(before_promo)`,
            CASE
                WHEN promo_type LIKE '50%' OR promo_type LIKE 'BOGOF%' THEN SUM(base_price * (1 - 0.5) * `quantity_sold(after_promo)`)
                WHEN promo_type LIKE '25%' THEN SUM(base_price * (1 - 0.25) * `quantity_sold(after_promo)`)
                WHEN promo_type LIKE '33%' THEN SUM(base_price * (1 - 0.33) * `quantity_sold(after_promo)`)
                WHEN promo_type LIKE '500%' THEN SUM((base_price - 500) * `quantity_sold(after_promo)`)
            END AS `total_revenue(after_promo)`
        FROM fact_events e
        JOIN dim_products p ON p.product_code = e.product_code
        GROUP BY p.product_name, p.category, promo_type
    ) AS subquery
)

SELECT product_name, category, ir_pct
FROM cte
WHERE rn <= 5
ORDER BY category, ir_pct DESC;
