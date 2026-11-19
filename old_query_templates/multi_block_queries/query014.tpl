```sql
--
-- Legal Notice
--
-- This document and associated source code (the "Work") is a part of a
-- benchmark specification maintained by the TPC.
--
-- The TPC reserves all right, title, and interest to the Work as provided
-- under U.S. and international laws, including without limitation all patent
-- and trademark rights therein.
--
-- No Warranty
--
-- 1.1 TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE INFORMATION
--     CONTAINED HEREIN IS PROVIDED "AS IS" AND WITH ALL FAULTS, AND THE
--     AUTHORS AND DEVELOPERS OF THE WORK HEREBY DISCLAIM ALL OTHER
--     WARRANTIES AND CONDITIONS, EITHER EXPRESS, IMPLIED OR STATUTORY,
--     INCLUDING, BUT NOT LIMITED TO, ANY (IF ANY) IMPLIED WARRANTIES,
--     DUTIES OR CONDITIONS OF MERCHANTABILITY, OF FITNESS FOR A PARTICULAR
--     PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OF
--     WORKMANLIKE EFFORT, OF LACK OF VIRUSES, AND OF LACK OF NEGLIGENCE.
--     ALSO, THERE IS NO WARRANTY OR CONDITION OF TITLE, QUIET ENJOYMENT,
--     QUIET POSSESSION, CORRESPONDENCE TO DESCRIPTION OR NON-INFRINGEMENT
--     WITH REGARD TO THE WORK.
-- 1.2 IN NO EVENT WILL ANY AUTHOR OR DEVELOPER OF THE WORK BE LIABLE TO
--     ANY OTHER PARTY FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO THE
--     COST OF PROCURING SUBSTITUTE GOODS OR SERVICES, LOST PROFITS, LOSS
--     OF USE, LOSS OF DATA, OR ANY INCIDENTAL, CONSEQUENTIAL, DIRECT,
--     INDIRECT, OR SPECIAL DAMAGES WHETHER UNDER CONTRACT, TORT, WARRANTY,
--     OR OTHERWISE, ARISING IN ANY WAY OUT OF THIS OR ANY OTHER AGREEMENT
--     RELATING TO THE WORK, WHETHER OR NOT SUCH AUTHOR OR DEVELOPER HAD
--     ADVANCE NOTICE OF THE POSSIBILITY OF SUCH DAMAGES.
--
-- Contributors:
--

DEFINE YEAR = RANDOM(1998, 2000, UNIFORM);
DEFINE DAY = RANDOM(1, 28, UNIFORM);
DEFINE CATEGORY = SULIST(DIST(categories, 1, 1), 3);
DEFINE MANAGER = RANGE(RANDOM(1, 100, UNIFORM), 10);
DEFINE WHOLESALE_COST = RANGE(RANDOM(0, 100, UNIFORM), 20);

DEFINE _LIMIT = 100;

WITH cross_items AS (
    SELECT
        i_item_sk AS ss_item_sk
    FROM
        item,
        (
            SELECT
                iss.i_brand_id AS brand_id,
                iss.i_class_id AS class_id,
                iss.i_category_id AS category_id
            FROM
                store_sales,
                item iss,
                date_dim d1
            WHERE
                ss_item_sk = iss.i_item_sk
                AND ss_sold_date_sk = d1.d_date_sk
                AND d1.d_year BETWEEN [YEAR] AND [YEAR] + 2
                AND i_category IN (
                    '[CATEGORY.1]',
                    '[CATEGORY.2]',
                    '[CATEGORY.3]'
                )
                AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
                AND ss_wholesale_cost BETWEEN
                    [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

            INTERSECT

            SELECT
                ics.i_brand_id,
                ics.i_class_id,
                ics.i_category_id
            FROM
                catalog_sales,
                item ics,
                date_dim d2
            WHERE
                cs_item_sk = ics.i_item_sk
                AND cs_sold_date_sk = d2.d_date_sk
                AND d2.d_year BETWEEN [YEAR] AND [YEAR] + 2
                AND i_category IN (
                    '[CATEGORY.1]',
                    '[CATEGORY.2]',
                    '[CATEGORY.3]'
                )
                AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
                AND cs_wholesale_cost BETWEEN
                    [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

            INTERSECT

            SELECT
                iws.i_brand_id,
                iws.i_class_id,
                iws.i_category_id
            FROM
                web_sales,
                item iws,
                date_dim d3
            WHERE
                ws_item_sk = iws.i_item_sk
                AND ws_sold_date_sk = d3.d_date_sk
                AND ws_wholesale_cost BETWEEN
                    [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
                AND d3.d_year BETWEEN [YEAR] AND [YEAR] + 2
        ) x
    WHERE
        i_brand_id = brand_id
        AND i_class_id = class_id
        AND i_category_id = category_id
        AND i_category IN (
            '[CATEGORY.1]',
            '[CATEGORY.2]',
            '[CATEGORY.3]'
        )
        AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
),

avg_sales AS (
    SELECT
        AVG(quantity * list_price) AS average_sales
    FROM (
        SELECT
            ss_quantity AS quantity,
            ss_list_price AS list_price
        FROM
            store_sales,
            date_dim
        WHERE
            ss_sold_date_sk = d_date_sk
            AND d_year BETWEEN [YEAR] AND [YEAR] + 2
            AND ss_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

        UNION ALL

        SELECT
            cs_quantity AS quantity,
            cs_list_price AS list_price
        FROM
            catalog_sales,
            date_dim
        WHERE
            cs_sold_date_sk = d_date_sk
            AND d_year BETWEEN [YEAR] AND [YEAR] + 2
            AND cs_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]

        UNION ALL

        SELECT
            ws_quantity AS quantity,
            ws_list_price AS list_price
        FROM
            web_sales,
            date_dim
        WHERE
            ws_sold_date_sk = d_date_sk
            AND ws_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
            AND d_year BETWEEN [YEAR] AND [YEAR] + 2
    ) x
)

[_LIMITA]
SELECT [_LIMITB]
    this_year.channel AS ty_channel,
    this_year.i_brand_id AS ty_brand,
    this_year.i_class_id AS ty_class,
    this_year.i_category_id AS ty_category,
    this_year.sales AS ty_sales,
    this_year.number_sales AS ty_number_sales,
    last_year.channel AS ly_channel,
    last_year.i_brand_id AS ly_brand,
    last_year.i_class_id AS ly_class,
    last_year.i_category_id AS ly_category,
    last_year.sales AS ly_sales,
    last_year.number_sales AS ly_number_sales
FROM
    (
        SELECT
            'store' AS channel,
            i_brand_id,
            i_class_id,
            i_category_id,
            SUM(ss_quantity * ss_list_price) AS sales,
            COUNT(*) AS number_sales
        FROM
            store_sales,
            item,
            date_dim
        WHERE
            ss_item_sk IN (
                SELECT ss_item_sk
                FROM cross_items
            )
            AND ss_item_sk = i_item_sk
            AND ss_sold_date_sk = d_date_sk
            AND d_week_seq = (
                SELECT d_week_seq
                FROM date_dim
                WHERE
                    d_year = [YEAR] + 1
                    AND d_moy = 12
                    AND d_dom = [DAY]
            )
            AND i_category IN (
                '[CATEGORY.1]',
                '[CATEGORY.2]',
                '[CATEGORY.3]'
            )
            AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
            AND ss_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
        GROUP BY
            i_brand_id,
            i_class_id,
            i_category_id
        HAVING
            SUM(ss_quantity * ss_list_price) > (
                SELECT average_sales
                FROM avg_sales
            )
    ) this_year,

    (
        SELECT
            'store' AS channel,
            i_brand_id,
            i_class_id,
            i_category_id,
            SUM(ss_quantity * ss_list_price) AS sales,
            COUNT(*) AS number_sales
        FROM
            store_sales,
            item,
            date_dim
        WHERE
            ss_item_sk IN (
                SELECT ss_item_sk
                FROM cross_items
            )
            AND ss_item_sk = i_item_sk
            AND ss_sold_date_sk = d_date_sk
            AND d_week_seq = (
                SELECT d_week_seq
                FROM date_dim
                WHERE
                    d_year = [YEAR]
                    AND d_moy = 12
                    AND d_dom = [DAY]
            )
            AND i_category IN (
                '[CATEGORY.1]',
                '[CATEGORY.2]',
                '[CATEGORY.3]'
            )
            AND ss_wholesale_cost BETWEEN
                [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
            AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
        GROUP BY
            i_brand_id,
            i_class_id,
            i_category_id
        HAVING
            SUM(ss_quantity * ss_list_price) > (
                SELECT average_sales
                FROM avg_sales
            )
    ) last_year

WHERE
    this_year.i_brand_id = last_year.i_brand_id
    AND this_year.i_class_id = last_year.i_class_id
    AND this_year.i_category_id = last_year.i_category_id

ORDER BY
    this_year.channel,
    this_year.i_brand_id,
    this_year.i_class_id,
    this_year.i_category_id

[_LIMITC];
```