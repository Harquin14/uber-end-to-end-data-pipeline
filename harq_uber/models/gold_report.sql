/* 
====================================================
Driver Performance, Segmentation, & Retention Report
====================================================

Business Questions Answered:
1. Driver Segmentation: How do we segment our driver base into cohorts (Elite Earners, Steady Drivers, New/Casual) based on lifetime earnings and tenure?
2. Service Quality: What proportion of our fleet falls into top-tier quality vs. underperforming?
3. Churn & Retention: Which drivers are inactive or churning based on days since their last completed trip?
4. Productivity: What is the average monthly earning rate for each driver over their active lifespan?
5. Operational Volume: How much total workload (trips and distance) has each driver handled?

===================================================================================================================
Purpose:
Provides a pre-aggregated Gold layer model for BI tools to track driver lifetime value, performance tiers, and retention metrics.
====================================================
*/

WITH base_data AS (

    SELECT
        r.trip_id,
        r.driver_id,
        r.distance_km,
        r.fare_amount,
        r.trip_start_time,
        r.trip_end_time,
        d.driver_rating,
        d.full_name AS driver_name

    FROM {{ source('source_gold','facttrips') }} AS r

    LEFT JOIN {{ source('source_gold', 'dimdrivers') }} AS d
        ON r.driver_id = d.driver_id

),

aggregations AS (

    SELECT
        driver_id,
        driver_name,

        MAX(driver_rating) AS current_rating,

        COUNT(DISTINCT trip_id) AS total_trips,

        SUM(fare_amount) AS total_earnings,

        SUM(distance_km) AS total_distance,

        MIN(trip_start_time) AS first_trip_date,

        MAX(trip_end_time) AS last_trip_date,

        CAST(
            MONTHS_BETWEEN(
                MAX(trip_end_time),
                MIN(trip_start_time)
            ) AS INT
        ) AS active_months

    FROM base_data

    GROUP BY
        driver_id,
        driver_name

),

final AS (

    SELECT
        driver_id,
        driver_name,
        current_rating,

        CASE
            WHEN current_rating >= 4.90 THEN 'Top Rated'
            WHEN current_rating >= 4.70 THEN 'Highly Rated'
            WHEN current_rating >= 4.50 THEN 'Average'
            ELSE 'Needs Improvement'
        END AS rating_tier,

        CASE
            WHEN total_earnings > 10000
                 AND active_months >= 6
                THEN 'ELITE EARNER'

            WHEN total_earnings <= 10000
                 AND active_months >= 6
                THEN 'STEADY DRIVER'

            ELSE 'NEW / CASUAL'
        END AS driver_category,

        first_trip_date,
        last_trip_date,

        DATEDIFF(
            CURRENT_DATE(),
            CAST(last_trip_date AS DATE)
        ) AS days_since_last_trip,

        total_trips,
        CAST(total_earnings AS decimal(10,2)) AS total_earnings,
        CAST(total_distance AS decimal(10,2)) AS total_distance,
        active_months,

        CASE
            WHEN active_months = 0
                THEN total_earnings

            ELSE CAST((total_earnings / active_months) AS decimal(10,2))
        END AS average_monthly_earnings

    FROM aggregations

)

SELECT *
FROM final