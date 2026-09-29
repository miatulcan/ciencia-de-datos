import argparse
import os
import sys
from pathlib import Path

import requests
import snowflake.connector


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"

DATA_DIR = Path("/data")


def required_months():
    months = []

    for month in range(1, 13):
        months.append((2025, month))

    for month in range(1, 9):
        months.append((2026, month))

    return months


def filename(year, month):
    return f"yellow_tripdata_{year}-{month:02d}.parquet"


def url_for(year, month):
    return f"{BASE_URL}/{filename(year, month)}"


def check_available(year, month):
    url = url_for(year, month)

    try:
        response = requests.head(
            url,
            allow_redirects=True,
            timeout=30,
        )

        return response.status_code == 200

    except requests.RequestException:
        return False


def show_manifest():
    print("\nNYC Yellow Taxi - required files\n")

    available = 0

    for year, month in required_months():
        exists = check_available(year, month)

        status = "AVAILABLE" if exists else "NOT AVAILABLE"

        if exists:
            available += 1

        print(f"{year}-{month:02d}  {status}")

    print(f"\nAvailable: {available}/20")


def download(year, month):
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    name = filename(year, month)
    destination = DATA_DIR / name

    if destination.exists():
        print(f"[SKIP DOWNLOAD] {name} already exists")
        return destination

    url = url_for(year, month)

    print(f"[DOWNLOAD] {url}")

    with requests.get(url, stream=True, timeout=120) as response:
        if response.status_code == 404:
            print(f"[NOT AVAILABLE] {year}-{month:02d}")
            return None

        response.raise_for_status()

        with open(destination, "wb") as file:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file.write(chunk)

    print(f"[DOWNLOADED] {destination}")

    return destination


def snowflake_connection():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema="BRONZE",
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        private_key_file_pwd=os.environ[
            "DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"
        ],
    )


def already_loaded(cursor, name):
    cursor.execute(
        """
        SELECT COUNT(*)
        FROM NYC_TAXI.BRONZE.YELLOW_TAXI_TRIPS_RAW
        WHERE SOURCE_FILE = %s
        """,
        (name,),
    )

    return cursor.fetchone()[0] > 0


def load_to_snowflake(path, year, month):
    name = path.name

    connection = snowflake_connection()
    cursor = connection.cursor()

    try:
        if already_loaded(cursor, name):
            print(f"[SKIP LOAD] {name} already loaded")
            return

        print(f"[UPLOAD] {name}")

        cursor.execute(
            f"""
            PUT 'file://{path.as_posix()}'
            @NYC_TAXI.BRONZE.YELLOW_TAXI_STAGE
            AUTO_COMPRESS = FALSE
            OVERWRITE = TRUE
            """
        )

        print(f"[COPY] {name}")

        cursor.execute(
            f"""
            COPY INTO NYC_TAXI.BRONZE.YELLOW_TAXI_TRIPS_RAW
                (
                    RAW_RECORD,
                    SOURCE_FILE,
                    SOURCE_YEAR,
                    SOURCE_MONTH,
                    INGESTED_AT
                )
            FROM (
                SELECT
                    $1,
                    '{name}',
                    {year},
                    {month},
                    CURRENT_TIMESTAMP()
                FROM
                    @NYC_TAXI.BRONZE.YELLOW_TAXI_STAGE/{name}
                    (FILE_FORMAT => NYC_TAXI.BRONZE.PARQUET_FORMAT)
            )
            """
        )

        connection.commit()

        cursor.execute(
            """
            SELECT COUNT(*)
            FROM NYC_TAXI.BRONZE.YELLOW_TAXI_TRIPS_RAW
            WHERE SOURCE_FILE = %s
            """,
            (name,),
        )

        rows = cursor.fetchone()[0]

        print(f"[LOADED] {name}: {rows:,} rows")

    finally:
        cursor.close()
        connection.close()


def ingest_month(year, month):
    if not check_available(year, month):
        print(f"[NOT AVAILABLE] {year}-{month:02d}")
        return

    path = download(year, month)

    if path is None:
        return

    load_to_snowflake(path, year, month)


def ingest_all():
    for year, month in required_months():
        print("\n" + "=" * 60)
        print(f"Processing {year}-{month:02d}")
        print("=" * 60)

        try:
            ingest_month(year, month)

        except Exception as error:
            print(f"[ERROR] {year}-{month:02d}: {error}")


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--check",
        action="store_true",
        help="Check availability of required files",
    )

    parser.add_argument(
        "--year",
        type=int,
    )

    parser.add_argument(
        "--month",
        type=int,
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Ingest all required months",
    )

    args = parser.parse_args()

    if args.check:
        show_manifest()
        return

    if args.all:
        ingest_all()
        return

    if args.year and args.month:
        ingest_month(args.year, args.month)
        return

    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()