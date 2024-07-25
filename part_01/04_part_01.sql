-- use md_water_services db
USE md_water_services;


-- show all tables
SHOW TABLES;


-- query data dictionary
SELECT *
FROM data_dictionary;


-- inspect tables
SELECT * FROM employee LIMIT 10;
SELECT COUNT(*) num_of_employees FROM employee;
SELECT * FROM global_water_access LIMIT 10;
SELECT COUNT(*) num_of_country_records FROM global_water_access;
SELECT ROUND(COUNT(*)/2) num_of_countries FROM global_water_access;
SELECT * FROM `location` LIMIT 10;
SELECT COUNT(*) source_locations FROM `location`;
SELECT * FROM visits LIMIT 10;
SELECT COUNT(*) num_of_visits FROM visits;
SELECT * FROM water_quality LIMIT 10;
SELECT COUNT(*) num_of_quality_records FROM water_quality;
SELECT * FROM water_source LIMIT 10;
SELECT COUNT(*) num_of_water_sources FROM water_source;
SELECT * FROM well_pollution LIMIT 10;
SELECT COUNT(*) num_of_well_pollution_records FROM well_pollution;


-- unique water sources
SELECT DISTINCT type_of_water_source
FROM water_source;


-- population of maji ndogo
SELECT distinct ROUND(pop_n * 1000)
FROM global_water_access
where name like "%maji%"


-- confirm shared_tap at 18 Twiga Lane serves 2700
SELECT
    type_of_water_source `Type`, 
    ROUND(number_of_people_served, -2) Number_Served
-- SELECT *
FROM water_source
WHERE
    source_id = (
        SELECT source_id
        FROM visits
        WHERE
            location_id = (
                SELECT location_id
                FROM location
                WHERE address like '18 Twiga Lane%'
            )
    )


-- one tap in home represent people served / 6
SELECT ROUND(number_of_people_served / 6)
FROM water_source
WHERE source_id = 'AkHa00000224';


-- records with queue time > 500 mins
SELECT *
FROM visits
WHERE time_in_queue > 500;


-- inspecting water sources with high queue times (random)
SELECT *
FROM water_source
WHERE source_id IN ('AkKi00881224', 'SoRu37635224', 'SoRu36096224')


-- inspecting water sources with high queue times (comprehensive)
SELECT *
FROM water_source
WHERE
    source_id IN (
        SELECT source_id
        FROM visits
        WHERE time_in_queue > 500
    );


-- inspecting water sources with zero queue times (random)
SELECT *
FROM water_source
WHERE source_id IN ('AkRu05234224', 'HaZa21742224');


-- inspecting water sources with zero queue times (comprehensive)
SELECT *
FROM water_source
WHERE
    source_id IN (
        SELECT source_id
        FROM visits
        WHERE time_in_queue = 0
    )
LIMIT 100;


-- high quality sources with visits = 2
SELECT *
FROM water_quality
WHERE
    subjective_quality_score = 10
    AND
    visit_count = 2;
-- 218 records


-- high quality sources with visits > 1
SELECT *
FROM water_quality
WHERE
    subjective_quality_score = 10
    AND
    visit_count > 1;
-- 1526 records


-- high quality home sources with visits > 1
SELECT *
FROM water_quality wq
INNER JOIN visits v USING(record_id)
INNER JOIN water_source ws USING(source_id)
WHERE
    subjective_quality_score = 10
    AND
    wq.visit_count > 1
    -- AND
    -- type_of_water_source LIKE '%home%'
;
-- 0 records like '%home%'
-- 1526 otherwise


-- unique well pollution result values like '%clean%'
SELECT DISTINCT results
FROM well_pollution
WHERE results LIKE '%clean%'


-- records with result as clean but with significant biological contaminant
SELECT *
FROM well_pollution
WHERE
    -- results LIKE '%clean%'
    results = 'Clean'
    AND
    biological > 0.01


-- records with description like 'clean_%' (check biological)
SELECT *
FROM well_pollution
WHERE description LIKE 'clean_%'
-- AND biological > 0.01
;


-- distinct description values of
-- records with description like 'clean_%' (check biological)
SELECT DISTINCT description
FROM well_pollution
WHERE description LIKE 'clean_%'
-- AND biological > 0.01
;


-- case 1a
SELECT *
FROM well_pollution
WHERE description = 'Clean Bacteria: E. coli';
-- 26 records


-- case 1b
SELECT *
FROM well_pollution
WHERE description = 'Clean Bacteria: Giardia Lamblia';
-- 12 records


-- case 2
SELECT *
FROM well_pollution
WHERE results = 'Clean'
AND biological > 0.01
AND description NOT LIKE 'Clean%'
-- 26 records


-- sum num of cases
SELECT 12 + 26 + 26;
-- 64


-- create copy of well_pollution
CREATE Table well_pollution_copy
AS (
    SELECT *
    FROM well_pollution
);


-- update case 1a
UPDATE well_pollution_copy
SET description = 'Bacteria: E. coli'
WHERE description = 'Clean Bacteria: E. coli'


-- update case 1b
UPDATE well_pollution_copy
SET description = 'Bacteria: Giardia Lamblia'
WHERE description = 'Clean Bacteria: Giardia Lamblia'


-- update case 2
UPDATE well_pollution_copy
SET results = 'Contaminated: Biological'
WHERE biological > 0.01
AND results = 'Clean'


-- check well pollution copy
SELECT *
FROM well_pollution_copy
WHERE
    description LIKE 'clean_%'
    OR
    (results = 'Clean'
    AND
    biological > 0.01);


-- update case 1a
UPDATE well_pollution
SET description = 'Bacteria: E. coli'
WHERE description = 'Clean Bacteria: E. coli'
-- AffectedRows : 26


-- update case 1b
UPDATE well_pollution
SET description = 'Bacteria: Giardia Lamblia'
WHERE description = 'Clean Bacteria: Giardia Lamblia'
-- AffectedRows : 12


-- update case 2
UPDATE well_pollution
SET results = 'Contaminated: Biological'
WHERE biological > 0.01
AND results = 'Clean'
-- AffectedRows : 64


-- check well pollution
SELECT *
FROM well_pollution
WHERE
    description LIKE 'clean_%'
    OR
    (results = 'Clean'
    AND
    biological > 0.01);


-- drop well pollution copy
DROP TABLE well_pollution_copy;



