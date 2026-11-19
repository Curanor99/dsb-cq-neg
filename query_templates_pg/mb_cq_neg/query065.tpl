-- Identifies underperforming products at stores within selected states over a 12-month period.
-- Calculates each store's average revenue per item and selects products whose revenue is no more
-- than 10% of that store-specific average. Filters by discount range and item manager ID, and excludes
-- products sold at any other store during the same period. Returns store names, item descriptions,
-- product prices, wholesale costs, brands, and sales revenue, ordered by store and item description.

define DMS = random(1176,1224,uniform);
define MANAGER=range(random(1, 100,uniform), 5);
define DISCOUNT = RANGE(RANDOM (0, 100, UNIFORM), 10);
define STATE=sulist(dist(fips_county,3,1),3);
define _LIMIT=100;

[_LIMITA] select [_LIMITB]
    s_store_name,
    i_item_desc,
    sc.revenue,
    i_current_price,
    i_wholesale_cost,
    i_brand
from store, item,
    (select ss_store_sk, avg(revenue) as ave
     from
         (select ss_store_sk, ss_item_sk,
                 sum(ss_sales_price) as revenue
          from store_sales, date_dim
          where ss_sold_date_sk = d_date_sk
            and d_month_seq between [DMS] and [DMS]+11
            and ss_sales_price / ss_list_price
                BETWEEN [DISCOUNT.begin] * 0.01
                    AND [DISCOUNT.end] * 0.01
          group by ss_store_sk, ss_item_sk) sa
     group by ss_store_sk) sb,
    (select ss_store_sk, ss_item_sk,
            sum(ss_sales_price) as revenue
     from store_sales, date_dim
     where ss_sold_date_sk = d_date_sk
       and d_month_seq between [DMS] and [DMS]+11
       and ss_sales_price / ss_list_price
           BETWEEN [DISCOUNT.begin] * 0.01
               AND [DISCOUNT.end] * 0.01
     group by ss_store_sk, ss_item_sk) sc
where sb.ss_store_sk = sc.ss_store_sk
  and sc.revenue <= 0.1 * sb.ave
  and s_store_sk = sc.ss_store_sk
  and i_item_sk = sc.ss_item_sk
  and i_manager_id BETWEEN [MANAGER.begin] and [MANAGER.end]
  and s_state in ('[STATE.1]','[STATE.2]','[STATE.3]')
  AND NOT EXISTS (
      SELECT 1
      FROM store_sales ss2
      JOIN date_dim d2
        ON ss2.ss_sold_date_sk = d2.d_date_sk
      WHERE ss2.ss_item_sk = sc.ss_item_sk
        AND ss2.ss_store_sk <> sc.ss_store_sk
        AND d2.d_month_seq BETWEEN [DMS] AND [DMS]+11
  )
order by s_store_name, i_item_desc
[_LIMITC];
