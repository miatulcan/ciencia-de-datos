# Diagrama de arquitectura — NYC Yellow Taxi ELT

```mermaid
flowchart LR
    A["NYC TLC<br/>Yellow Taxi Parquet"] --> B["Python ingestion<br/>Docker"]
    B --> C["Snowflake BRONZE<br/>YELLOW_TAXI_TRIPS_RAW"]
    C --> D["dbt SILVER<br/>STG_YELLOW_TAXI"]
    E["NYC TLC<br/>Taxi Zone Lookup CSV"] --> F["dbt seed<br/>TAXI_ZONE_LOOKUP"]
    D --> G["dbt GOLD"]
    F --> G
    G --> H["DIM_DATE"]
    G --> I["DIM_ZONE"]
    G --> J["FCT_TRIPS"]
    K["dbt tests<br/>not_null · unique · relationships"] --> D
    K --> H
    K --> I
    K --> J
```

## Flujo

1. Los archivos mensuales de NYC Yellow Taxi se descargan automáticamente desde la fuente pública de NYC TLC.
2. La ingesta se ejecuta dentro de Docker y carga los registros originales en Snowflake Bronze.
3. Bronze conserva el registro fuente en `VARIANT` y agrega metadata de archivo, año, mes y fecha de ingesta.
4. dbt transforma Bronze en Silver, donde se tipan los campos, se generan indicadores de calidad y se eliminan duplicados exactos identificados mediante un hash determinístico.
5. El Taxi Zone Lookup se carga como un seed de dbt.
6. dbt construye el esquema estrella Gold con `FCT_TRIPS`, `DIM_DATE` y `DIM_ZONE`.
7. Los tests de dbt validan nulabilidad, unicidad e integridad referencial.
