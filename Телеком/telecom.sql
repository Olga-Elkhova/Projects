-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
-- Формирование уникальной пары значений user_id и dt_month:
user_activity_months AS (
    -- Первое множество значений user_id и dt_month с учётом разговорной активности клиента:
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    -- Второе множество значений user_id и dt_month с учётом интернет-активности клиента:
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    -- Третье множество значений user_id и dt_month с учётом активности клиента по сообщениям:
    SELECT user_id, dt_month
    FROM monthly_sms
),
-- Соединение подсчитанных значений по активности клиента в одну таблицу:
users_stat AS (
    SELECT u.user_id,
           u.dt_month,
           month_duration,
           month_mb_traffic,
           month_sms
    -- В качестве основной таблицы используем данные из CTE user_activity_months:
    FROM user_activity_months AS u
    -- Последовательно присоединяем данные по звонкам, интернет-трафику и сообщениям.
    -- При объединении данных используем пару значений user_id и dt_month:
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
-- Превышение установленного лимита по каждому виду связи:
user_over_limits AS (
    SELECT us.user_id,
           us.dt_month,
           u.tariff,
           us.month_duration,
           us.month_mb_traffic,
           us.month_sms,
        -- Условие, если длительность разговоров клиента превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_duration >= t.minutes_included 
            THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        -- Условие, если количество интернет-трафика в месяц превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included 
            THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,
        -- Условие, если количество сообщений в месяц превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_sms >= t.messages_included 
            THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT tariff, user_id FROM telecom.users) AS u ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
),
-- Траты клиента за каждый месяц:
users_costs AS (
    SELECT uol.user_id,
           uol.dt_month,
           uol.tariff,
           uol.month_duration,
           uol.month_mb_traffic,
           uol.month_sms,
           t.rub_monthly_fee, 
           t.rub_monthly_fee + uol.duration_over * t.rub_per_minute
           + uol.gb_traffic_over * t.rub_per_gb + uol.sms_over * t.rub_per_message AS total_cost 
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t ON uol.tariff = t.tariff_name
)
select users_costs.tariff,
       count(distinct users_costs.user_id) as total_users,
       round(avg(users_costs.total_cost)::numeric, 2) as avg_total_cost,
       round(avg(users_costs.total_cost - rub_monthly_fee)::numeric, 2) as overcost
from users_costs
left join telecom.users on users_costs.user_id = users.user_id
where users.churn_date is null and users_costs.total_cost > users_costs.rub_monthly_fee
group by users_costs.tariff;