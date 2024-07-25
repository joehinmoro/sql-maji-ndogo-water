-- use db
USE md_water_services;


-- add email column to employee table
-- email format: fname.lname@ndogowater.gov
-- test email update query
SELECT
   CONCAT(REPLACE(TRIM(LOWER(employee_name)), ' ', '.'), '@ndogowater.gov')
FROM employee;


-- add email column
UPDATE
    employee
SET
    email = CONCAT(REPLACE(TRIM(LOWER(employee_name)), ' ', '.'), '@ndogowater.gov');


-- inspect email column
SELECT
    employee_name,
    email
FROM
    employee;


-- inspect phone number column
SELECT
    employee_name,
    phone_number,
    LENGTH(phone_number) phone_number_length
FROM
    employee


-- test phone_number update query
SELECT 
    trimmed_phone_number,
    trimmed_length
FROM (
        -- update query is subquery
        SELECT
            TRIM(phone_number) as trimmed_phone_number,
            LENGTH(TRIM(phone_number)) trimmed_length
        FROM
            employee
    ) trim_num
-- toggle comment out the where clause (phone num length should be 12)
WHERE trimmed_length != 12
;


-- update phone number column
UPDATE employee
SET
    phone_number = TRIM(phone_number)
;


-- verify phone number update
-- should return blank
SELECT
    phone_number
FROM employee
WHERE LENGTH(phone_number) != 12


-- number of employees per town
SELECT
    town_name town,
    COUNT(assigned_employee_id) num_of_employees
FROM
    employee
GROUP BY 1
-- ORDER BY 1
;


-- num of visits per employee_id (unordered)
SELECT
    assigned_employee_id,
    COUNT(assigned_employee_id) number_of_visits
FROM
    visits
GROUP BY 1
-- ORDER BY 2 DESC
LIMIT 3;


-- top 3 employees with the most visit count
-- using CTE and subquery
with emp_vis_count AS (
    SELECT
        assigned_employee_id,
        COUNT(assigned_employee_id) num_of_visits
    FROM
        visits
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 3
)
SELECT
    employee_name,
    email,
    phone_number,
    evc.assigned_employee_id,
    num_of_visits
FROM
    employee
    JOIN emp_vis_count evc
    USING(assigned_employee_id)
;


-- top 3 employees with the most visit count
-- using subqueries(FROM) and Join
SELECT
    employee_name,
    email,
    phone_number,
    evc.assigned_employee_id,
    num_of_visits
FROM employee
JOIN
    (
        SELECT
            assigned_employee_id,
            COUNT(assigned_employee_id) num_of_visits
        FROM visits
        GROUP BY 1
        ORDER BY 2 DESC
        LIMIT 3
    ) evc
USING(assigned_employee_id)
;


-- top 3 employees with the most visit count
-- using subqueries(FROM) and WHERE (Filter)
SELECT
    employee_name,
    email,
    phone_number,
    evc.assigned_employee_id,
    num_of_visits
FROM
    employee,
    (
        SELECT
            assigned_employee_id,
            COUNT(assigned_employee_id) num_of_visits
        FROM visits
        GROUP BY 1
        ORDER BY 2 DESC
        LIMIT 3
    ) evc
WHERE
    employee.assigned_employee_id = evc.assigned_employee_id


-- top 3 employees with the most visit count
-- using nested subqueries WHERE (select employee table only)
SELECT
    employee_name,
    email,
    phone_number
FROM
    employee
WHERE
    assigned_employee_id IN (
        SELECT
            assigned_employee_id
        FROM
            (
                SELECT
                    assigned_employee_id,
                    COUNT(assigned_employee_id)
                FROM
                    visits
                GROUP BY 1
                ORDER BY 2 DESC
                LIMIT 3
            ) evc
    )
;


-- top 3 employees with the most visit count
-- using just CTE and WHERE (select employee table only)
WITH emp_vis_count as (
    SELECT
        assigned_employee_id,
        COUNT(assigned_employee_id) num_of_visits
    FROM
        visits
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 3   
)
SELECT
    employee_name,
    email,
    phone_number
FROM
    employee
WHERE
    employee.assigned_employee_id IN (
        SELECT
            assigned_employee_id
        FROM
            emp_vis_count
    )


-- top 3 employees with the most visit count
-- using just WHERE manually (select employee table only) [2 queries]
SELECT
    assigned_employee_id,
    COUNT(assigned_employee_id)
FROM
    visits
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;
-- (1, 30, 34)
SELECT
    employee_name,
    email,
    phone_number
FROM
    employee
WHERE
    assigned_employee_id IN (1, 30, 34)
;


-- numner of location records per town
SELECT
    COUNT(location_id) records_per_town,
    town_name
FROM
    `location`
GROUP BY 2
ORDER BY 1 DESC;

    
-- number of location records per province
SELECT
    COUNT(location_id) records_per_province,
    province_name
FROM `location`
GROUP BY 2
ORDER BY 1 DESC;


-- number of location records per province per town
SELECT
    province_name,
    town_name,
    COUNT(location_id) records_per_town
FROM
    `location`
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- number of records and percentage share per location type 
SELECT
    COUNT(location_id) num_of_sources,
    location_type
FROM
    `location`
GROUP BY 2
ORDER BY 1;


-- number of records and percentage share per location type 
SELECT
    COUNT(location_id) num_of_sources,
    ROUND(COUNT(location_id) / (
            SELECT COUNT(location_id)
            FROM `location`
        ) * 100 ) percentage_share,
    location_type
FROM
    `location`
GROUP BY 3
ORDER BY 1;


-- 01 number of people surveyed?
SELECT
    SUM(number_of_people_served) total_num_of_people_surveyed
FROM water_source;


-- 02 number of sources per source type?
SELECT
    type_of_water_source,
    COUNT(source_id) num_of_source
FROM
    water_source
GROUP BY 1
ORDER BY 2 DESC;


-- 03 average number of people served per water source?
SELECT
    type_of_water_source,
    ROUND(AVG(number_of_people_served)) avg_served
FROM
    water_source
GROUP BY 1
ORDER BY 2 DESC


-- [PROPER] 02 number of sources per source type?
-- 1 tap in home = average tap in home / 6
WITH src_cnt as (
    SELECT
        type_of_water_source,
        COUNT(source_id) cnt_src
    FROM
        water_source
    GROUP BY 1
    ORDER BY 2 DESC
),
src_avg as (
    SELECT
        type_of_water_source,
        ROUND(AVG(number_of_people_served)) avg_src
    FROM
        water_source
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    type_of_water_source,
    CASE 
        WHEN type_of_water_source LIKE 'tap_in_home%' THEN  ROUND(cnt_src * (avg_src / 6))
        ELSE  cnt_src
    END num_of_source
FROM src_cnt
JOIN src_avg
USING(type_of_water_source)
;


-- [PROPER] 03 average number of people served per water source?
SELECT
    type_of_water_source,
    CASE 
        WHEN type_of_water_source LIKE 'tap_in_home%' THEN 6
        ELSE ROUND(AVG(number_of_people_served)) 
    END avg_served
FROM
    water_source
GROUP BY 1
ORDER BY 2 DESC;


-- 04 total num of people served per source type
SELECT
    type_of_water_source,
    sum(number_of_people_served) population_served
FROM
    water_source
GROUP BY 1
ORDER BY 2 DESC;


-- [XTRA] pct_diff of calulated and estimated population served
-- for taps in home
WITH src_cnt AS (
    SELECT
        type_of_water_source,
        COUNT(source_id) cnt_src
    FROM
        water_source
    GROUP BY 1
    ORDER BY 2 DESC
),
src_avg as (
    SELECT
        type_of_water_source,
        ROUND(AVG(number_of_people_served)) avg_src
    FROM
        water_source
    GROUP BY 1
    ORDER BY 2 DESC
),
src_sum AS (
    SELECT
        type_of_water_source,
        sum(number_of_people_served) population_served
    FROM
        water_source
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    type_of_water_source,
    cnt_src * avg_src derived_population_served,
    population_served,
    ABS((cnt_src * avg_src) - population_served) abs_error,
    ((cnt_src * avg_src) + population_served) / 2 average,
    ABS((cnt_src * avg_src) - population_served) / (((cnt_src * avg_src) + population_served) / 2) * 100 pct_diff
FROM src_cnt
JOIN src_avg
USING(type_of_water_source)
JOIN src_sum
USING(type_of_water_source)
WHERE type_of_water_source LIKE 'tap_in_home%'
;


-- 04 pct of people served per source type
SELECT
    type_of_water_source,
    sum(number_of_people_served) population_served,
    ROUND(sum(number_of_people_served) / (
        SELECT SUM(number_of_people_served)
        FROM water_source
    ) * 100) percentage_people_per_source
FROM
    water_source
GROUP BY 1
ORDER BY 2 DESC;


-- well cleaniness pct
SELECT
    results,
    COUNT(source_id) pollution_dist,
    ROUND(COUNT(source_id) / (
        SELECT COUNT(source_id)
        FROM well_pollution
    ) * 100) pct_pollution_dist
FROM well_pollution
GROUP BY 1;


-- rank water sources based on population served
SELECT
    type_of_water_source,
    SUM(number_of_people_served) people_served,
    RANK() OVER(ORDER BY SUM(number_of_people_served) DESC) rank_by_population
FROM water_source
GROUP BY 1;


-- ranking improvable sources by number of people served
-- categorized by each distinct source type 
SELECT
    source_id,
    type_of_water_source,
    number_of_people_served,
    RANK() OVER(
        PARTITION BY type_of_water_source 
        ORDER BY number_of_people_served DESC
    ) priority_rank,
    DENSE_RANK() OVER(
        PARTITION BY type_of_water_source
        ORDER BY number_of_people_served DESC
    ) priority_dense_rank,
    ROW_NUMBER() OVER(
        PARTITION BY type_of_water_source
        ORDER BY number_of_people_served DESC
    ) priority_row_number
FROM water_source
WHERE type_of_water_source != 'tap_in_home';


-- total time of visit survey
SELECT
    DATEDIFF(MAX(time_of_record), MIN(time_of_record)) total_visits_duration
FROM visits;
-- 924 days


-- average time in queue [assuming 0 == non-queue source]
SELECT ROUND(AVG(NULLIF(time_in_queue, 0))) avg_time_in_queue
from visits
LIMIT 100


-- [XTRA] verify sources with 0 queue time are non-queue sources
SELECT
    type_of_water_source,
    COUNT(source_id) num_of_sources
FROM visits v
LEFT JOIN water_source ws
USING (source_id)
WHERE time_in_queue = 0
GROUP BY 1;
-- all wells are non-queue sorces (17383)


-- [XTRA] number of wells
SELECT
COUNT(source_id) num_of_wells
FROM water_source
WHERE type_of_water_source like '%well%'
-- 17383 wells


-- [XTRA] only rivers and shared taps have non-zero queue times
SELECT
    type_of_water_source,
    COUNT(source_id) num_of_sources
FROM visits v
LEFT JOIN water_source ws
USING (source_id)
WHERE time_in_queue != 0
GROUP BY 1;


-- average queue time by day of the week
SELECT
DAYNAME(time_of_record) day_of_week,
ROUND(AVG(NULLIF(time_in_queue, 0))) avg_queue_time
FROM visits
GROUP BY 1
ORDER BY 2 DESC;
-- saturday has an extremely high queue time


-- average queue time by hour of the day
SELECT
HOUR(time_of_record) hour_of_day,
ROUND(AVG(NULLIF(time_in_queue, 0))) avg_queue_time
FROM visits
GROUP BY 1
ORDER BY 2 DESC;


-- average queue time by hour of the day (formatted)
SELECT
TIME_FORMAT(TIME(time_of_record), '%H:00') hour_of_day,
ROUND(AVG(NULLIF(time_in_queue, 0))) avg_queue_time
FROM visits
GROUP BY 1
ORDER BY 2 DESC;


-- pivot table test: hours of sunday
SELECT
    TIME_FORMAT(TIME(time_of_record), '%H:00') hour_of_day,
    DAYNAME(time_of_record) day_of_week,
    CASE
        WHEN DAYNAME(time_of_record) like '%sunday%' THEN time_in_queue
        END Sunday
FROM
    visits
WHERE
    time_in_queue != 0
;


-- pivot table: average queue time (val) by hour of the day (rows/idx) and day of the week (cols)
SELECT
    TIME_FORMAT(TIME(time_of_record), '%H:00') hour_of_day,
    ROUND(AVG(CASE
        WHEN DAYNAME(time_of_record) like '%sunday%' THEN time_in_queue
        END)) sunday,
    ROUND(AVG(CASE
        WHEN DAYNAME(time_of_record) like '%monday%' THEN time_in_queue
        END)) monday,
    ROUND(AVG(CASE 
        WHEN DAYNAME(time_of_record) like '%tuesday%' THEN time_in_queue
        END)) tuesday,
    ROUND(AVG(CASE
        WHEN DAYNAME(time_of_record) like '%wednesday%' THEN time_in_queue
        END)) wednesday,
    ROUND(AVG(CASE
        WHEN DAYNAME(time_of_record) like '%thursday%' THEN time_in_queue
        END)) thursday,
    ROUND(AVG(CASE 
        WHEN DAYNAME(time_of_record) like '%friday%' THEN time_in_queue
        END)) friday,
    ROUND(AVG(CASE 
        WHEN DAYNAME(time_of_record) like '%saturday%' THEN time_in_queue
        END)) saturday
FROM
    visits
WHERE
    time_in_queue != 0
GROUP BY 1
ORDER BY 1
;


-- 