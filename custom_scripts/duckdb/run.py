import csv
import json
import random
import statistics
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from custom_scripts.duckdb.common import get_connection

WARMUP_RUNS = 2
MEASURED_RUNS = 10
RANDOM_SEED = 42

PROJECT_ROOT = Path(__file__).resolve().parents[2]
WORKLOAD_DIR = PROJECT_ROOT / "workload"
OUTPUT_DIR = PROJECT_ROOT / "results" / "duckdb"


def execute_query(connection, query, profile_path=None):
    if profile_path is None:
        connection.execute(query)
        return None

    profile_path = Path(profile_path)
    profile_path.unlink(missing_ok=True)

    escaped_path = str(profile_path).replace("'", "''")

    connection.execute(
        f"SET profiling_output = '{escaped_path}'"
    )
    connection.execute("SET enable_profiling = 'json'")

    try:
        connection.execute(query)

        if not profile_path.is_file():
            raise RuntimeError(
                f"DuckDB did not generate the profiling file: {profile_path}"
            )

        with profile_path.open("r", encoding="utf-8") as profile_file:
            plan_data = json.load(profile_file)

    finally:
        connection.execute("SET disable_profiling = true")

    execution_ms = (
        plan_data.get("latency", 0) * 1000
        if plan_data.get("latency") is not None
        else None
    )

    cpu_time_ms = (
        plan_data.get("cpu_time", 0) * 1000
        if plan_data.get("cpu_time") is not None
        else None
    )

    return {
        "planning_ms": None,
        "execution_ms": execution_ms,
        "server_total_ms": None,
        "cpu_time_ms": cpu_time_ms,
        "actual_rows": plan_data.get("rows_returned"),
        "actual_loops": None,
        "plan": plan_data,
    }


def run_benchmark(jobs, output_dir, prefix):
    Path(output_dir).mkdir(exist_ok=True, parents=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    runs_file = output_dir / f"{prefix}_runs_{timestamp}.csv"
    summary_file = output_dir / f"{prefix}_summary_{timestamp}.csv"
    plans_file = output_dir / f"{prefix}_plans_{timestamp}.jsonl"
    profile_dir = output_dir / f".{prefix}_profiles_{timestamp}"

    profile_dir.mkdir(exist_ok=True)

    random.seed(RANDOM_SEED)
    print(f"Loaded {len(jobs)} queries.")
    run_records = []
    connection = get_connection()

    try:
        print("Connection established successfully.")
        print("\nStarting warm-up executions...")

        warmup_jobs = jobs.copy()
        random.shuffle(warmup_jobs)

        for warmup_run in range(1, WARMUP_RUNS + 1):
            print(f"Warm-up {warmup_run}/{WARMUP_RUNS}")

            for job_index, job in enumerate(warmup_jobs):
                print(f"Execute query {job['query_id']} as {job_index + 1}/{len(warmup_jobs)}.")
                try:
                    execute_query(connection, job["query"])
                except Exception as error:
                    print(f"Warm-up failed: {job['query_id']}: {error}")

        print("\nStarting measured executions...")
        for measured_run in range(1, MEASURED_RUNS + 1):
            print(f"Measured run {measured_run}/{MEASURED_RUNS}")
            current_jobs = jobs.copy()
            random.shuffle(current_jobs)

            for job_index, job in enumerate(current_jobs):
                query_id = job["query_id"]
                print(f"Execute query {query_id} as {job_index + 1}/{len(current_jobs)}.")

                record = {
                    "timestamp": datetime.now().isoformat(),
                    "query_id": query_id,
                    "run": measured_run,
                }
                profile_path = (
                        profile_dir / f"profile_{measured_run}_{job_index}.json"
                )

                try:
                    measurements = execute_query(
                        connection,
                        job["query"],
                        profile_path,
                    )

                    record.update({
                        "planning_ms": measurements["planning_ms"],
                        "execution_ms": measurements["execution_ms"],
                        "server_total_ms": measurements["server_total_ms"],
                        "cpu_time_ms": measurements["cpu_time_ms"],
                        "actual_rows": measurements["actual_rows"],
                        "actual_loops": measurements["actual_loops"],
                        "error": "",
                    })
                    plan_record = {
                        "query_id": query_id,
                        "run": measured_run,
                        "plan": measurements["plan"],
                    }

                    with plans_file.open("a", encoding="utf-8") as plan_file:
                        json.dump(plan_record, plan_file)
                        plan_file.write("\n")

                except Exception as error:
                    record["error"] = str(error)
                    print(f"Query failed: {query_id}: {error}")

                finally:
                    profile_path.unlink(missing_ok=True)

                run_records.append(record)

        print("\nBenchmark execution completed.")

    finally:
        connection.close()

    columns = [
        "timestamp",
        "query_id",
        "run",
        "planning_ms",
        "execution_ms",
        "server_total_ms",
        "cpu_time_ms",
        "actual_rows",
        "actual_loops",
        "error",
    ]

    with runs_file.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=columns)
        writer.writeheader()
        writer.writerows(run_records)

    print(f"Individual measurements saved to: {runs_file}")

    grouped = defaultdict(list)

    for record in run_records:
        if record.get("error"):
            continue

        grouped[record["query_id"]].append(record)

    summary_records = []

    for query_id, records in grouped.items():
        summary = {
            "query_id": query_id,
            "successful_runs": len(records),
        }

        for metric in (
                "execution_ms",
                "cpu_time_ms",
        ):
            values = [
                record[metric]
                for record in records
                if record.get(metric) is not None
            ]

            if not values:
                continue

            summary[f"{metric}_mean"] = statistics.mean(values)
            summary[f"{metric}_median"] = statistics.median(values)
            summary[f"{metric}_stddev"] = (
                statistics.stdev(values) if len(values) >= 2 else 0
            )
            summary[f"{metric}_min"] = min(values)
            summary[f"{metric}_max"] = max(values)

        summary_records.append(summary)

    if summary_records:
        summary_columns = list(dict.fromkeys(
            key for record in summary_records for key in record
        ))

        with summary_file.open(
                "w", newline="", encoding="utf-8"
        ) as output_file:
            writer = csv.DictWriter(
                output_file,
                fieldnames=summary_columns,
            )
            writer.writeheader()
            writer.writerows(summary_records)

        print(f"Summary statistics saved to: {summary_file}")

    print(f"Execution plans saved to: {plans_file}")


def get_queries():
    queries = {}

    for query_file in sorted(WORKLOAD_DIR.rglob("*.sql")):
        query = query_file.read_text(encoding="utf-8")
        query_id = query_file.stem.replace("query", "")

        queries[query_id] = query

    return queries


def main():
    queries = get_queries()

    jobs = [
        {"query_id": query_id, "query": query}
        for query_id, query in queries.items()
    ]

    run_benchmark(jobs, OUTPUT_DIR, "duckdb")


if __name__ == "__main__":
    main()
