-- Calculates the combined catalog and web sales revenue for a selected month and year, restricted to
-- products frequently sold in physical stores (more than four sales per item per day) within specified
-- categories and manager IDs. Considers only customers whose store sales exceed 95% of the highest
-- individual customer store sales total and who have no store or web returns during the selected year.
-- Filters catalog and web transactions by wholesale cost and returns the total sales revenue across both
-- channels.

DEFINE YEAR = RANDOM(1998, 2002, UNIFORM);
DEFINE MONTH = RANDOM(1, 12, UNIFORM);
DEFINE TOPPERCENT = RANDOM(95, 95, UNIFORM);
DEFINE WHOLESALE_COST = RANGE(RANDOM(0, 100, UNIFORM), 10);
DEFINE BIRTH_YEAR = RANGE(RANDOM(1925, 1993, UNIFORM), 10);
DEFINE MANAGER = RANGE(RANDOM(1, 100, UNIFORM), 20);
DEFINE CATEGORY = SULIST(DIST(categories, 1, 1), 3);

DEFINE _LIMIT = 100;

WITH frequent_ss_items AS (
    SELECT
        SUBSTRING(i_item_desc, 1, 30) AS itemdesc,
        i_item_sk AS item_sk,
        d_date AS solddate,
        COUNT(*) AS cnt
    FROM
        store_sales,
        date_dim,
        item
    WHERE
        ss_sold_date_sk = d_date_sk
        AND ss_item_sk = i_item_sk
        AND d_year = [YEAR]
        AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
        AND i_category IN (
            '[CATEGORY.1]',
            '[CATEGORY.2]',
            '[CATEGORY.3]'
        )
    GROUP BY
        SUBSTRING(i_item_desc, 1, 30),
        i_item_sk,
        d_date
    HAVING
        COUNT(*) > 4
),

max_store_sales AS (
    SELECT
        MAX(csales) AS tpcds_cmax
    FROM (
        SELECT
            c_customer_sk,
            SUM(ss_quantity * ss_sales_price) AS csales
        FROM
            store_sales,
            customer,
            date_dim
        WHERE
            ss_customer_sk = c_customer_sk
            AND ss_sold_date_sk = d_date_sk
            AND d_year = [YEAR]
            AND ss_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
        GROUP BY
            c_customer_sk
    ) tmp1
),

best_ss_customer AS (
    SELECT
        c_customer_sk,
        SUM(ss_quantity * ss_sales_price) AS ssales
    FROM
        store_sales,
        customer
    WHERE
        ss_customer_sk = c_customer_sk
        AND c_birth_year BETWEEN
            [BIRTH_YEAR.begin] AND [BIRTH_YEAR.end]

        -- Exclude customers with store returns during the selected year.
        AND NOT EXISTS (
            SELECT 1
            FROM
                store_returns sr
                JOIN date_dim rd
                    ON sr.sr_returned_date_sk = rd.d_date_sk
            WHERE
                sr.sr_customer_sk = c_customer_sk
                AND rd.d_year = [YEAR]
        )

        -- Exclude customers with web returns during the selected year.
        AND NOT EXISTS (
            SELECT 1
            FROM
                web_returns wr
                JOIN date_dim wd
                    ON wr.wr_returned_date_sk = wd.d_date_sk
            WHERE
                wr.wr_returning_customer_sk = c_customer_sk
                AND wd.d_year = [YEAR]
        )

    GROUP BY
        c_customer_sk
    HAVING
        SUM(ss_quantity * ss_sales_price) >
        ([TOPPERCENT] / 100.0) * (
            SELECT *
            FROM max_store_sales
        )
)

[_LIMITA]
SELECT [_LIMITB]
    SUM(sales)
FROM (
    SELECT
        cs_quantity * cs_list_price AS sales
    FROM
        catalog_sales,
        date_dim
    WHERE
        d_year = [YEAR]
        AND d_moy = [MONTH]
        AND cs_sold_date_sk = d_date_sk
        AND cs_item_sk IN (
            SELECT item_sk
            FROM frequent_ss_items
        )
        AND cs_bill_customer_sk IN (
            SELECT c_customer_sk
            FROM best_ss_customer
        )
        AND cs_wholesale_cost BETWEEN
            [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

    UNION ALL

    SELECT
        ws_quantity * ws_list_price AS sales
    FROM
        web_sales,
        date_dim
    WHERE
        d_year = [YEAR]
        AND d_moy = [MONTH]
        AND ws_sold_date_sk = d_date_sk
        AND ws_item_sk IN (
            SELECT item_sk
            FROM frequent_ss_items
        )
        AND ws_bill_customer_sk IN (
            SELECT c_customer_sk
            FROM best_ss_customer
        )
        AND ws_wholesale_cost BETWEEN
            [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
) tmp2

[_LIMITC];