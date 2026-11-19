-- Analyzes catalog returns processed by call centers during a selected month and year, filtering customers
-- by specific marital status and education combinations, household buying potential, and address GMT offset.
-- Excludes customers who returned the same item through the web channel or purchased it through the catalog
-- during the selected year, as well as customers who returned the same item through another call center
-- during the selected month. Returns minimum call center identifiers, names, manager names, return net losses,
-- item keys, and order numbers.

define YEAR = random(1998,2002, uniform);
define MONTH = random(1,12,uniform);
define BUY_POTENTIAL = text({"1001-5000",1},{">10000",1},{"501-1000",1},{"0-500",1},{"Unknown",1},{"5001-10000",1});
define GMT = text({"-6",1},{"-7",1});

SELECT
    MIN(cc.cc_call_center_id),
    MIN(cc.cc_name),
    MIN(cc.cc_manager),
    MIN(cr.cr_net_loss),
    MIN(cr.cr_item_sk),
    MIN(cr.cr_order_number)
FROM
    call_center cc,
    catalog_returns cr,
    date_dim d,
    customer c,
    customer_address ca,
    customer_demographics cd,
    household_demographics hd
WHERE
    cr.cr_call_center_sk = cc.cc_call_center_sk
    AND cr.cr_returned_date_sk = d.d_date_sk
    AND cr.cr_returning_customer_sk = c.c_customer_sk
    AND cd.cd_demo_sk = c.c_current_cdemo_sk
    AND hd.hd_demo_sk = c.c_current_hdemo_sk
    AND ca.ca_address_sk = c.c_current_addr_sk
    AND d.d_year = [YEAR]
    AND d.d_moy = [MONTH]
    AND (
        (cd.cd_marital_status = 'M'
         AND cd.cd_education_status = 'Unknown')
        OR
        (cd.cd_marital_status = 'W'
         AND cd.cd_education_status = 'Advanced Degree')
    )
    AND hd.hd_buy_potential LIKE '[BUY_POTENTIAL]%'
    AND ca.ca_gmt_offset = [GMT]

    -- 1. Exclude customers who returned the same item through the web channel.
    AND NOT EXISTS (
        SELECT 1
        FROM web_returns wr
        JOIN date_dim dw
          ON wr.wr_returned_date_sk = dw.d_date_sk
        WHERE wr.wr_returning_customer_sk = cr.cr_returning_customer_sk
          AND wr.wr_item_sk = cr.cr_item_sk
          AND dw.d_year = [YEAR]
    )

    -- 2. Exclude customers who purchased the same item through the catalog
    --    during the selected year.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_sales cs
        JOIN date_dim ds
          ON cs.cs_sold_date_sk = ds.d_date_sk
        WHERE cs.cs_bill_customer_sk = cr.cr_returning_customer_sk
          AND cs.cs_item_sk = cr.cr_item_sk
          AND ds.d_year = [YEAR]
    )

    -- 3. Exclude customers who returned the same item through another
    --    call center during the selected month and year.
    AND NOT EXISTS (
        SELECT 1
        FROM catalog_returns cr2
        JOIN date_dim d2
          ON cr2.cr_returned_date_sk = d2.d_date_sk
        WHERE cr2.cr_returning_customer_sk = cr.cr_returning_customer_sk
          AND cr2.cr_item_sk = cr.cr_item_sk
          AND cr2.cr_call_center_sk <> cr.cr_call_center_sk
          AND d2.d_year = [YEAR]
          AND d2.d_moy = [MONTH]
    );
