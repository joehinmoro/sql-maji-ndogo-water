-- Active: 1698164990869@@127.0.0.1@3306@md_water_services

-- select DB
USE md_water_services;

--  Are there any specific provinces, or towns where some sources are more abundant?

--  Join location to visits
SELECT
    loc.province_name,
    loc.town_name,
    vis.visit_count,
    vis.location_id,
    src.type_of_water_source,
    src.number_of_people_served,
    vis.time_of_record,
    qly.subjective_quality_score
FROM visits vis
JOIN location loc ON vis.location_id = loc.location_id
JOIN water_source src ON vis.source_id = src.source_id
JOIN water_quality qly ON vis.record_id = qly.record_id
WHERE vis.location_id = 'AkHa00103'
;


--  Join location to visits amd visit count = 1 as filter
SELECT
    loc.province_name,
    loc.town_name,
    src.type_of_water_source,
    loc.location_type,
    src.number_of_people_served,
    vis.time_in_queue
FROM visits vis
JOIN location loc ON vis.location_id = loc.location_id
JOIN water_source src ON vis.source_id = src.source_id
WHERE vis.visit_count = 1
;


-- join well_pollution
SELECT
    loc.province_name,
    loc.town_name,
    src.type_of_water_source,
    loc.location_type,
    src.number_of_people_served,
    vis.time_in_queue
FROM visits vis
LEFT JOIN well_pollution pol ON vis.source_id = pol.source_id
INNER JOIN location loc ON vis.location_id = loc.location_id
INNER JOIN water_source src ON vis.source_id = src.source_id
WHERE vis.visit_count = 1
;

-- create combined_analysis_table
CREATE VIEW combined_analysis_table AS
SELECT
    src.type_of_water_source source_type,
    loc.town_name,
    loc.province_name,
    loc.location_type,
    src.number_of_people_served people_served,
    vis.time_in_queue,
    pol.results
FROM visits vis
LEFT JOIN well_pollution pol ON vis.source_id = pol.source_id
INNER JOIN location loc ON vis.location_id = loc.location_id
INNER JOIN water_source src ON vis.source_id = src.source_id
WHERE vis.visit_count = 1
;

CREATE TEMPORARY TABLE province_aggregated_water_access
-- province name vs type of water source pivot table
WITH province_totals AS (-- This CTE calculates the population of each province
SELECT
province_name,
SUM(people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name
)
SELECT
ct.province_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
ROUND((SUM(CASE WHEN source_type = 'river'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN source_type = 'shared_tap'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN source_type = 'well'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
province_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name
ORDER BY
ct.province_name;


-- temp table: aggregated water access per town
CREATE TEMPORARY TABLE town_aggregated_water_access
WITH town_totals AS (
-- This CTE calculates the population of each town
-- Since there are two Harare towns, we have to group by province_name and town_name
SELECT province_name, town_name, SUM(people_served) AS total_ppl_serv
FROM combined_analysis_table
GROUP BY province_name,town_name
)
SELECT
ct.province_name,
ct.town_name,
ROUND((SUM(CASE WHEN source_type = 'river'
THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN source_type = 'shared_tap'
THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN source_type = 'well'
THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN -- Since the town names are not unique, we have to join on a composite key
town_totals tt ON ct.province_name = tt.province_name AND ct.town_name = tt.town_name
GROUP BY -- We group by province first, then by town.
ct.province_name,
ct.town_name
ORDER BY
ct.town_name;


SELECT * FROM province_aggregated_water_access;
SELECT * FROM town_aggregated_water_access
ORDER BY 1 DESC
;


SELECT
province_name,
town_name,
ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) * 100,0) AS Pct_broken_taps
FROM
town_aggregated_water_access
ORDER BY 3 DESC;


-- create project progress table
CREATE TABLE Project_progress (
Project_id SERIAL PRIMARY KEY,
source_id VARCHAR(20) NOT NULL 
    REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
Address VARCHAR(50),
Town VARCHAR(30),
Province VARCHAR(30),
Source_type VARCHAR(50),
Improvement VARCHAR(50),
Source_status VARCHAR(50) DEFAULT 'Backlog' 
    CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
Date_of_completion DATE,
Comments TEXT
)
;


--  Project_progress_query
SELECT
location.address,
location.town_name,
location.province_name,
water_source.source_id,
water_source.type_of_water_source,
well_pollution.results,
CASE 
    WHEN well_pollution.results = "Contaminated: Chemical" THEN "Install RO filter" 
    WHEN well_pollution.results = "Contaminated: Biological" THEN "Install UV and RO filter" 
    WHEN water_source.type_of_water_source = "river" THEN "Drill well" 
    WHEN water_source.type_of_water_source = "shared_tap" AND visits.time_in_queue >= 30
        THEN CONCAT("Install ", FLOOR(visits.time_in_queue / 30), " tap", IF(FLOOR(visits.time_in_queue / 30) > 1, "s", ""), " nearby")
    WHEN water_source.type_of_water_source = "tap_in_home_broken" THEN "Diagnose local infrastructure"
    ELSE NULL
END Improvements
FROM
water_source
LEFT JOIN
well_pollution ON water_source.source_id = well_pollution.source_id
INNER JOIN
visits ON water_source.source_id = visits.source_id
INNER JOIN
location ON location.location_id = visits.location_id
WHERE
    visits.visit_count = 1 -- This must always be true
    AND ( -- AND one of the following (OR) options must be true as well.
        well_pollution.results != 'Clean'
            OR
        water_source.type_of_water_source IN ('tap_in_home_broken','river')
            OR (
                water_source.type_of_water_source = 'shared_tap' 
                    AND
                visits.time_in_queue >= 30
            )
    )
;


SELECT * FROM location;



INSERT INTO project_progress (
    `source_id`,
    `Address`,
    `Town`,
    `Province`,
    `Source_type`,
    `Improvement`
)
SELECT
    water_source.source_id,
    location.address,
    location.town_name,
    location.province_name,
    water_source.type_of_water_source,
    CASE 
        WHEN well_pollution.results = "Contaminated: Chemical" THEN "Install RO filter" 
        WHEN well_pollution.results = "Contaminated: Biological" THEN "Install UV and RO filter" 
        WHEN water_source.type_of_water_source = "river" THEN "Drill well" 
        WHEN water_source.type_of_water_source = "shared_tap" AND visits.time_in_queue >= 30
            THEN CONCAT("Install ", FLOOR(visits.time_in_queue / 30), " tap", IF(FLOOR(visits.time_in_queue / 30) > 1, "s", ""), " nearby")
        WHEN water_source.type_of_water_source = "tap_in_home_broken" THEN "Diagnose local infrastructure"
        ELSE NULL
    END Improvements
FROM
water_source
LEFT JOIN
well_pollution ON water_source.source_id = well_pollution.source_id
INNER JOIN
visits ON water_source.source_id = visits.source_id
INNER JOIN
location ON location.location_id = visits.location_id
WHERE
    visits.visit_count = 1 -- This must always be true
    AND ( -- AND one of the following (OR) options must be true as well.
        well_pollution.results != 'Clean'
            OR
        water_source.type_of_water_source IN ('tap_in_home_broken','river')
            OR (
                water_source.type_of_water_source = 'shared_tap' 
                    AND
                visits.time_in_queue >= 30
            )
    )
;

