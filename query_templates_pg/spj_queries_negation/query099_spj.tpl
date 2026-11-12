-- Analyzes catalog sales shipments over a selected 24-month period, filtering by list price, shipping
-- mode type, call center class, and warehouse GMT offset. Excludes catalog orders with returns, items
-- also sold through the web channel during the same period, and customers who ordered the same item
-- using a different shipping mode. Returns minimum warehouse name, shipping mode type, call center name,
-- catalog order number, and item key.

define DMS = random(1176,1212, uniform);
define PRICE = range(random(1, 300, uniform), 10);
define MODE_TYPE = dist(ship_mode_type, 1, 1);
define CLASS = dist(call_center_class, 1, 1);
define GMT_OFFSET = random(-5, -7, uniform);

SELECT
    MIN(w.w_warehouse_name),
    MIN(sm.sm_type),
    MIN(cc.cc_name),
    MIN(cs.cs_order_number),
    MIN(cs.cs_item_sk)
FROM
    catalog_sales cs
    JOIN warehouse w
        ON cs.cs_warehouse_sk = w.w_warehouse_sk
    JOIN ship_mode sm
        ON cs.cs_ship_mode_sk = sm.sm_ship_mode_sk
    JOIN call_center cc
        ON cs.cs_call_center_sk = cc.cc_call_center_sk
    JOIN date_dim d
        ON cs.cs_ship_date_sk = d.d_date_sk
WHERE
    d.d_month_seq BETWEEN [DMS] AND [DMS] + 23
    AND cs.cs_list_price BETWEEN [PRICE.begin] AND [PRICE.end]
    AND sm.sm_type = '[MODE_TYPE]'
    AND cc.cc_class = '[CLASS]'
    AND w.w_gmt_offset = [GMT_OFFSET]

    -- 1. Exclude catalog orders that were returned.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_returns cr
        WHERE cr.cr_order_number = cs.cs_order_number
          AND cr.cr_item_sk = cs.cs_item_sk
    )

    -- 2. Exclude items also sold through the web channel
    --    during the selected 24-month period.
    AND NOT EXISTS (
        SELECT 1
        FROM web_sales ws
        JOIN date_dim dw
            ON ws.ws_sold_date_sk = dw.d_date_sk
        WHERE ws.ws_item_sk = cs.cs_item_sk
          AND dw.d_month_seq BETWEEN [DMS] AND [DMS] + 23
    )

    -- 3. Exclude customers who ordered the same item through
    --    a different shipping mode during the selected period.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_sales cs2
        JOIN date_dim d2
            ON cs2.cs_ship_date_sk = d2.d_date_sk
        WHERE cs2.cs_bill_customer_sk = cs.cs_bill_customer_sk
          AND cs2.cs_item_sk = cs.cs_item_sk
          AND cs2.cs_ship_mode_sk <> cs.cs_ship_mode_sk
          AND d2.d_month_seq BETWEEN [DMS] AND [DMS] + 23
    );
