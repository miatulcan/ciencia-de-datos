{{ config(
    materialized='table',
    schema='GOLD'
) }}

with zones as (

    select *
    from {{ ref('taxi_zone_lookup') }}

)

select
    LOCATIONID::integer as location_id,
    trim(BOROUGH)::varchar as borough,
    trim(ZONE)::varchar as zone,
    trim(SERVICE_ZONE)::varchar as service_zone

from zones