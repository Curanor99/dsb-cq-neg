-- Identifies customers whose average store return amount exceeds the store-specific average by more than 20%, 
-- filtering by return reason, store location, and customer demographic attributes. Considers returns from a 
-- randomly selected year and price range, excluding returns for items subsequently purchased online by the 
-- same customer. Returns the matching customer IDs, ordered by customer ID.

define STATE=sulist(dist(fips_county,3,1), 3);
define YEAR = random(1998, 2002, uniform);
define AGG_FIELD = text({"SR_RETURN_AMT",1},{"SR_FEE",1},{"SR_REFUNDED_CASH",1},{"SR_RETURN_AMT_INC_TAX",1},{"SR_REVERSED_CHARGE",1},{"SR_STORE_CREDIT",1},{"SR_RETURN_TAX",1});
define MS= list(dist(marital_status, 1, 1), 2);
define ES= list(dist(education, 1, 1), 2);
define GEN= dist(gender, 1, 1);
define BIRTH_MONTH = random(1, 12, uniform);
define BIRTH_YEAR = range(random (1925, 1993, uniform), 10);
define REASON = range(random(1, 75, uniform), 5);
define PRICE = range(random(1, 300, uniform), 20);

define _LIMIT=100;

WITH customer_total_return AS (
    SELECT
        sr_customer_sk AS ctr_customer_sk,
        sr_store_sk AS ctr_store_sk,
        sr_reason_sk AS ctr_reason_sk,
        SUM([AGG_FIELD]) AS ctr_total_return
    FROM store_returns,
         date_dim
    WHERE sr_returned_date_sk = d_date_sk
      AND d_year = [YEAR]
      AND sr_return_amt / sr_return_quantity
          BETWEEN [PRICE.begin] AND [PRICE.end]

      AND NOT EXISTS (
          SELECT 1
          FROM web_sales ws
          JOIN date_dim online_date
            ON ws.ws_sold_date_sk = online_date.d_date_sk
          WHERE ws.ws_bill_customer_sk = sr_customer_sk
            AND ws.ws_item_sk = sr_item_sk
            AND online_date.d_date > d_date
      )

    GROUP BY
        sr_customer_sk,
        sr_store_sk,
        sr_reason_sk
)

[_LIMITA]
SELECT [_LIMITB] c_customer_id
FROM customer_total_return ctr1,
     store,
     customer,
     customer_demographics
WHERE ctr1.ctr_total_return > (
    SELECT AVG(ctr_total_return) * 1.2
    FROM customer_total_return ctr2
    WHERE ctr1.ctr_store_sk = ctr2.ctr_store_sk
)
  AND ctr1.ctr_reason_sk
      BETWEEN [REASON.begin] AND [REASON.end]
  AND s_store_sk = ctr1.ctr_store_sk
  AND s_state IN (
      '[STATE.1]',
      '[STATE.2]',
      '[STATE.3]'
  )
  AND ctr1.ctr_customer_sk = c_customer_sk
  AND c_current_cdemo_sk = cd_demo_sk
  AND cd_marital_status IN ('[MS.1]', '[MS.2]')
  AND cd_education_status IN ('[ES.1]', '[ES.2]')
  AND cd_gender = '[GEN]'
  AND c_birth_month = [BIRTH_MONTH]
  AND c_birth_year
      BETWEEN [BIRTH_YEAR.begin] AND [BIRTH_YEAR.end]
ORDER BY c_customer_id
[_LIMITC];