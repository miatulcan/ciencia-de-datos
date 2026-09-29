{{ config(
    materialized='table',
    schema='GOLD'
) }}

with trips as (

    select *
    from {{ ref('stg_yellow_taxi') }}

),

final as (

    select
        -- Technical identifier for the deduplicated trip record
        trip_record_hash as trip_id,

        -- Foreign keys: date dimension
        to_number(to_char(cast(pickup_datetime as date), 'YYYYMMDD'))
            as pickup_date_key,

        to_number(to_char(cast(dropoff_datetime as date), 'YYYYMMDD'))
            as dropoff_date_key,

        -- Foreign keys: zone dimension
        pickup_location_id,
        dropoff_location_id,

        -- Trip attributes
        vendor_id,
        ratecode_id,
        payment_type,
        store_and_fwd_flag,

        -- Exact timestamps
        pickup_datetime,
        dropoff_datetime,

        -- Measures
        passenger_count,
        trip_distance,
        trip_duration_seconds,

        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        total_amount,
        congestion_surcharge,
        airport_fee,
        cbd_congestion_fee,

        -- Data quality attributes
        has_missing_passenger_count,
        has_missing_ratecode,
        has_zero_distance,
        has_negative_fare,
        has_negative_total,
        has_zero_passengers,
        has_suspicious_passenger_count,
        has_invalid_duration,
        has_pickup_outside_source_month,
        has_dropoff_outside_source_month,

        -- Lineage / traceability
        source_file,
        source_year,
        source_month,
        ingested_at

    from trips

)

select *
from final