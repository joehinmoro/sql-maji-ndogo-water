-- use md_water_services db
USE md_water_services;


-- create auditor report table
CREATE Table `auditor_report`(
    `location_id` VARCHAR(32),
    `type_of_water_source` VARCHAR(64),
    `true_water_source_score` INT DEFAULT NULL,
    `statements` VARCHAR(255)
);


-- import auditor reports records from csv using MySQL workbench


-- inspect auditor reports table
SELECT
    *
FROM auditor_report
LIMIT 10;


-- count unique location id in auditor's report table
SELECT
    COUNT(DISTINCT location_id) num_of_audit_locations
FROM auditor_report;
-- 1620 records


-- count recors in auditors report table
SELECT
    COUNT(*) num_of_audit_records
FROM auditor_report;
-- 1620 records


-- [XTRA] set the location id column as primary key in auditor report
ALTER TABLE auditor_report
ADD PRIMARY KEY(location_id);


-- [XTRA] set the location id column as foreign key
-- referencing location id in auditor response
SET FOREIGN_KEY_CHECKS=0;
ALTER TABLE visits
ADD FOREIGN KEY(location_id) 
REFERENCES auditor_report(location_id);


-- ver
SELECT
    location_id audited_location,
    COUNT(location_id) num_of_pre_audit_visit,
    type_of_water_source source_type
FROM auditor_report ar
INNER JOIN visits
USING (location_id)
GROUP BY 1
HAVING num_of_pre_audit_visit > 1
ORDER BY 2 DESC
;
-- 154 unique audited source locations were visited
-- more than once. hence auditor report has a 
-- one to many relationship the visits table



-- [XTRA] count of well records in water source table
SELECT COUNT(*) num_of_well_records
FROM water_source
WHERE
    type_of_water_source LIKE '%well%';
-- 17383 well records


-- [XTRA] count of unique well sources in water source table
SELECT COUNT(DISTINCT source_id) num_of_well_sources
FROM water_source
WHERE
    type_of_water_source LIKE '%well%';
-- 17383 unique well sources


-- [XTRA] count of well pollution records
SELECT COUNT(*) num_of_well_pollution_records
FROM well_pollution;
-- 17383 well pollution records


-- [XTRA] count of unique well sources in well pollution table
SELECT COUNT(DISTINCT source_id) num_of_well_source
FROM well_pollution;
-- 17383 num of unique well sources


-- [XTRA] hence water_source and well pollution 
-- has a one-to-one relationship with water sources
-- !!! correct in ERD


-- select location id and true water quality score from auditor's report
SELECT
    location_id,
    true_water_source_score
FROM auditor_report
-- LIMIT 10
;


-- join the visits table to the auditors table
-- select audit and visit locations, audit score and visit records
SELECT
    ar.location_id audit_location, 
    ar.true_water_source_score,
    v.location_id visit_location,
    v.record_id
FROM visits v
INNER JOIN auditor_report ar
USING (location_id)


-- join visits to auditors and water score
-- to compare auditor score and surveyor score
SELECT
    ar.location_id audit_location,
    ar.true_water_source_score,
    v.location_id visit_location,
    v.record_id,
    wq.subjective_quality_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id);


-- refactor survey vs. audit score comparison
SELECT
    location_id,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)


-- records where surveyor score and audit score are equal
SELECT
    location_id,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE
    ar.true_water_source_score = wq.subjective_quality_score
-- 2505 records (some sources had multiple visits)


-- records where surveyor score and audit score are equal
-- and visits count is equal to 1 (first or only visit)
SELECT
    location_id,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE
    ar.true_water_source_score = wq.subjective_quality_score
    AND
    v.visit_count = 1;
-- 1518 records with legit surveyor scores


-- [XTRA] what if we compare auditors score to most recent surveyor score
-- per location for fairness. we only filter for records representing
-- the most recent visit per location [ie. max(visit_count) partitioned by location id
-- then record id where visit_count = max(visit_count)
WITH visit_counter AS (
    SELECT
        location_id,
        record_id,
        v.visit_count,
        MAX(v.visit_count) OVER(PARTITION BY location_id) max_visit
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    WHERE wq.visit_count = v.visit_count
)
SELECT
    location_id,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE
    ar.true_water_source_score = wq.subjective_quality_score
    AND record_id IN (
        -- returns the most recent visit max(visit_count) per location_id
            SELECT
                record_id
            FROM
                visit_counter
            WHERE
                visit_count = max_visit
    )
;
-- [XTRA] still 1518 records where suveyor score [on most recent visit]
-- is equal to auditor score hence recency of visit per location is irrelevant


-- [XTRA] verify this by inspecting deviation of surveyor score for the location with
-- the highest visit count
SELECT
    location_id,
    record_id,
    wq.visit_count,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE v.location_id IN (
    -- returns a list of location_id having records with
    -- the max visit counts in visits [list]
    SELECT
        location_id
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    WHERE v.visit_count = (
        -- returns the max visit count value in visits [scalar]
        SELECT MAX(visit_count)
        FROM visits 
    )
)   
-- !!! TOGGLE FILTERS BELOW FOR SURVEYOR'S SCORE EQUAL OR UNEQUAL TO AUDITOR'S
-- AND subjective_quality_score = true_water_source_score
-- AND subjective_quality_score != true_water_source_score
ORDER BY location_id, visit_count
-- [XTRA] we should consider recency in real world setting!!!


-- records where surveyor score and audit score are NOT equal
-- and visits count is equal to 1 (first or only visit)
SELECT
    location_id,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE
    ar.true_water_source_score != wq.subjective_quality_score
    AND
    v.visit_count = 1;
-- 102 records with inaccurate surveyor scores


-- since some water source scores are dubious, let's check if
-- recorded water source type are accurate.
SELECT
    location_id,
    ar.type_of_water_source auditor_source,
    ws.type_of_water_source survey_source,
    record_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
INNER JOIN water_source ws
USING(source_id)
WHERE
    ar.true_water_source_score != wq.subjective_quality_score
    AND
    v.visit_count = 1
    -- the filter below (!!!TOGGLE) returns no records so 
    -- the type of water source surveyed are accurate
    -- AND ar.type_of_water_source != ws.type_of_water_source
    ;


-- so, who are the employees recording these inaccurate source scores?
-- add employee id to select clause of the previous query 
-- (with 102 inaccurate source score records) 
SELECT
    location_id,
    record_id,
    assigned_employee_id,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
WHERE
    ar.true_water_source_score != wq.subjective_quality_score
    AND
    v.visit_count = 1;


-- so, who are the employees recording these inaccurate source scores?
-- join the previous query(with 102 inaccurate source score records)
-- to employee table and extract employee names
SELECT
    location_id,
    record_id,
    employee_name,
    ar.true_water_source_score auditor_score,
    wq.subjective_quality_score surveyor_score
FROM visits v
INNER JOIN auditor_report ar
USING(location_id)
INNER JOIN water_quality wq
USING(record_id)
INNER JOIN employee e
USING(assigned_employee_id)
WHERE
    ar.true_water_source_score != wq.subjective_quality_score
    AND
    v.visit_count = 1;


-- with incorrect records query as CTE, select all columns
-- incorrect records is better as a temp table or view
WITH incorrect_records AS (
    SELECT
        location_id,
        record_id,
        employee_name,
        ar.true_water_source_score auditor_score,
        wq.subjective_quality_score surveyor_score
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    INNER JOIN employee e
    USING(assigned_employee_id)
    WHERE
        ar.true_water_source_score != wq.subjective_quality_score
        AND
        v.visit_count = 1
)
SELECT *
FROM incorrect_records;


-- unique list of employee names from incorrect records query
WITH incorrect_records AS (
    SELECT
        location_id,
        record_id,
        employee_name,
        ar.true_water_source_score auditor_score,
        wq.subjective_quality_score surveyor_score
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    INNER JOIN employee e
    USING(assigned_employee_id)
    WHERE
        ar.true_water_source_score != wq.subjective_quality_score
        AND
        v.visit_count = 1
)
SELECT DISTINCT employee_name
FROM incorrect_records
ORDER BY 1;


-- number of erronous records per employee in incorrect records query
WITH incorrect_records AS (
    SELECT
        location_id,
        record_id,
        employee_name,
        ar.true_water_source_score auditor_score,
        wq.subjective_quality_score surveyor_score
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    INNER JOIN employee e
    USING(assigned_employee_id)
    WHERE
        ar.true_water_source_score != wq.subjective_quality_score
        AND
        v.visit_count = 1
)
SELECT
    employee_name,
    COUNT(record_id) number_of_mistakes
FROM incorrect_records
GROUP BY 1
ORDER BY 2 DESC


-- [XTRA] showing honest_mistake / possible_corruption divide 
-- using lead difference in the number of erronous records 
-- per employee in incorrect records query
WITH incorrect_records AS (
    SELECT
        location_id,
        record_id,
        employee_name,
        ar.true_water_source_score auditor_score,
        wq.subjective_quality_score surveyor_score
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    INNER JOIN employee e
    USING(assigned_employee_id)
    WHERE
        ar.true_water_source_score != wq.subjective_quality_score
        AND
        v.visit_count = 1
)
SELECT
    employee_name,
    COUNT(record_id) number_of_mistakes,
    -- lead difference shows honest_mistake / possible_corruption split
    COUNT(record_id) - LEAD(COUNT(record_id)) OVER(ORDER BY COUNT(record_id) DESC) lead_diff
FROM incorrect_records
GROUP BY 1
ORDER BY 2 DESC;
-- noticeable difference between 'Zuriel Matembo' errors and 'Lalitha Kaburi'


-- average number_of_mistakes made by employees
WITH error_count AS (
    WITH incorrect_records AS (
        SELECT
            location_id,
            record_id,
            employee_name,
            ar.true_water_source_score auditor_score,
            wq.subjective_quality_score surveyor_score
        FROM visits v
        INNER JOIN auditor_report ar
        USING(location_id)
        INNER JOIN water_quality wq
        USING(record_id)
        INNER JOIN employee e
        USING(assigned_employee_id)
        WHERE
            ar.true_water_source_score != wq.subjective_quality_score
            AND
            v.visit_count = 1
    )
    SELECT
        employee_name,
        COUNT(record_id) number_of_mistakes
    FROM incorrect_records
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    AVG(number_of_mistakes) avg_error_count_per_empl
FROM error_count
;


-- employees with number_of_mistakes above the average number_of_mistakes
WITH error_count AS (
    WITH incorrect_records AS (
        SELECT
            location_id,
            record_id,
            employee_name,
            ar.true_water_source_score auditor_score,
            wq.subjective_quality_score surveyor_score
        FROM visits v
        INNER JOIN auditor_report ar
        USING(location_id)
        INNER JOIN water_quality wq
        USING(record_id)
        INNER JOIN employee e
        USING(assigned_employee_id)
        WHERE
            ar.true_water_source_score != wq.subjective_quality_score
            AND
            v.visit_count = 1
    )
    SELECT
        employee_name,
        COUNT(record_id) number_of_mistakes
    FROM incorrect_records
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    employee_name,
    number_of_mistakes
    -- uncomment line below to see average number_of_mistakes (6.00)
    -- ,(SELECT AVG(number_of_mistakes) FROM error_count)
FROM error_count
WHERE
    number_of_mistakes > (
        SELECT AVG(number_of_mistakes)
        FROM error_count
    )
;


-- Refactoring:


-- create view with incorrect_records CTE: add auditors comment
DROP VIEW IF EXISTS incorrect_records;
CREATE VIEW incorrect_records AS (
    SELECT
        location_id,
        record_id,
        employee_name,
        ar.true_water_source_score auditor_score,
        wq.subjective_quality_score surveyor_score,
        statements
    FROM visits v
    INNER JOIN auditor_report ar
    USING(location_id)
    INNER JOIN water_quality wq
    USING(record_id)
    INNER JOIN employee e
    USING(assigned_employee_id)
    WHERE
        ar.true_water_source_score != wq.subjective_quality_score
        AND
        v.visit_count = 1
);


-- inspect incorrect_records view:
SELECT *
FROM incorrect_records;


-- error_count as CTE referencing incorrect_records view
WITH error_count AS (
    SELECT
        employee_name,
        COUNT(record_id) number_of_mistakes
    FROM incorrect_records
    /*
    Incorrect_records is a view that joins 
    the audit report to the database
    for records where the auditor and
    employees scores are different
    */
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT *
FROM error_count;


-- averge number_of_mistakes in error_count
WITH error_count AS (
    SELECT
        employee_name,
        COUNT(record_id) number_of_mistakes
    FROM incorrect_records
    /*
    Incorrect_records is a view that joins 
    the audit report to the database
    for records where the auditor and
    employees scores are different
    */
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT AVG(number_of_mistakes) avg_number_of_mistakes
FROM error_count;


-- employees with number_of_mistakes above the average number_of_mistakes
WITH error_count AS (
    SELECT
        employee_name,
        COUNT(record_id) number_of_mistakes
    FROM incorrect_records
    /*
    Incorrect_records is a view that joins 
    the audit report to the database
    for records where the auditor and
    employees scores are different
    */
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    employee_name,
    number_of_mistakes
FROM 
    error_count
WHERE
    number_of_mistakes > (
        SELECT AVG(number_of_mistakes)
        FROM error_count
    )
;


-- suspect list CTE: employees and number_of_mistakes above average
WITH suspect_list AS (
    WITH error_count AS (
        SELECT
            employee_name,
            COUNT(record_id) number_of_mistakes
        FROM incorrect_records
        /*
        Incorrect_records is a view that joins 
        the audit report to the database
        for records where the auditor and
        employees scores are different
        */
        GROUP BY 1
        ORDER BY 2 DESC
    )
    SELECT
        employee_name,
        number_of_mistakes
    FROM 
        error_count
    WHERE
        number_of_mistakes > (
            SELECT AVG(number_of_mistakes)
            FROM error_count
        )
)
SELECT employee_name
FROM suspect_list;


-- query incorrect_records view for records made by suspects
WITH suspect_list AS (
    WITH error_count AS (
        SELECT
            employee_name,
            COUNT(record_id) number_of_mistakes
        FROM incorrect_records
        /*
        Incorrect_records is a view that joins 
        the audit report to the database
        for records where the auditor and
        employees scores are different
        */
        GROUP BY 1
        ORDER BY 2 DESC
    )
    SELECT
        employee_name,
        number_of_mistakes
    FROM 
        error_count
    WHERE
        number_of_mistakes > (
            SELECT AVG(number_of_mistakes)
            FROM error_count
        )
)
SELECT
    employee_name,
    location_id,
    statements
FROM
    incorrect_records
WHERE
    employee_name IN (
        SELECT employee_name
        FROM suspect_list
    )
;
-- 71 out 102 records were made by suspects


-- inspect the statements from some locations surveyed by suspects
SELECT
    employee_name,
    location_id,
    statements
FROM
    incorrect_records
WHERE
    location_id IN ('AkRu04508', 'AkRu07310', 'KiRu29639', 'AmAm09607');
-- they all contained 'cash exchange' or 'cash transactions' in their statements
-- hence all 4 suspects could be allegedly involved in bribery


-- all incorrect records by suspects having 'cash' in their statements
WITH suspect_list AS (
    WITH error_count AS (
        SELECT
            employee_name,
            COUNT(record_id) number_of_mistakes
        FROM incorrect_records
        /*
        Incorrect_records is a view that joins 
        the audit report to the database
        for records where the auditor and
        employees scores are different
        */
        GROUP BY 1
        ORDER BY 2 DESC
    )
    SELECT
        employee_name,
        number_of_mistakes
    FROM 
        error_count
    WHERE
        number_of_mistakes > (
            SELECT AVG(number_of_mistakes)
            FROM error_count
        )
)
SELECT
    employee_name,
    location_id,
    statements
FROM
    incorrect_records
WHERE
    employee_name IN (
        SELECT employee_name
        FROM suspect_list
    )
    AND
    statements LIKE '%cash%'
;
-- 19 records returned having all 4 suspects
-- all 4 suspects could be allegedly involved in bribery.


-- all incorrect records by non-suspects having 'cash' in their statements
-- what if an employee who is not a suspect (did not make errors above the average)
-- was allegedly involved in bribery.
WITH suspect_list AS (
    WITH error_count AS (
        SELECT
            employee_name,
            COUNT(record_id) number_of_mistakes
        FROM incorrect_records
        /*
        Incorrect_records is a view that joins 
        the audit report to the database
        for records where the auditor and
        employees scores are different
        */
        GROUP BY 1
        ORDER BY 2 DESC
    )
    SELECT
        employee_name,
        number_of_mistakes
    FROM 
        error_count
    WHERE
        number_of_mistakes > (
            SELECT AVG(number_of_mistakes)
            FROM error_count
        )
)
SELECT
    employee_name,
    location_id,
    statements
FROM
    incorrect_records
WHERE
    employee_name NOT IN (
        SELECT employee_name
        FROM suspect_list
    )
    AND
    statements LIKE '%cash%'
;
-- 0 records returned
-- only suspects were allegedly involved in bribery.