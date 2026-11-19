from pathlib import Path

from psycopg2 import sql

from custom_scripts.postgres.common import get_connection

tables = [
    "call_center", "catalog_page", "catalog_returns", "catalog_sales",
    "customer", "customer_address", "customer_demographics", "date_dim",
    "household_demographics", "income_band", "inventory", "item", "promotion",
    "reason", "ship_mode", "store", "store_returns", "store_sales", "time_dim",
    "warehouse", "web_page", "web_returns", "web_sales", "web_site",
]

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_FOLDER = PROJECT_ROOT / "scripts"
DATA_FOLDER = PROJECT_ROOT / "data"


def check_table_files_exist():
    for table in tables:
        path = Path(f"data/{table}.dat")
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty data file: {path}")


def check_schema_empty(connection):
    with connection.cursor() as cursor:
        cursor.execute("SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public'")
        if cursor.fetchone()[0]:
            raise RuntimeError("The public schema is not empty; refusing to overwrite tables")
        cursor.execute((SCRIPTS_FOLDER / "create_tables.sql").read_text(encoding="utf-8"))
    connection.commit()


def create_tables(connection):
    for table in tables:
        with connection.cursor() as cursor, (DATA_FOLDER / f"{table}.dat").open("rb") as source:
            cursor.copy_expert(
                sql.SQL("COPY {} FROM STDIN WITH (FORMAT CSV, DELIMITER '|')").format(
                    sql.Identifier(table)
                ), source
            )
            print(f"{table}: {cursor.rowcount} rows", flush=True)
        connection.commit()
    with connection.cursor() as cursor:
        cursor.execute("ANALYZE")
    connection.commit()


def main():
    check_table_files_exist()

    connection = get_connection()
    check_schema_empty(connection)

    create_tables(connection)


if __name__ == '__main__':
    main()