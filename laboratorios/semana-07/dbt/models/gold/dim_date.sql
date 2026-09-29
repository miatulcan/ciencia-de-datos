{{ config(
    materialized='table',
    schema='GOLD'
) }}

with dates as (

    select cast(pickup_datetime as date) as full_date
    from {{ ref('stg_yellow_taxi') }}

    union

    select cast(dropoff_datetime as date) as full_date
    from {{ ref('stg_yellow_taxi') }}

),

final as (

    select
        to_number(to_char(full_date, 'YYYYMMDD')) as date_key,
        full_date,
        year(full_date) as year,
        quarter(full_date) as quarter,
        month(full_date) as month,
        monthname(full_date) as month_name,
        day(full_date) as day,
        dayofweekiso(full_date) as day_of_week,
        dayname(full_date) as day_name,

        case
            when dayofweekiso(full_date) in (6, 7) then true
            else false
        end as is_weekend

    from dates
    where full_date is not null

)

select *
from final