-- =============================================================================
-- Patient Referral Management Database  —  PostgreSQL
-- =============================================================================
-- Run this file top to bottom on an empty database.
--   Section 1  schema      13 tables, visit as the hub
--   Section 2  seed data   6 patients, 9 referrals (demonstration dataset)
--   Section 3  analysis    the 9 reporting queries (Q1-Q9)
--   Section 4  charts      the 6 aggregations exported to Tableau
--
-- Note on types: every identifier is VARCHAR, not CHAR. CHAR(n) is fixed-width
-- and pads short values with spaces ('PH01      '), which is invisible inside
-- Postgres but appears literally in CSV exports and Tableau axis labels.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — SCHEMA
-- =============================================================================

-- Drop first so the script is re-runnable. Order matters: children before parents,
-- or CASCADE handles it. Point this at a scratch database, not a live one.
DROP TABLE IF EXISTS communication_table CASCADE;
DROP TABLE IF EXISTS billing CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS disease CASCADE;
DROP TABLE IF EXISTS vital_signs CASCADE;
DROP TABLE IF EXISTS visit CASCADE;
DROP TABLE IF EXISTS medication_history CASCADE;
DROP TABLE IF EXISTS family_history CASCADE;
DROP TABLE IF EXISTS social_history CASCADE;
DROP TABLE IF EXISTS medical_history CASCADE;
DROP TABLE IF EXISTS laboratory_tests CASCADE;
DROP TABLE IF EXISTS physician_main CASCADE;
DROP TABLE IF EXISTS patient_demographics CASCADE;

CREATE TABLE patient_demographics (
    patient_id      VARCHAR(10) PRIMARY KEY,
    first_name      VARCHAR(45),
    middle_name     VARCHAR(45),
    last_name       VARCHAR(45),
    gender          VARCHAR(10),
    date_of_birth   DATE,
    phone_number    VARCHAR(12),
    address         VARCHAR(100)
);
CREATE TABLE physician_main (
    physician_id    VARCHAR(10) PRIMARY KEY,
    first_name      VARCHAR(45),
    last_name       VARCHAR(45),
    npi             INT,
    specialization  VARCHAR(45),
    hospital        VARCHAR(200)
);
CREATE TABLE laboratory_tests (
    test_id         VARCHAR(10) PRIMARY KEY,
    department      VARCHAR(45),
    investigation   VARCHAR(250)
);
CREATE TABLE medical_history (
    id              SERIAL PRIMARY KEY,
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    disease_history VARCHAR(250),
    allergies       VARCHAR(250)
);
CREATE TABLE social_history (
    id              SERIAL PRIMARY KEY,
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    details         VARCHAR(225),
    duration        VARCHAR(45)
);
CREATE TABLE family_history (
    id              SERIAL PRIMARY KEY,
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    relation        VARCHAR(50),
    details         VARCHAR(225)
);
CREATE TABLE medication_history (
    id              SERIAL PRIMARY KEY,
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    medication      VARCHAR(200),
    dose            VARCHAR(50),
    start_date      DATE
);
CREATE TABLE visit (
    visit_id        VARCHAR(10) PRIMARY KEY,
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    physician_id    VARCHAR(10) REFERENCES physician_main(physician_id),
    referral_id     VARCHAR(15) UNIQUE,
    referral_status VARCHAR(20),
    visit_datetime  TIMESTAMP,
    hospital        VARCHAR(200)
);
CREATE TABLE vital_signs (
    visit_id        VARCHAR(10) PRIMARY KEY REFERENCES visit(visit_id),
    height          DECIMAL(5,2),
    weight          DECIMAL(5,2),
    systolic        INT,
    diastolic       INT,
    temperature     DECIMAL(4,2),
    pulse_rate      INT,
    respiratory_rate INT
);
CREATE TABLE disease (
    serial_number   SERIAL PRIMARY KEY,
    icd             VARCHAR(200),
    patient_id      VARCHAR(10) REFERENCES patient_demographics(patient_id),
    specialization  VARCHAR(45),
    final_diagnosis VARCHAR(150),
    test_id         VARCHAR(10) REFERENCES laboratory_tests(test_id),
    visit_id        VARCHAR(10) REFERENCES visit(visit_id)
);
CREATE TABLE orders (
    order_id        VARCHAR(10) PRIMARY KEY,
    visit_id        VARCHAR(10) REFERENCES visit(visit_id),
    test_id         VARCHAR(10) REFERENCES laboratory_tests(test_id),
    order_date      TIMESTAMP
);
CREATE TABLE billing (
    billing_id      VARCHAR(10) PRIMARY KEY,
    visit_id        VARCHAR(10) REFERENCES visit(visit_id),
    insurance_company VARCHAR(200),
    coverage        VARCHAR(15)
);
CREATE TABLE communication_table (
    communication_id VARCHAR(10) PRIMARY KEY,
    referral_id     VARCHAR(15) REFERENCES visit(referral_id),
    communication_date TIMESTAMP,
    sent_to         VARCHAR(45),
    method          VARCHAR(45),
    notes           VARCHAR(350)
);


-- =============================================================================
-- SECTION 2 — SEED DATA
-- Fictional. 6 patients, 6 physicians, 9 referrals, 14 communications.
-- =============================================================================

INSERT INTO patient_demographics VALUES
('PT01','John','Francis','Diggle','Male','1990-01-15','617-555-0101','Boston'),
('PT02','Laurel','Quinton','Lance','Female','1985-03-22','617-555-0102','Boston'),
('PT03','Oliver','Robert','Queen','Male','1978-07-30','617-555-0103','Cambridge'),
('PT04','Sara','Quinton','Lance','Female','1992-12-11','617-555-0104','Somerville'),
('PT05','Slade','Albert','Wilson','Male','2000-09-09','617-555-0105','Medford'),
('PT06','Jerry','Andrew','Constantine','Male','2001-09-09','617-555-0106','Quincy');
INSERT INTO physician_main VALUES
('PH01','Marc','Spector',1000000001,'Cardiology','Mass General Brigham Hospital'),
('PH02','Emma','Johnson',1000000002,'Cardiology','Tufts Medical Center'),
('PH03','Diana','Prince',1000000003,'Internal Medicine','Tufts Medical Center'),
('PH04','Olivia','Brown',1000000004,'Pulmonology','Beth Israel Hospital'),
('PH05','William','Jones',1000000005,'Urology','Mass General Brigham Hospital'),
('PH06','Ava','Garcia',1000000006,'Nephrology','Beth Israel Hospital');
INSERT INTO laboratory_tests VALUES
('LT01','Hematology','Complete Blood Count'),
('LT02','Radiology','Chest X-Ray'),
('LT03','Biochemistry','Lipid Panel'),
('LT04','Cardiology','Electrocardiogram');
INSERT INTO medical_history (patient_id, disease_history, allergies) VALUES
('PT01','Obesity','Dairy Allergy'),
('PT02','Skin Infections',NULL),
('PT03','Bronchitis','Dust'),
('PT04','Coronary artery disease','Citrus Fruits'),
('PT05','GERD',NULL),
('PT06','UTI','');
INSERT INTO social_history (patient_id, details, duration) VALUES
('PT01','Non-smoker','N/A'),
('PT03','Former smoker','10 years');
INSERT INTO family_history (patient_id, relation, details) VALUES
('PT04','Father','Cardiac history'),
('PT03','Mother','Asthma');
INSERT INTO medication_history (patient_id, medication, dose, start_date) VALUES
('PT04','Atorvastatin','20mg','2023-06-01'),
('PT04','Aspirin','75mg','2023-06-01'),
('PT01','Metformin','500mg','2022-01-15');
INSERT INTO visit VALUES
('V001','PT01','PH01','R001','completed','2024-01-10 09:00:00','Mass General Brigham Hospital'),
('V002','PT01','PH01','R002','completed','2023-10-05 09:00:00','Mass General Brigham Hospital'),
('V003','PT02','PH03','R003','scheduled','2024-10-09 10:00:00','Tufts Medical Center'),
('V004','PT02','PH03','R004','completed','2024-05-01 10:00:00','Tufts Medical Center'),
('V005','PT03','PH01','R005','completed','2024-07-11 11:00:00','Mass General Brigham Hospital'),
('V006','PT03','PH04','R006','completed','2024-03-01 11:00:00','Beth Israel Hospital'),
('V007','PT04','PH01','R007','initiated','2024-03-19 14:00:00','Mass General Brigham Hospital'),
('V008','PT05','PH03','R008','completed','2024-05-16 14:00:00','Tufts Medical Center'),
('V009','PT06','PH04','R009','scheduled','2024-03-14 15:00:00','Beth Israel Hospital');
INSERT INTO vital_signs VALUES
('V001',178,85.0,122,80,36.80,72,16),
('V002',178,86.0,120,78,36.70,70,16),
('V003',165,60.0,118,76,37.00,68,15),
('V004',165,61.0,119,77,36.90,69,15),
('V005',180,90.0,128,84,37.10,74,17),
('V006',180,90.5,126,82,37.20,73,17),
('V007',160,58.0,145,100,37.50,88,18),
('V008',175,70.0,121,79,36.80,70,16),
('V009',170,68.0,124,80,37.00,72,16);
INSERT INTO disease (icd, patient_id, specialization, final_diagnosis, test_id, visit_id) VALUES
('I25.1','PT03','Cardiology','Arrhythmia','LT04','V005'),
('J40'  ,'PT03','Pulmonary','Bronchitis','LT02','V006'),
('I25.1','PT04','Cardiology','Coronary artery disease','LT04','V007'),
('L08.9','PT02','Dermatology','Skin infection','LT01','V003'),
('N39.0','PT06','Urology','UTI','LT01','V009');
INSERT INTO orders VALUES
('O001','V001','LT01','2024-01-10 09:30:00'),
('O002','V003','LT01','2024-10-09 10:30:00'),
('O003','V004','LT03','2024-05-01 10:30:00'),
('O004','V005','LT04','2024-07-11 11:30:00'),
('O005','V006','LT02','2024-03-01 11:30:00'),
('O006','V007','LT04','2024-03-19 14:30:00'),
('O007','V007','LT03','2024-03-19 15:00:00'),
('O008','V008','LT01','2024-05-16 14:30:00'),
('O009','V008','LT03','2024-05-16 15:00:00'),
('O010','V009','LT01','2024-03-14 15:30:00'),
('O011','V009','LT02','2024-03-14 16:00:00');
INSERT INTO billing VALUES
('B001','V001','Blue Cross','Full'),
('B002','V003','Aetna','Partial'),
('B003','V005','Blue Cross','Full'),
('B004','V007','Cigna','Full'),
('B005','V008','Aetna','Partial'),
('B006','V009','Medicare','Full');
INSERT INTO communication_table VALUES
('C001','R001','2024-01-11 09:00:00','Dr. Brown','Email','Referral sent'),
('C002','R002','2023-10-06 09:00:00','Dr. Brown','Email','Follow-up'),
('C003','R003','2024-10-10 09:00:00','Dr. Prince','Email','Referral sent'),
('C004','R004','2024-05-02 09:00:00','Dr. Prince','Voicemail','Left message'),
('C005','R005','2024-07-12 09:00:00','Dr. Spector','Email','Results shared'),
('C006','R006','2024-03-02 09:00:00','Dr. Brown','Voicemail','Left message'),
('C007','R007','2024-03-20 09:00:00','Dr. Spector','Email','Urgent referral'),
('C008','R008','2024-05-17 09:00:00','Dr. Prince','Voicemail','Left message'),
('C009','R009','2024-03-15 09:00:00','Dr. Brown','Phone','Spoke directly'),
('C010','R001','2024-01-12 09:00:00','Dr. Brown','Email','Reminder'),
('C011','R003','2024-10-11 09:00:00','Dr. Prince','Voicemail','Left message'),
('C012','R005','2024-07-13 09:00:00','Dr. Spector','Voicemail','Reminder'),
('C013','R007','2024-03-21 09:00:00','Dr. Spector','Email','Reminder'),
('C014','R009','2024-03-16 09:00:00','Dr. Brown','Phone','Confirmed');


-- =============================================================================
-- SECTION 3 — ANALYSIS QUERIES
--   Q1, Q6, Q9  -> data completeness  (the "referral arrives empty" problem)
--   Q2, Q5, Q7, Q8 -> tracking & risk (the "referral gets lost" problem)
--   Q3, Q4      -> capacity and population views
-- =============================================================================


-- Q1: Comprehensive patient summary with visit count
--     LEFT JOIN keeps patients with no history row and no visits; GROUP BY
--     collapses the row multiplication the second join creates.
SELECT pd.patient_id, pd.first_name, pd.middle_name, pd.last_name,
       pd.gender, pd.date_of_birth,
       mh.allergies, mh.disease_history,
       COUNT(v.visit_id) AS total_visits
FROM patient_demographics pd
LEFT JOIN medical_history mh ON pd.patient_id = mh.patient_id
LEFT JOIN visit v            ON pd.patient_id = v.patient_id
GROUP BY pd.patient_id, pd.first_name, pd.middle_name, pd.last_name,
         pd.gender, pd.date_of_birth, mh.allergies, mh.disease_history
ORDER BY pd.patient_id;


-- Q2: High-risk patients (numeric BP compare, LIKE, OR)
--     Vitals belong to a VISIT, not a patient, so the path is
--     patient -> visit -> vitals. OR widens the net: any one factor flags.
SELECT pd.patient_id, pd.first_name, pd.last_name,
       vs.systolic, vs.diastolic, vs.temperature,
       mh.disease_history, mh.allergies
FROM patient_demographics pd
JOIN visit v            ON pd.patient_id = v.patient_id
JOIN vital_signs vs     ON v.visit_id    = vs.visit_id
JOIN medical_history mh ON pd.patient_id = mh.patient_id
WHERE vs.systolic > 130
   OR vs.diastolic > 90
   OR vs.temperature > 38
   OR mh.disease_history LIKE '%Cardiac%'
   OR mh.disease_history LIKE '%Coronary%'
   OR mh.disease_history LIKE '%Diabetes%'
ORDER BY pd.patient_id;


-- Q3: Physicians with fewer visits than average (LEFT JOIN, HAVING + derived table)
--     LEFT JOIN is essential: a physician with ZERO visits is exactly who we want.
--     HAVING, not WHERE, because we filter on a COUNT that only exists after grouping.
SELECT pm.physician_id,
       CONCAT(pm.first_name, ' ', pm.last_name) AS full_name,
       pm.specialization,
       COUNT(v.visit_id) AS total_visits
FROM physician_main pm
LEFT JOIN visit v ON pm.physician_id = v.physician_id
GROUP BY pm.physician_id, pm.first_name, pm.last_name, pm.specialization
HAVING COUNT(v.visit_id) < (
    SELECT AVG(vc) FROM (
        SELECT COUNT(v2.visit_id) AS vc
        FROM physician_main pm2
        LEFT JOIN visit v2 ON pm2.physician_id = v2.physician_id
        GROUP BY pm2.physician_id
    ) AS avg_visits
)
ORDER BY total_visits ASC;


-- Q4: Age group + most recent order date (CASE, EXTRACT/AGE, MAX)
--     Age is calculated, not stored. CASE stops at the first true branch.
SELECT pd.patient_id,
       CONCAT(pd.first_name, ' ', pd.last_name) AS full_name,
       EXTRACT(YEAR FROM AGE(pd.date_of_birth))::INT AS age,
       CASE
           WHEN EXTRACT(YEAR FROM AGE(pd.date_of_birth)) > 60 THEN 'Senior'
           WHEN EXTRACT(YEAR FROM AGE(pd.date_of_birth)) BETWEEN 40 AND 60 THEN 'Middle-aged'
           ELSE 'Young Adult'
       END AS age_group,
       MAX(o.order_date) AS most_recent_order_date
FROM patient_demographics pd
JOIN visit v  ON pd.patient_id = v.patient_id
JOIN orders o ON v.visit_id    = o.visit_id
WHERE EXTRACT(YEAR FROM AGE(pd.date_of_birth)) > 30
GROUP BY pd.patient_id, pd.first_name, pd.last_name, pd.date_of_birth
ORDER BY age DESC, most_recent_order_date DESC;


-- Q5: Patients referred to the lab more than once in 2024
--     Two filters in two places: "during 2024" filters raw rows (WHERE, before
--     grouping); "more than once" filters the count (HAVING, after grouping).
SELECT pd.patient_id,
       CONCAT(pd.first_name, ' ', pd.last_name) AS full_name,
       COUNT(o.order_id) AS total_lab_orders
FROM patient_demographics pd
JOIN visit v             ON pd.patient_id = v.patient_id
JOIN orders o            ON v.visit_id    = o.visit_id
JOIN laboratory_tests lt ON o.test_id     = lt.test_id
WHERE o.order_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY pd.patient_id, pd.first_name, pd.last_name
HAVING COUNT(o.order_id) > 1
ORDER BY total_lab_orders DESC, pd.patient_id;


-- Q6: Patients in BOTH Cardiology and Pulmonary (IN subquery = set intersection)
--     A single row can't be both specialties, so a plain AND returns nothing.
--     The subquery builds the pulmonary list; IN keeps cardiology rows in it.
SELECT DISTINCT d.patient_id, d.specialization, d.final_diagnosis
FROM disease d
WHERE d.specialization = 'Cardiology'
  AND d.patient_id IN (
      SELECT patient_id FROM disease WHERE specialization = 'Pulmonary'
  )
ORDER BY d.patient_id;


-- Q7: Communication method used most (GROUP BY + COUNT + ORDER BY DESC)
--     How a referral is chased is itself a risk signal.
SELECT ct.method AS communication_method,
       COUNT(*)  AS usage_count,
       CASE
           WHEN ct.method = 'Email' THEN 'Electronic Communication'
           WHEN ct.method = 'Phone' THEN 'Verbal Communication'
           ELSE 'Other Communication'
       END AS communication_category
FROM communication_table ct
WHERE ct.method IS NOT NULL AND ct.method <> ''
GROUP BY ct.method
ORDER BY usage_count DESC;


-- Q8: Share of referred patients per hospital (scalar subquery denominator)
--     Postgres does INTEGER division (3/6 = 0), so the numerator is cast with
--     ::numeric. MySQL returns 0.5 automatically - a real dialect difference.
--     NOTE: a patient referred to two hospitals counts once at each, so these
--     shares can sum to more than 100%. It is "share of patients who touched
--     each hospital", not a partition of the population.
SELECT v.hospital,
       COUNT(DISTINCT v.patient_id) AS referred_patients,
       ROUND(
           COUNT(DISTINCT v.patient_id)::numeric /
           (SELECT COUNT(DISTINCT patient_id) FROM visit) * 100, 2
       ) AS referral_percentage
FROM visit v
WHERE v.hospital IS NOT NULL
GROUP BY v.hospital
ORDER BY referral_percentage DESC;


-- Q9: Patients with no allergy recorded (LEFT JOIN, NULL handling)
--     LEFT JOIN keeps patients with no medical_history row at all - the most
--     incomplete records, which INNER JOIN would silently hide. Catch both
--     NULL (never entered) and '' (entered blank). Never test = NULL.
SELECT pd.patient_id, pd.first_name, pd.last_name, pd.gender, pd.date_of_birth
FROM patient_demographics pd
LEFT JOIN medical_history mh ON pd.patient_id = mh.patient_id
WHERE mh.allergies IS NULL OR mh.allergies = ''
ORDER BY pd.patient_id;


-- =============================================================================
-- SECTION 4 — CHART QUERIES
-- Each result was exported to CSV and built as one Tableau sheet.
-- =============================================================================


-- Chart 1 · Referral status distribution
SELECT referral_status, COUNT(*) AS referrals
FROM visit
GROUP BY referral_status
ORDER BY referrals DESC;


-- Chart 2 · Referral load per physician  (Q3 without the HAVING filter, so the
--           chart can show the full distribution with an average line at 1.5)
SELECT pm.physician_id,
       CONCAT(pm.first_name, ' ', pm.last_name) AS physician,
       pm.specialization,
       pm.hospital,
       COUNT(v.visit_id) AS referrals
FROM physician_main pm
LEFT JOIN visit v ON pm.physician_id = v.physician_id
GROUP BY pm.physician_id, pm.first_name, pm.last_name, pm.specialization, pm.hospital
ORDER BY referrals DESC;


-- Chart 3 · Communication methods  (= Q7)
SELECT ct.method AS communication_method,
       COUNT(*)  AS messages,
       CASE
           WHEN ct.method = 'Email' THEN 'Electronic Communication'
           WHEN ct.method = 'Phone' THEN 'Verbal Communication'
           ELSE 'Other Communication'
       END AS communication_category
FROM communication_table ct
WHERE ct.method IS NOT NULL AND ct.method <> ''
GROUP BY ct.method
ORDER BY messages DESC;


-- Chart 4 · Referral volume by receiving hospital  (Q8 plus a raw referral count)
SELECT v.hospital,
       COUNT(*) AS referrals,
       COUNT(DISTINCT v.patient_id) AS referred_patients
FROM visit v
WHERE v.hospital IS NOT NULL
GROUP BY v.hospital
ORDER BY referrals DESC;


-- Chart 5 · Investigations ordered  (four-table join chain from Q5)
SELECT lt.department, lt.investigation, COUNT(*) AS times_ordered
FROM orders o
JOIN laboratory_tests lt ON o.test_id = lt.test_id
GROUP BY lt.department, lt.investigation
ORDER BY times_ordered DESC;


-- Chart 6 · Record completeness by data element
--     What fraction of patients have each part of the clinical record populated.
--     The denominator is a subquery, not a hardcoded 6, so the query survives
--     the dataset growing.
SELECT 'Disease history' AS data_element,
       COUNT(DISTINCT patient_id) AS patients_with_data,
       ROUND(100.0 * COUNT(DISTINCT patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0) AS pct_of_patients
FROM medical_history WHERE disease_history IS NOT NULL AND disease_history <> ''
UNION ALL
SELECT 'Vital signs', COUNT(DISTINCT v.patient_id),
       ROUND(100.0 * COUNT(DISTINCT v.patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0)
FROM visit v JOIN vital_signs vs ON v.visit_id = vs.visit_id
UNION ALL
SELECT 'Allergies', COUNT(DISTINCT patient_id),
       ROUND(100.0 * COUNT(DISTINCT patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0)
FROM medical_history WHERE allergies IS NOT NULL AND allergies <> ''
UNION ALL
SELECT 'Medication history', COUNT(DISTINCT patient_id),
       ROUND(100.0 * COUNT(DISTINCT patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0)
FROM medication_history
UNION ALL
SELECT 'Social history', COUNT(DISTINCT patient_id),
       ROUND(100.0 * COUNT(DISTINCT patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0)
FROM social_history
UNION ALL
SELECT 'Family history', COUNT(DISTINCT patient_id),
       ROUND(100.0 * COUNT(DISTINCT patient_id) /
             (SELECT COUNT(*) FROM patient_demographics), 0)
FROM family_history
ORDER BY pct_of_patients DESC, data_element;
