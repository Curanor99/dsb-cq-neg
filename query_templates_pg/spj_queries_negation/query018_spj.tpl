-- Calculates the minimum values for selected catalog sales, customer, and address attributes, including
-- item ID, geographic location, sales quantities and prices, coupon amounts, net profit, birth year, and
-- dependent count. Filters catalog transactions by year, item category, wholesale cost, customer gender,
-- education level, birth month, and current address state. Excludes items that have ever been sold through
-- the web sales channel.

 define YEAR = random(1998, 2002, uniform);
 define GEN= dist(gender, 1, 1);
 define ES= dist(education, 1, 1);
 define STATE=sulist(dist(fips_county,3,1),3);
 define MONTH=random(1,12,uniform);
 define WHOLESALE_COST = range(random (0, 100, uniform), 5);
 define CATEGORY = dist(categories,1,1);

 select min(i_item_id),
        min(ca_country),
        min(ca_state),
        min(ca_county),
        min(cs_quantity),
        min(cs_list_price),
        min(cs_coupon_amt),
        min(cs_sales_price),
        min(cs_net_profit),
        min(c_birth_year),
        min(cd_dep_count)
 from catalog_sales, customer_demographics, customer, customer_address, date_dim, item
 where cs_sold_date_sk = d_date_sk and
       cs_item_sk = i_item_sk and
       cs_bill_cdemo_sk = cd_demo_sk and
       cs_bill_customer_sk = c_customer_sk and
       cd_gender = '[GEN]' and
       cd_education_status = '[ES]' and
       c_current_addr_sk = ca_address_sk and
       d_year = [YEAR] and
       c_birth_month = [MONTH] and
       ca_state in ('[STATE.1]', '[STATE.2]', '[STATE.3]')
       and cs_wholesale_cost BETWEEN [WHOLESALE_COST.begin] AND [WHOLESALE_COST.end]
       AND i_category = '[CATEGORY]'
       AND NOT EXISTS (
              SELECT 1
              FROM web_sales ws
              WHERE ws.ws_item_sk = i.i_item_sk
       )
;
