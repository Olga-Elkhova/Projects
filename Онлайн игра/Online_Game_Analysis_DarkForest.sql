-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
SELECT  COUNT(payer) AS count_gamers,
        SUM(payer) AS paying,
        (COUNT(payer) - SUM(payer)) AS non_paying, --  количество неплатящих игроков
        round(SUM(payer)/COUNT(payer)::numeric, 2) as share_paying,     --  доля платящих игроков 
        round((COUNT(payer) - SUM(payer))/COUNT(payer)::numeric, 2) as share_non_paying --  доля неплатящих игроков
    FROM fantasy.users;  
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT  race,
        SUM(payer) AS paying,         --  количество платящих игроков
        COUNT(payer) AS count_gamers, --  количество игроков
        round(SUM(payer)/COUNT(payer)::numeric, 3) as share_paying_race  --  доля платящих игроков по расам
    FROM fantasy.users
    JOIN fantasy.race using(race_id)
    GROUP BY race
    ORDER BY share_paying_race desc;  
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT count(transaction_id) AS count_transaction,  -- количество покупок
       sum(amount) AS sum_amount,                   -- суммарная стоимость покупок
       min(amount) AS min_amount,                   -- стоимость минимальной покупки,
       max(amount) AS max_amount,                   -- стоимость максимальной покупки
       round(avg(amount)::numeric, 2) AS avg_amount,                   -- среднее арифметическое стоимости покупок
       percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount, --  медиана стоимости покупок
       max(amount) - min(amount) AS spread_amount,                           -- разброс стоимости покупок
       (SELECT count(amount) FROM fantasy.events WHERE amount = 0) AS zero_amount,      -- количество нулевых покупок
       (SELECT count(amount) FROM fantasy.events WHERE amount > 1000) AS large_amount,  -- количество крупных покупок
       (SELECT count(amount) FROM fantasy.events WHERE amount < 1 AND amount > 0) AS small_amount      -- количество мелких покупок
FROM fantasy.events;
-- Статистические показатели по полю amount по расам
WITH z_amt AS (SELECT race_id, count(amount) AS zero_amount -- количество нулевых покупок
               FROM fantasy.events 
               LEFT JOIN fantasy.users  using(id)
               LEFT JOIN fantasy.race  using(race_id) 
               WHERE amount = 0
               GROUP BY race_id), 
l_amt AS (SELECT race_id, count(amount) AS large_amount     -- количество крупных покупок
               FROM fantasy.events 
               LEFT JOIN fantasy.users  using(id)
               LEFT JOIN fantasy.race  using(race_id) 
               WHERE amount > 1000
               GROUP BY race_id),
s_amt AS (SELECT race_id, count(amount) AS small_amount      -- количество мелких покупок
               FROM fantasy.events 
               LEFT JOIN fantasy.users  using(id)
               LEFT JOIN fantasy.race  using(race_id) 
               WHERE amount < 1 AND amount >0
               GROUP BY race_id)                
SELECT race,
       count(transaction_id) AS count_transaction,  -- количество покупок
       sum(amount) AS sum_amount,                   -- суммарная стоимость покупок
       min(amount) AS min_amount,                   -- стоимость минимальной покупки,
       max(amount) AS max_amount,                   -- стоимость максимальной покупки
       round(avg(amount)::numeric, 2) AS avg_amount,                   -- среднее арифметическое стоимости покупок
       percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount, --  медиана стоимости покупок
       max(amount) - min(amount) AS spread_amount,                           -- разброс стоимости покупок
       round(stddev(amount)::numeric, 2) AS stand_dev,                       -- стандартное отклонение стоимости покупок
       zero_amount,      -- количество нулевых покупок
       large_amount,     -- количество крупных покупок
       small_amount     -- количество мелких покупок
FROM fantasy.events
LEFT JOIN fantasy.users  using(id)
LEFT JOIN fantasy.race  using(race_id)
LEFT JOIN z_amt  using(race_id)
LEFT JOIN l_amt  using(race_id)
LEFT JOIN s_amt  using(race_id)
GROUP BY race,
         zero_amount,      
         large_amount,     
         small_amount
ORDER BY count_transaction DESC;
-- 2.2: Аномальные нулевые покупки:
SELECT (SELECT count(transaction_id) FROM fantasy.events) AS count_transaction,  -- количество покупок
       count(amount) AS zero_mount,  -- количество нулевых покупок
       round((count(amount)::numeric/(SELECT count(transaction_id) FROM fantasy.events))::NUMERIC,4) AS share_amound -- доля нулевых покупок
FROM fantasy.events
WHERE amount = 0;
-- Аномальные нулевые покупки о расам
-- АЛЬТЕРНАТИВНЫЙ ВАРИАНТ ЗАПРОСА --
SELECT race,
       COUNT(transaction_id) AS count_transaction,  -- количество покупок
       COUNT(transaction_id) FILTER (WHERE amount = 0) AS zero_mount_race,  -- количество нулевых покупок по расам
       round((COUNT(transaction_id) FILTER (WHERE amount = 0)::numeric)/(COUNT(transaction_id))::NUMERIC,5) AS share_amound -- доля нулевых покупок
    FROM fantasy.events
    LEFT JOIN fantasy.users using(id)
    LEFT JOIN fantasy.race using(race_id)
    GROUP BY race;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Количество платящих и неплатящих игроков по активности покупок
WITH ctr AS (
SELECT u.id,
       --count(u.id) AS count_id_paying,            -- общее количество игроков
       count(transaction_id) AS count_tr_paying,  -- количество покупок игроков
       sum(amount) AS sum_amount_paying,          -- суммарная стоимость покупок игроков
       round(count(transaction_id)/count(id)::numeric, 2) AS avg_tr_us,  -- среднее количество покупок на одного игрока 
       round((sum(amount)/count(id))::numeric, 2) AS  avg_sum_us         -- средняя сумма покупок на одного платящего игрока
FROM fantasy.users u 
LEFT JOIN fantasy.events e using(id)
WHERE amount > 0
GROUP BY u.id)
SELECT CASE 
	    WHEN payer=0 THEN 'неплатящий'
	    WHEN payer=1 THEN  'платящий'
        END AS payer,
       count(u.id) AS count_id_paying,              -- общее количество игроков
       sum(count_tr_paying) AS count_tr_paying,     -- количество покупок игроков
       sum(sum_amount_paying) AS sum_amount_paying, -- суммарная стоимость покупок игроков
       round((sum(count_tr_paying)::numeric/count(u.id))::numeric, 2) AS avg_tr_us,     -- среднее количество покупок на одного игрока 
       round((sum(sum_amount_paying)::numeric/count(u.id))::numeric, 2) AS  avg_sum_us -- средняя сумма покупок на одного платящего игрока
FROM ctr
JOIN fantasy.users u using(id)
GROUP BY payer
ORDER BY payer DESC;
-- Количество платящих и неплатящих игроков по расам
SELECT race, 
       count(DISTINCT id) FILTER (WHERE payer=1) AS count_paying_race,
       count(DISTINCT id) FILTER (WHERE payer=0) AS count_non_paying_race
FROM fantasy.users u 
LEFT JOIN fantasy.race  using(race_id)
GROUP BY race
ORDER BY count_paying_race DESC;
-- Количество платящих и неплатящих игроков по классам
WITH cnpc AS (
SELECT class, 
       count(id) AS count_non_paying_class
FROM fantasy.classes 
LEFT JOIN fantasy.users u using(class_id)
WHERE payer=0
GROUP BY class
ORDER BY count_non_paying_class DESC),
 cpc AS (
SELECT class, 
       count(id) AS count_paying_class
FROM fantasy.classes 
LEFT JOIN fantasy.users u using(class_id)
WHERE payer=1
GROUP BY class
ORDER BY count_paying_class DESC)
SELECT class,
       count_paying_class,
       count_non_paying_class
FROM cnpc
JOIN cpc using(class)
ORDER BY count_paying_class DESC;
-- 2.4: Популярные эпические предметы:
WITH ctr_id AS (
     SELECT item_code,
            game_items,
            count(transaction_id) AS count_transaction,   -- количество продаж по эпическим предметам
            count(DISTINCT id) AS count_gamers        -- количество игроков, покупавших эпические предметы
     FROM fantasy.events
     LEFT join fantasy.items using(item_code)
     WHERE amount > 0
     GROUP BY item_code,
              game_items)
     SELECT game_items,
            (SELECT count(transaction_id) FROM fantasy.events WHERE amount > 0) AS ctr,  -- общее количество продаж эпических предметов 
            count_transaction,                                                           -- количество продаж по эпическим предметам
            round((count_transaction::REAL/(SELECT count(transaction_id) FROM fantasy.events WHERE amount > 0))::NUMERIC,4) AS share_tr,   -- доля продаж эпических предметов
            (SELECT count(DISTINCT id) FROM fantasy.events WHERE amount > 0) AS total_count_gamers,  -- общее количество игроков, покупавших эпические предметы
            count_gamers,                                                                            -- количество игроков, покупавших эпические предметы
            round((count_gamers::REAL/(SELECT count(DISTINCT id) FROM fantasy.events WHERE amount > 0))::NUMERIC,4) AS share_id  -- доля игроков, покупающих эпические предметы
     FROM ctr_id
     WHERE count_transaction >= 1
     GROUP BY game_items,
              count_gamers,
              count_transaction
     ORDER BY  share_tr desc;
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH 
pg AS (select race, count(DISTINCT e.id) AS paying_gamers  -- количество платящих игроков
       FROM fantasy.users JOIN fantasy.race r using(race_id) LEFT JOIN fantasy.events e using(id)
       WHERE payer=1
       GROUP BY race),
avg_sum AS (SELECT race, round(avg(sum_amt)::NUMERIC,2)  AS avg_sum_amount   -- средняя сумма покупок на одного игрока
            FROM (SELECT race, id, count(transaction_id) AS count_tr, sum(amount) AS sum_amt 
                  FROM fantasy.users JOIN fantasy.events u using(id) JOIN fantasy.race r using(race_id)
                   GROUP BY race, id 
                   ORDER BY sum_amt DESC) AS cs
            GROUP BY race),
total_count AS (
SELECT race,
       count(DISTINCT u.id) AS total_reg_gamers,  -- общее количество зарегистрированных игроков 
       count(DISTINCT e.id) AS total_amt_gamers,    -- общее количество игроков, покупавших эпические предметы
       count(transaction_id) FILTER (WHERE amount >0) AS total_count_tr,  -- общее количество покупок
       sum(amount) AS total_sum_amt              -- сумма всех покупок
FROM fantasy.events e
FULL JOIN fantasy.users u using(id)
JOIN fantasy.race r using(race_id)
GROUP BY race)
SELECT race,
       total_reg_gamers,  -- общее количество зарегистрированных игроков
       total_amt_gamers,    -- общее количество игроков, покупавших эпические предметы
       round((total_amt_gamers::NUMERIC/total_reg_gamers)::NUMERIC,2) AS share_gamers, -- доля игроков, покупавших эпические предметы
       round((paying_gamers::NUMERIC/total_amt_gamers)::NUMERIC,2) AS share_paying_gamers,   -- доля платящих игроков от всех покупавших эпические предметы
       round((total_count_tr::NUMERIC/total_amt_gamers)::NUMERIC,2) AS avg_tr_gamers,   -- среднее количество покупок на одного игрока
       round((total_sum_amt::NUMERIC/total_count_tr)::NUMERIC,2) AS avg_1tr_gamers,   -- средняя стоимость одной покупки на одного игрока
       round(avg_sum_amount::NUMERIC,2) AS avg_sum_tr   -- средняя суммарная стоимость всех покупок на одного игрока
FROM total_count
JOIN pg using(race)
JOIN avg_sum using(race)
ORDER BY race;
-- Задача 2: Частота покупок
WITH
filtr_d AS (
      SELECT id, transaction_id, amount, payer,
             date::date - LAG(date::date) OVER (PARTITION BY id ORDER BY date) AS interval_date
      FROM fantasy.events e
      LEFT JOIN  fantasy.users u using(id)
      where amount > 0),
int_tr AS (
      SELECT id, count(transaction_id) AS count_tr,  -- общее количество покупок,
             max(payer) AS amt_gamers,
             avg(interval_date) AS avg_interval, -- среднее количество дней между покупками на одного игрока
             sum(interval_date) AS sum_interval -- суммарное количество дней между покупками на одного игрока
      FROM filtr_d
      GROUP BY id),
ntl_int AS (
      SELECT *,
             CASE 
             	WHEN NTILE(3) OVER (ORDER BY avg_interval) = 1 THEN 'высокая частота'
             	WHEN NTILE(3) OVER (ORDER BY avg_interval) = 2 THEN 'умеренная частота'
             	ELSE 'низкая частота'
             END AS category   -- категория игроков
       FROM int_tr
       WHERE count_tr >=25)
SELECT category,
       count(DISTINCT id) AS total_amt_gamers,  -- общее количество игроков,покупавших эпические предметы
       COUNT(DISTINCT CASE WHEN amt_gamers = 1 THEN id ELSE null END) AS paying_gamers,  -- количество платящих игроков
       round((COUNT(DISTINCT CASE WHEN amt_gamers = 1 THEN id ELSE null END)::NUMERIC/count(DISTINCT id))::NUMERIC,2) AS share_paying_gamers,   -- доля платящих игроков от всех покупавших эпические предмет
       round((sum(count_tr)::NUMERIC/count(DISTINCT id))::NUMERIC,2) AS avg_tr_gamers,   -- среднее количество покупок на одного игрока
       round((sum(avg_interval)::NUMERIC/count(DISTINCT id))::NUMERIC,2) AS tot_avg_interval -- среднее количество дней между покупками на одного игрока          
FROM ntl_int
GROUP BY category
ORDER BY avg_tr_gamers desc; 









       


