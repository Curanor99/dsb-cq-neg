-- Identifies catalog sales orders where inventory at the corresponding warehouse was insufficient to
-- fulfill the ordered quantity during the same week as the sale. Filters by year, item category,
-- wholesale cost, customer marital status, dependent count, and household buying potential. Requires
-- shipment to occur more than three days after the sale and excludes orders with catalog returns,
-- items also sold through the web channel during the selected year, and items experiencing inventory
-- shortages at other warehouses during the same week. Returns minimum item keys, warehouse name,
-- week sequence, and order number.

define YEAR = random(1998, 2002, uniform);
define BP = text({"1001-5000",1},{">10000",1},{"501-1000",1});
define MS = dist(marital_status, 1, 1);
define DEP_COUNT = range(random(0, 9, uniform), 30);
define CATEGORY = sulist(dist(categories,1,1), 3);
define WHOLESALE_COST = range(random(0, 100, uniform), 20);

SELECT
    MIN(i.i_item_sk),
    MIN(w.w_warehouse_name),
    MIN(d1.d_week_seq),
    MIN(cs.cs_item_sk),
    MIN(cs.cs_order_number),
    MIN(inv.inv_item_sk)
FROM catalog_sales cs
JOIN inventory inv
    ON cs.cs_item_sk = inv.inv_item_sk
JOIN warehouse w
    ON w.w_warehouse_sk = inv.inv_warehouse_sk
JOIN item i
    ON i.i_item_sk = cs.cs_item_sk
JOIN customer_demographics cd
    ON cs.cs_bill_cdemo_sk = cd.cd_demo_sk
JOIN household_demographics hd
    ON cs.cs_bill_hdemo_sk = hd.hd_demo_sk
JOIN date_dim d1
    ON cs.cs_sold_date_sk = d1.d_date_sk
JOIN date_dim d2
    ON inv.inv_date_sk = d2.d_date_sk
JOIN date_dim d3
    ON cs.cs_ship_date_sk = d3.d_date_sk
LEFT OUTER JOIN promotion p
    ON cs.cs_promo_sk = p.p_promo_sk
WHERE
    d1.d_week_seq = d2.d_week_seq
    AND inv.inv_quantity_on_hand < cs.cs_quantity
    AND d3.d_date > d1.d_date + INTERVAL '3 day'
    AND hd.hd_buy_potential = '[BP]'
    AND d1.d_year = [YEAR]
    AND cd.cd_marital_status = '[MS]'
    AND cd.cd_dep_count BETWEEN [DEP_COUNT.begin] AND [DEP_COUNT.end]
    AND i.i_category IN ('[CATEGORY.1]', '[CATEGORY.2]', '[CATEGORY.3]')
    AND cs.cs_wholesale_cost BETWEEN [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

    -- 1. Exclude catalog orders that were returned.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_returns cr
        WHERE cr.cr_item_sk = cs.cs_item_sk
          AND cr.cr_order_number = cs.cs_order_number
    )

    -- 2. Exclude items also sold through the web channel in the selected year.
    AND NOT EXISTS (
        SELECT 1
        FROM web_sales ws
        JOIN date_dim dw
            ON ws.ws_sold_date_sk = dw.d_date_sk
        WHERE ws.ws_item_sk = cs.cs_item_sk
          AND dw.d_year = [YEAR]
    )

    -- 3. Exclude items with an inventory shortage at another warehouse
    --    during the same week.
    AND NOT EXISTS (
        SELECT 1
        FROM inventory inv2
        JOIN date_dim d4
            ON inv2.inv_date_sk = d4.d_date_sk
        WHERE inv2.inv_item_sk = cs.cs_item_sk
          AND d4.d_week_seq = d1.d_week_seq
          AND inv2.inv_warehouse_sk <> inv.inv_warehouse_sk
          AND inv2.inv_quantity_on_hand < cs.cs_quantity
    );