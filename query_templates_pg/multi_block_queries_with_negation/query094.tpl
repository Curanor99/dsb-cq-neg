-- Calculates the number of distinct web orders, total shipping costs, and total net profit for orders
-- shipped within a selected 60-day period. Filters transactions by shipping address state, website GMT
-- offset, and list price. Includes only orders fulfilled by multiple warehouses and excludes orders with
-- associated web returns for specified return reasons. Returns the aggregated order count, shipping cost,
-- and net profit, ordered by the number of distinct orders.

define YEAR = random(1998, 2002, uniform);
define MONTH = random(1,10,uniform);
define STATE=sulist(dist(fips_county,3,1),6);
define PRICE = range(random(1, 300, uniform), 10);
define GMT = text({"-5",1}, {"-6",1},{"-7",1});
define REASON = sulist(random(1, 75, uniform), 5);

define _LIMIT=100;

[_LIMITA] select [_LIMITB]
   count(distinct ws_order_number) as "order count"
  ,sum(ws_ext_ship_cost) as "total shipping cost"
  ,sum(ws_net_profit) as "total net profit"
from
   web_sales ws1
  ,date_dim
  ,customer_address
  ,web_site
where
    d_date between '[YEAR]-[MONTH]-01' and
           cast('[YEAR]-[MONTH]-01' as date) + interval '60 day'
and ws1.ws_ship_date_sk = d_date_sk
and ws1.ws_ship_addr_sk = ca_address_sk
and ca_state in ('[STATE.1]','[STATE.2]','[STATE.3]'
            ,'[STATE.4]' ,'[STATE.5]' ,'[STATE.6]')
and ws1.ws_web_site_sk = web_site_sk
and web_gmt_offset >= [GMT]
and ws1.ws_list_price between [PRICE.begin] and [PRICE.end]
and exists (select *
            from web_sales ws2
            where ws1.ws_order_number = ws2.ws_order_number
              and ws1.ws_warehouse_sk <> ws2.ws_warehouse_sk)
and not exists(select *
               from web_returns wr1
               where ws1.ws_order_number = wr1.wr_order_number
               and wr1.wr_reason_sk in ([REASON.1], [REASON.2], [REASON.3], [REASON.4], [REASON.5])
               )
order by count(distinct ws_order_number)
[_LIMITC];
