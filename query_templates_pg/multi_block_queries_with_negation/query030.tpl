-- Identifies customers whose total web return amount exceeds the state-specific average by more than 20%.
-- Analyzes returns from a selected year, filtering by item manager, return amount per unit, return reason,
-- customer state, and birth year. Excludes customers who made any store returns during the selected year.
-- Returns detailed customer information together with their total web return amount, ordered by customer
-- and return details.

DEFINE STATE = SULIST(DIST(fips_county, 3, 1), 4);
DEFINE YEAR = RANDOM(1998, 2002, UNIFORM);
DEFINE REASON = SULIST(RANDOM(1, 75, UNIFORM), 2);
DEFINE MANAGER = RANGE(RANDOM(1, 100, UNIFORM), 10);
DEFINE PRICE = RANGE(RANDOM(1, 300, UNIFORM), 10);
DEFINE BIRTH_YEAR = RANGE(RANDOM(1925, 1993, UNIFORM), 10);

DEFINE _LIMIT = 100;

WITH customer_total_return AS (
    SELECT
        wr_returning_customer_sk AS ctr_customer_sk,
        ca_state AS ctr_state,
        wr_reason_sk AS ctr_reason_sk,
        SUM(wr_return_amt) AS ctr_total_return
    FROM
        web_returns,
        date_dim,
        customer_address,
        item
    WHERE
        wr_returned_date_sk = d_date_sk
        AND d_year = [YEAR]
        AND wr_returning_addr_sk = ca_address_sk
        AND wr_item_sk = i_item_sk
        AND i_manager_id BETWEEN [MANAGER.begin] AND [MANAGER.end]
        AND wr_return_amt / wr_return_quantity
            BETWEEN [PRICE.begin] AND [PRICE.end]
    GROUP BY
        wr_returning_customer_sk,
        ca_state,
        wr_reason_sk
)

[_LIMITA]
SELECT [_LIMITB]
    c_customer_id,
    c_salutation,
    c_first_name,
    c_last_name,
    c_preferred_cust_flag,
    c_birth_day,
    c_birth_month,
    c_birth_year,
    c_birth_country,
    c_login,
    c_email_address,
    c_last_review_date_sk,
    ctr_total_return
FROM
    customer_total_return ctr1,
    customer_address,
    customer
WHERE
    ctr1.ctr_total_return > (
        SELECT
            AVG(ctr_total_return) * 1.2
        FROM
            customer_total_return ctr2
        WHERE
            ctr1.ctr_state = ctr2.ctr_state
    )
    AND ca_address_sk = c_current_addr_sk
    AND ca_state IN (
        '[STATE.1]',
        '[STATE.2]',
        '[STATE.3]',
        '[STATE.4]'
    )
    AND ctr1.ctr_customer_sk = c_customer_sk
    AND ctr1.ctr_reason_sk IN (
        [REASON.1],
        [REASON.2]
    )
    AND c_birth_year BETWEEN
        [BIRTH_YEAR.begin] AND [BIRTH_YEAR.end]

    -- Exclude customers who made store returns during the selected year.
    AND NOT EXISTS (
        SELECT 1
        FROM
            store_returns sr
            JOIN date_dim sd
                ON sr.sr_returned_date_sk = sd.d_date_sk
        WHERE
            sr.sr_customer_sk = ctr1.ctr_customer_sk
            AND sd.d_year = [YEAR]
    )

ORDER BY
    c_customer_id,
    c_salutation,
    c_first_name,
    c_last_name,
    c_preferred_cust_flag,
    c_birth_day,
    c_birth_month,
    c_birth_year,
    c_birth_country,
    c_login,
    c_email_address,
    c_last_review_date_sk,
    ctr_total_return

[_LIMITC];