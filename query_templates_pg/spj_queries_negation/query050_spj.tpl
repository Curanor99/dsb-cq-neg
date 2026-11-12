-- Analyzes store purchases that were subsequently returned at the same store within a 120-day period.
-- Filters transactions by return month, purchase day of the week, and store state, matching purchases
-- and returns by customer, item, ticket number, and store. Excludes cases where the customer also returned
-- the same item through the web channel or purchased it at another store between the original purchase
-- and the return. Returns minimum values for store address details, transaction identifiers, item keys,
-- and purchase and return dates.

define MONTH = random(1,12,uniform);
define STATE = sulist(dist(fips_county,3,1),3);
define DAY = random(1,7,uniform);

SELECT
    MIN(s.s_store_name),
    MIN(s.s_company_id),
    MIN(s.s_street_number),
    MIN(s.s_street_name),
    MIN(s.s_suite_number),
    MIN(s.s_city),
    MIN(s.s_zip),
    MIN(ss.ss_ticket_number),
    MIN(ss.ss_sold_date_sk),
    MIN(sr.sr_returned_date_sk),
    MIN(ss.ss_item_sk),
    MIN(d1.d_date_sk)
FROM
    store_sales ss,
    store_returns sr,
    store s,
    date_dim d1,
    date_dim d2
WHERE
    d2.d_moy = [MONTH]
    AND ss.ss_ticket_number = sr.sr_ticket_number
    AND ss.ss_item_sk = sr.sr_item_sk
    AND ss.ss_sold_date_sk = d1.d_date_sk
    AND sr.sr_returned_date_sk = d2.d_date_sk
    AND ss.ss_customer_sk = sr.sr_customer_sk
    AND ss.ss_store_sk = s.s_store_sk
    AND sr.sr_store_sk = s.s_store_sk
    AND d1.d_date BETWEEN (d2.d_date - INTERVAL '120 day')
                      AND d2.d_date
    AND d1.d_dow = [DAY]
    AND s.s_state IN ('[STATE.1]', '[STATE.2]', '[STATE.3]')

    -- 1. Exclude customers who also returned the same item online.
    AND NOT EXISTS (
        SELECT 1
        FROM web_returns wr
        JOIN date_dim dw
          ON wr.wr_returned_date_sk = dw.d_date_sk
        WHERE wr.wr_returning_customer_sk = ss.ss_customer_sk
          AND wr.wr_item_sk = ss.ss_item_sk
          AND dw.d_date BETWEEN d1.d_date AND d2.d_date
    )

    -- 2. Exclude customers who purchased the same item at another store
    --    between the original purchase and the return.
    AND NOT EXISTS (
        SELECT 1
        FROM store_sales ss2
        JOIN date_dim ds2
          ON ss2.ss_sold_date_sk = ds2.d_date_sk
        WHERE ss2.ss_customer_sk = ss.ss_customer_sk
          AND ss2.ss_item_sk = ss.ss_item_sk
          AND ss2.ss_store_sk <> ss.ss_store_sk
          AND ds2.d_date BETWEEN d1.d_date AND d2.d_date
    );