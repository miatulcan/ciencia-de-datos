{{ config(
    materialized='view',
    schema='SILVER'
) }}

with source as (

    select *
    from {{ source('bronze', 'yellow_taxi_trips_raw') }}

),

typed as (

    select
        RAW_RECORD:"VendorID"::integer as vendor_id,

        TO_TIMESTAMP_NTZ(
            RAW_RECORD:"tpep_pickup_datetime"::number,
            6
        ) as pickup_datetime,

        TO_TIMESTAMP_NTZ(
            RAW_RECORD:"tpep_dropoff_datetime"::number,
            6
        ) as dropoff_datetime,

        RAW_RECORD:"passenger_count"::integer as passenger_count,
        RAW_RECORD:"trip_distance"::float as trip_distance,
        RAW_RECORD:"RatecodeID"::integer as ratecode_id,
        RAW_RECORD:"store_and_fwd_flag"::varchar as store_and_fwd_flag,
        RAW_RECORD:"PULocationID"::integer as pickup_location_id,
        RAW_RECORD:"DOLocationID"::integer as dropoff_location_id,
        RAW_RECORD:"payment_type"::integer as payment_type,
        RAW_RECORD:"fare_amount"::float as fare_amount,
        RAW_RECORD:"extra"::float as extra,
        RAW_RECORD:"mta_tax"::float as mta_tax,
        RAW_RECORD:"tip_amount"::float as tip_amount,
        RAW_RECORD:"tolls_amount"::float as tolls_amount,
        RAW_RECORD:"improvement_surcharge"::float as improvement_surcharge,
        RAW_RECORD:"total_amount"::float as total_amount,
        RAW_RECORD:"congestion_surcharge"::float as congestion_surcharge,
        RAW_RECORD:"Airport_fee"::float as airport_fee,
        RAW_RECORD:"cbd_congestion_fee"::float as cbd_congestion_fee,

        SOURCE_FILE::varchar as source_file,
        SOURCE_YEAR::integer as source_year,
        SOURCE_MONTH::integer as source_month,
        INGESTED_AT as ingested_at

    from source

),

final as (

    select
        *,

        -- Deterministic fingerprint used to identify possible duplicate trips.
        -- This does NOT remove any rows.
        MD5(
            CONCAT_WS(
                '|',
                COALESCE(vendor_id::varchar, 'NULL'),
                COALESCE(pickup_datetime::varchar, 'NULL'),
                COALESCE(dropoff_datetime::varchar, 'NULL'),
                COALESCE(pickup_location_id::varchar, 'NULL'),
                COALESCE(dropoff_location_id::varchar, 'NULL'),
                COALESCE(passenger_count::varchar, 'NULL'),
                COALESCE(trip_distance::varchar, 'NULL'),
                COALESCE(fare_amount::varchar, 'NULL'),
                COALESCE(total_amount::varchar, 'NULL')
            )
        ) as trip_record_hash,

        -- Duration of the trip in seconds.
        DATEDIFF(
            'second',
            pickup_datetime,
            dropoff_datetime
        ) as trip_duration_seconds,

        -- Missing-value quality flags.
        passenger_count is null
            as has_missing_passenger_count,

        ratecode_id is null
            as has_missing_ratecode,

        -- Distance quality flags.
        trip_distance = 0
            as has_zero_distance,

        -- Monetary quality flags.
        fare_amount < 0
            as has_negative_fare,

        total_amount < 0
            as has_negative_total,

        -- Passenger-count quality flags.
        passenger_count = 0
            as has_zero_passengers,

        passenger_count > 8
            as has_suspicious_passenger_count,

        -- Temporal quality flags.
        dropoff_datetime < pickup_datetime
            as has_invalid_duration,

        (
            YEAR(pickup_datetime) != source_year
            OR MONTH(pickup_datetime) != source_month
        ) as has_pickup_outside_source_month,

        (
            YEAR(dropoff_datetime) != source_year
            OR MONTH(dropoff_datetime) != source_month
        ) as has_dropoff_outside_source_month

    from typed

),

deduplicated as (

    select *
    from final

    qualify row_number() over (
        partition by trip_record_hash
        order by ingested_at, source_file
    ) = 1

)

select *
from deduplicated