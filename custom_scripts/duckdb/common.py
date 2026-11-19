from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATABASE_FILE = PROJECT_ROOT / "tpcds.duckdb"


def ensure_duckdb_version():
    if duckdb.__version__ != "2.0.0":
        raise RuntimeError(
            f"DuckDB 2.0.0 is required, found {duckdb.__version__}"
        )


def get_connection(create_database = False):
    ensure_duckdb_version()

    if not create_database and not DATABASE_FILE.exists():
        raise FileNotFoundError(
            f"DuckDB database not found at {DATABASE_FILE}. "
            "Run scripts/py/duckdb/init_database.py first."
        )

    return duckdb.connect(str(DATABASE_FILE))