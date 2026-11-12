-- Identifies pairs of distinct products purchased together in the same store transaction by customers
-- with selected marital status and education level. Filters purchases over a two-year period by product
-- category, item manager, and list price. Excludes product pairs also purchased together through catalog
-- or web sales, and customers who purchased either item in a different store transaction during the
-- selected period. Returns minimum item keys for both products and the associated store ticket number
-- and item key.

define YEAR = random(1998,2000,uniform);
define CATEGORY = sulist(dist(categories,1,1), 2);
define MANAGER = range(random(1, 100, uniform), 20);
define MS = dist(marital_status, 1, 1);
define ES = dist(education, 1, 1);
define PRICE = range(random(1, 300, uniform), 5);

SELECT
    MIN(item1.i_item_sk),
    MIN(item2.i_item_sk),
    MIN(s1.ss_ticket_number),
    MIN(s1.ss_item_sk)
FROM
    item AS item1,
    item AS item2,
    store_sales AS s1,
    store_sales AS s2,
    date_dim,
    customer,
    customer_address,
    customer_demographics
WHERE
    item1.i_item_sk < item2.i_item_sk
    AND s1.ss_ticket_number = s2.ss_ticket_number
    AND s1.ss_item_sk = item1.i_item_sk
    AND s2.ss_item_sk = item2.i_item_sk
    AND s1.ss_customer_sk = c_customer_sk
    AND c_current_addr_sk = ca_address_sk
    AND c_current_cdemo_sk = cd_demo_sk
    AND d_year BETWEEN [YEAR] AND [YEAR] + 1
    AND d_date_sk = s1.ss_sold_date_sk
    AND item1.i_category IN ('[CATEGORY.1]', '[CATEGORY.2]')
    AND item2.i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
    AND cd_marital_status = '[MS]'
    AND cd_education_status = '[ES]'
    AND s1.ss_list_price BETWEEN [PRICE.begin] AND [PRICE.end]
    AND s2.ss_list_price BETWEEN [PRICE.begin] AND [PRICE.end]

    -- 1. Exclude product pairs purchased together through the catalog channel.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_sales cs1
        JOIN catalog_sales cs2
          ON cs1.cs_order_number = cs2.cs_order_number
        WHERE cs1.cs_item_sk = item1.i_item_sk
          AND cs2.cs_item_sk = item2.i_item_sk
          AND cs1.cs_bill_customer_sk = s1.ss_customer_sk
          AND cs2.cs_bill_customer_sk = s1.ss_customer_sk
    )

    -- 2. Exclude product pairs purchased together through the web channel.
    AND NOT EXISTS (
        SELECT 1
        FROM web_sales ws1
        JOIN web_sales ws2
          ON ws1.ws_order_number = ws2.ws_order_number
        WHERE ws1.ws_item_sk = item1.i_item_sk
          AND ws2.ws_item_sk = item2.i_item_sk
          AND ws1.ws_bill_customer_sk = s1.ss_customer_sk
          AND ws2.ws_bill_customer_sk = s1.ss_customer_sk
    )

    -- 3. Exclude customers who purchased either item in another store transaction
    --    during the selected period.
    AND NOT EXISTS (
        SELECT 1
        FROM store_sales ss3
        JOIN date_dim d3
          ON ss3.ss_sold_date_sk = d3.d_date_sk
        WHERE ss3.ss_customer_sk = s1.ss_customer_sk
          AND (ss3.ss_item_sk = item1.i_item_sk
               OR ss3.ss_item_sk = item2.i_item_sk)
          AND ss3.ss_ticket_number <> s1.ss_ticket_number
          AND d3.d_year BETWEEN [YEAR] AND [YEAR] + 1
    );
