-- Analyzes store transactions involving items that were subsequently returned and also purchased through
-- the catalog sales channel by the same customer. Matches store sales, store returns, and catalog sales
-- using customer, item, and transaction identifiers within a selected year and overlapping three-month
-- periods. Excludes customers who purchased or returned the same item through the web channel during the
-- selected year, as well as customers who repurchased the item in a store after the catalog sale.
-- Returns minimum values for item, store, sales, return, and transaction attributes.

define YEAR= random(1998,2002, uniform);
define MONTH= random(1,10, uniform);

SELECT
    MIN(i.i_item_id),
    MIN(i.i_item_desc),
    MIN(s.s_store_id),
    MIN(s.s_store_name),
    MIN(ss.ss_net_profit),
    MIN(sr.sr_net_loss),
    MIN(cs.cs_net_profit),
    MIN(ss.ss_item_sk),
    MIN(sr.sr_ticket_number),
    MIN(cs.cs_order_number)
FROM
    store_sales ss,
    store_returns sr,
    catalog_sales cs,
    date_dim d1,
    date_dim d2,
    date_dim d3,
    store s,
    item i
WHERE
    d1.d_moy = [MONTH]
    AND d1.d_year = [YEAR]
    AND d1.d_date_sk = ss.ss_sold_date_sk
    AND i.i_item_sk = ss.ss_item_sk
    AND s.s_store_sk = ss.ss_store_sk

    AND ss.ss_customer_sk = sr.sr_customer_sk
    AND ss.ss_item_sk = sr.sr_item_sk
    AND ss.ss_ticket_number = sr.sr_ticket_number

    AND sr.sr_returned_date_sk = d2.d_date_sk
    AND d2.d_moy BETWEEN [MONTH] AND [MONTH] + 2
    AND d2.d_year = [YEAR]

    AND sr.sr_customer_sk = cs.cs_bill_customer_sk
    AND sr.sr_item_sk = cs.cs_item_sk
    AND cs.cs_sold_date_sk = d3.d_date_sk
    AND d3.d_moy BETWEEN [MONTH] AND [MONTH] + 2
    AND d3.d_year = [YEAR]

    -- 1. Exclude customers who also purchased the same item online.
    AND NOT EXISTS (
        SELECT 1
        FROM web_sales ws
        JOIN date_dim dw
          ON ws.ws_sold_date_sk = dw.d_date_sk
        WHERE ws.ws_bill_customer_sk = ss.ss_customer_sk
          AND ws.ws_item_sk = ss.ss_item_sk
          AND dw.d_year = [YEAR]
    )

    -- 2. Exclude customers who returned the same item through the web channel.
    AND NOT EXISTS (
        SELECT 1
        FROM web_returns wr
        JOIN date_dim dwr
          ON wr.wr_returned_date_sk = dwr.d_date_sk
        WHERE wr.wr_returning_customer_sk = ss.ss_customer_sk
          AND wr.wr_item_sk = ss.ss_item_sk
          AND dwr.d_year = [YEAR]
    )

    -- 3. Exclude customers who subsequently repurchased the same item in a store.
    AND NOT EXISTS (
        SELECT 1
        FROM store_sales ss2
        JOIN date_dim ds2
          ON ss2.ss_sold_date_sk = ds2.d_date_sk
        WHERE ss2.ss_customer_sk = ss.ss_customer_sk
          AND ss2.ss_item_sk = ss.ss_item_sk
          AND ds2.d_year = [YEAR]
          AND ds2.d_date > d3.d_date
    );