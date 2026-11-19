
from pathlib import Path

from custom_scripts.duckdb.common import get_connection, DATABASE_FILE

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
DATABASE_PATH = PROJECT_ROOT / "tpcds.duckdb"


def check_table_files_exist():
    for table in tables:
        path = DATA_FOLDER / f"{table}.dat"

        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty data file: {path}")


def check_schema_empty(connection):
    table_count = connection.execute("""
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'main'
    """).fetchone()[0]

    if table_count:
        raise RuntimeError(
            "The DuckDB main schema is not empty; refusing to overwrite tables"
        )

    schema = (SCRIPTS_FOLDER / "create_tables.sql").read_text(
        encoding="utf-8"
    )
    connection.execute(schema)


def create_tables(connection):
    for table in tables:
        path = DATA_FOLDER / f"{table}.dat"

        # Escape single quotes in the file path.
        file_path = str(path).replace("'", "''")

        connection.execute(f"""
            COPY "{table}"
            FROM '{file_path}'
            (FORMAT CSV, DELIMITER '|', HEADER false)
        """)

        row_count = connection.execute(
            f'SELECT COUNT(*) FROM "{table}"'
        ).fetchone()[0]

        print(f"{table}: {row_count} rows", flush=True)

    connection.execute("ANALYZE")


def main():
    check_table_files_exist()
    DATABASE_FILE.parent.mkdir(exist_ok=True, parents=True)

    connection = get_connection(True)

    try:
        check_schema_empty(connection)
        create_tables(connection)
        print(f"\nDatabase created successfully: {DATABASE_PATH}")
    finally:
        connection.close()


if __name__ == "__main__":
    main()
