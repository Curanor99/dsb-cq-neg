-- Analyzes customer demographics by grouping customers according to gender, marital status, education,
-- purchase estimate, and credit rating. Filters customers by address state and marital and education status,
-- requiring at least one in-store purchase within a selected three-month period and price range. Excludes
-- customers who made matching web or catalog purchases during the same period and price range. Returns
-- demographic group counts, ordered by the grouping attributes.

define MONTH=random(1,10,uniform);
define YEAR=random(1998,2002,uniform);
define STATE= sulist(dist(fips_county, 3, 1), 3);
define PRICE = range(random(1, 300, uniform), 30);
define MS= list(dist(marital_status, 1, 1), 3);
define ES= list(dist(education, 1, 1), 2);

define _LIMIT=100;

[_LIMITA] select [_LIMITB]
cd_gender,
cd_marital_status,
cd_education_status,
count(*) cnt1,
cd_purchase_estimate,
count(*) cnt2,
cd_credit_rating,
count(*) cnt3
from
customer c,customer_address ca,customer_demographics
where
c.c_current_addr_sk = ca.ca_address_sk and
ca_state in ('[STATE.1]','[STATE.2]','[STATE.3]') and
cd_demo_sk = c.c_current_cdemo_sk
and cd_marital_status in ('[MS.1]', '[MS.2]', '[MS.3]')
and cd_education_status in ('[ES.1]', '[ES.2]') and
exists (select *
      from store_sales,date_dim
      where c.c_customer_sk = ss_customer_sk and
            ss_sold_date_sk = d_date_sk and
            d_year = [YEAR] and
            d_moy between [MONTH] and [MONTH]+2
            and ss_list_price between [PRICE.begin] and [PRICE.end]
      ) and
(not exists (select *
      from web_sales,date_dim
      where c.c_customer_sk = ws_bill_customer_sk and
            ws_sold_date_sk = d_date_sk and
            d_year = [YEAR] and
            d_moy between [MONTH] and [MONTH]+2
            and ws_list_price between [PRICE.begin] and [PRICE.end]
      ) and
not exists (select *
      from catalog_sales,date_dim
      where c.c_customer_sk = cs_ship_customer_sk and
            cs_sold_date_sk = d_date_sk and
            d_year = [YEAR] and
            d_moy between [MONTH] and [MONTH]+2
            and cs_list_price between [PRICE.begin] and [PRICE.end])
      )
group by cd_gender,
      cd_marital_status,
      cd_education_status,
      cd_purchase_estimate,
      cd_credit_rating
order by cd_gender,
      cd_marital_status,
      cd_education_status,
      cd_purchase_estimate,
      cd_credit_rating
[_LIMITC];
