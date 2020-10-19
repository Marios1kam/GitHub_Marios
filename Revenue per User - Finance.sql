WITH first_install AS 

(
select 
user_id,
max(context_ip) as context_ip,
min(timestamp) as install_day 
from ios_app.tracks
group by 1
),

PURCHASES AS

(
SELECT
anonymous_id, 
CP.user_id, 
timestamp::date as date, 
revenue, 
currency,
iap_sku,
first_install.context_ip as context_ip,
CONCAT(timestamp::date, currency) AS key,
mm_city.country_name,
first_install.install_day

FROM ios_app.currency_purchase as CP
      
LEFT JOIN first_install on first_install.user_id= CP.user_id

LEFT JOIN maxmind_ipv4_lookup AS mm_geo
 ON REGEXP_SUBSTR(first_install.context_ip, '\\d+\.\\d+') = mm_geo.first_16_bits
 AND f_inet_aton(first_install.context_ip) BETWEEN mm_geo.network_start_integer
 AND mm_geo.network_last_integer
LEFT JOIN maxmind_geo_to_city AS mm_city ON mm_geo.geoname_id = mm_city.geoname_id

WHERE status = 'succeeded'
AND anonymous_id not in (select anonymous_id from public.internal_devices )
--AND revenue is not null 
AND amount_spent is null

),

FX AS
 
(
SELECT 
CONCAT(tradingdate, targetcurrency) AS key,
tradingrate

FROM exchange_rates.fx_rates_gbp
)



select 
purchases.anonymous_id,
purchases.user_id,
purchases.date,
purchases.revenue,
purchases.currency,
purchases.iap_sku,
purchases.install_day,
purchases.country_name,
(purchases.revenue / fx.tradingrate) as gbp_revenue

from PURCHASES
LEFT JOIN fx ON purchases.key = fx.key