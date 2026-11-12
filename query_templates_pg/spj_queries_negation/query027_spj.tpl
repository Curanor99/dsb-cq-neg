-- Calculates minimum values for item, store, and sales attributes from store transactions in a selected
-- year. Filters transactions by customer gender, marital status, education level, store state, and item
-- category. Excludes customers who purchased the same item through web sales or made any store returns
-- during the selected year, and excludes items sold at a different store during that year. Returns minimum
-- item ID, store state, quantity, list price, coupon amount, sales price, item key, and ticket number.

define YEAR = random(1998, 2002, uniform);
define GEN = dist(gender, 1, 1);
define MS = dist(marital_status, 1, 1);
define ES = dist(education, 1, 1);
define STATE = dist(fips_county, 3, 1);
define CATEGORY = dist(categories, 1, 1);

SELECT
    MIN(i_item_id),
    MIN(s_state),
    MIN(ss_quantity),
    MIN(ss_list_price),
    MIN(ss_coupon_amt),
    MIN(ss_sales_price),
    MIN(ss_item_sk),
    MIN(ss_ticket_number)
FROM
    store_sales ss,
    customer_demographics,
    date_dim,
    store,
    item
WHERE
    ss_sold_date_sk = d_date_sk
    AND ss_item_sk = i_item_sk
    AND ss_store_sk = s_store_sk
    AND ss_cdemo_sk = cd_demo_sk
    AND cd_gender = '[GEN]'
    AND cd_marital_status = '[MS]'
    AND cd_education_status = '[ES]'
    AND d_year = [YEAR]
    AND s_state = '[STATE]'
    AND i_category = '[CATEGORY]'

    -- 1. Exclude customers who purchased the same item through web sales
    AND NOT EXISTS (
        SELECT 1
        FROM web_sales ws
        WHERE ws.ws_bill_customer_sk = ss.ss_customer_sk
          AND ws.ws_item_sk = ss.ss_item_sk
    )

    -- 3. Exclude customers who made store returns during the selected year
    AND NOT EXISTS (
        SELECT 1
        FROM store_returns sr,
             date_dim rd
        WHERE sr.sr_returned_date_sk = rd.d_date_sk
          AND sr.sr_customer_sk = ss.ss_customer_sk
          AND rd.d_year = [YEAR]
    )

    -- 4. Exclude items sold at another store during the selected year
    AND NOT EXISTS (
        SELECT 1
        FROM store_sales ss2,
             date_dim d2
        WHERE ss2.ss_item_sk = ss.ss_item_sk
          AND ss2.ss_store_sk <> ss.ss_store_sk
          AND ss2.ss_sold_date_sk = d2.d_date_sk
          AND d2.d_year = [YEAR]
    );