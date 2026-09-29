# Diagrama de esquema estrella — Gold

**Grano de `FCT_TRIPS`:** una fila por registro de viaje Yellow Taxi deduplicado.

```mermaid
erDiagram
    DIM_DATE ||--o{ FCT_TRIPS : "pickup_date_key"
    DIM_DATE ||--o{ FCT_TRIPS : "dropoff_date_key"
    DIM_ZONE ||--o{ FCT_TRIPS : "pickup_location_id"
    DIM_ZONE ||--o{ FCT_TRIPS : "dropoff_location_id"

    DIM_DATE {
        NUMBER date_key PK
        DATE full_date
        NUMBER year
        NUMBER quarter
        NUMBER month
        VARCHAR month_name
        NUMBER day
        NUMBER day_of_week
        VARCHAR day_name
        BOOLEAN is_weekend
    }

    DIM_ZONE {
        INTEGER location_id PK
        VARCHAR borough
        VARCHAR zone
        VARCHAR service_zone
    }

    FCT_TRIPS {
        VARCHAR trip_id
        NUMBER pickup_date_key FK
        NUMBER dropoff_date_key FK
        INTEGER pickup_location_id FK
        INTEGER dropoff_location_id FK
        INTEGER vendor_id
        INTEGER ratecode_id
        INTEGER payment_type
        TIMESTAMP pickup_datetime
        TIMESTAMP dropoff_datetime
        INTEGER passenger_count
        FLOAT trip_distance
        INTEGER trip_duration_seconds
        FLOAT fare_amount
        FLOAT tip_amount
        FLOAT tolls_amount
        FLOAT total_amount
    }
```

`DIM_DATE` funciona como dimensión de rol para pickup y dropoff. `DIM_ZONE` se reutiliza de la misma forma para las zonas de origen y destino.

Las claves foráneas fueron validadas mediante tests `relationships` de dbt. Las claves de las dimensiones fueron validadas con `not_null` y `unique`.

`trip_id` es un identificador técnico determinístico; no corresponde a un identificador oficial proporcionado por NYC TLC.
