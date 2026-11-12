-- Analyzes customer demographics by grouping customers according to gender, marital status, education,
-- purchase estimate, credit rating, and dependent information. Filters customers by county and birth month,
-- requiring purchases in physical stores and online during a specified year and four-month period, within
-- selected product categories, manager IDs, and discount ranges, while excluding customers who made matching
-- catalog purchases. Returns demographic group counts, ordered by the grouping attributes.

define COUNTY = sulist(dist(fips_county, 2, 1), 5);
define MONTH = random(1, 9, uniform);
define YEAR = random(1998, 2002, uniform);
define BIRTH_MONTH = sulist(random(1, 12, uniform), 2);
define CATEGORY = sulist(dist(categories, 1, 1), 3);
define DISCOUNT = RANGE(RANDOM(0, 100, UNIFORM), 10);
define MANAGER = range(random(1, 100, uniform), 10);
define MS = list(dist(marital_status, 1, 1), 3);
define ES = list(dist(education, 1, 1), 3);
define GEN = dist(gender, 1, 1);

define _LIMIT = 100;

[_LIMITA]
SELECT [_LIMITB]
    cd_gender,
    cd_marital_status,
    cd_education_status,
    COUNT(*) cnt1,
    cd_purchase_estimate,
    COUNT(*) cnt2,
    cd_credit_rating,
    COUNT(*) cnt3,
    cd_dep_count,
    COUNT(*) cnt4,
    cd_dep_employed_count,
    COUNT(*) cnt5,
    cd_dep_college_count,
    COUNT(*) cnt6
FROM
    customer c,
    customer_address ca,
    customer_demographics
WHERE
    c.c_current_addr_sk = ca.ca_address_sk
    AND ca_county IN (
        '[COUNTY.1]',
        '[COUNTY.2]',
        '[COUNTY.3]',
        '[COUNTY.4]',
        '[COUNTY.5]'
    )
    AND c.c_birth_month IN (
        [BIRTH_MONTH.1],
        [BIRTH_MONTH.2]
    )
    AND cd_demo_sk = c.c_current_cdemo_sk
    AND cd_marital_status IN (
        '[MS.1]',
        '[MS.2]',
        '[MS.3]'
    )
    AND cd_education_status IN (
        '[ES.1]',
        '[ES.2]',
        '[ES.3]'
    )
    AND cd_gender = '[GEN]'
    AND EXISTS (
        SELECT *
        FROM
            store_sales,
            date_dim,
            item
        WHERE
            c.c_customer_sk = ss_customer_sk
            AND ss_sold_date_sk = d_date_sk
            AND d_year = [YEAR]
            AND d_moy BETWEEN [MONTH] AND [MONTH] + 3
            AND ss_item_sk = i_item_sk
            AND i_category IN (
                '[CATEGORY.1]',
                '[CATEGORY.2]',
                '[CATEGORY.3]'
            )
            AND ss_sales_price / ss_list_price
                BETWEEN [DISCOUNT.begin] * 0.01
                    AND [DISCOUNT.end] * 0.01
            AND i_manager_id
                BETWEEN [MANAGER.begin] AND [MANAGER.end]
    )
    AND (
        EXISTS (
            SELECT *
            FROM
                web_sales,
                date_dim,
                item
            WHERE
                c.c_customer_sk = ws_bill_customer_sk
                AND ws_sold_date_sk = d_date_sk
                AND d_year = [YEAR]
                AND d_moy BETWEEN [MONTH] AND [MONTH] + 3
                AND ws_item_sk = i_item_sk
                AND i_category IN (
                    '[CATEGORY.1]',
                    '[CATEGORY.2]',
                    '[CATEGORY.3]'
                )
                AND i_manager_id
                    BETWEEN [MANAGER.begin] AND [MANAGER.end]
                AND ws_sales_price / ws_list_price
                    BETWEEN [DISCOUNT.begin] * 0.01
                        AND [DISCOUNT.end] * 0.01
        )
        AND NOT EXISTS (
            SELECT *
            FROM
                catalog_sales,
                date_dim,
                item
            WHERE
                c.c_customer_sk = cs_ship_customer_sk
                AND cs_sold_date_sk = d_date_sk
                AND d_year = [YEAR]
                AND d_moy BETWEEN [MONTH] AND [MONTH] + 3
                AND cs_item_sk = i_item_sk
                AND i_category IN (
                    '[CATEGORY.1]',
                    '[CATEGORY.2]',
                    '[CATEGORY.3]'
                )
                AND i_manager_id
                    BETWEEN [MANAGER.begin] AND [MANAGER.end]
                AND cs_sales_price / cs_list_price
                    BETWEEN [DISCOUNT.begin] * 0.01
                        AND [DISCOUNT.end] * 0.01
        )
    )
GROUP BY
    cd_gender,
    cd_marital_status,
    cd_education_status,
    cd_purchase_estimate,
    cd_credit_rating,
    cd_dep_count,
    cd_dep_employed_count,
    cd_dep_college_count
ORDER BY
    cd_gender,
    cd_marital_status,
    cd_education_status,
    cd_purchase_estimate,
    cd_credit_rating,
    cd_dep_count,
    cd_dep_employed_count,
    cd_dep_college_count
[_LIMITC];