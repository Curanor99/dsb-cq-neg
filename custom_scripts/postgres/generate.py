import json
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]

tools_path = PROJECT_ROOT / "code" / "tools"
templates_path = PROJECT_ROOT / "query_templates_pg"
workload_path = PROJECT_ROOT / "workload"

config = json.loads((PROJECT_ROOT / "custom_scripts" / "util" / "workload_config.json").read_text())

def run(command):
    result = subprocess.run(command, cwd=tools_path, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"{command}\n{result.stdout}\n{result.stderr}")


def main():
    for template in templates_path.rglob("query*.tpl"):
        text = template.read_text(encoding="utf-8")
        if text.startswith("```sql\n") and text.rstrip().endswith("```"):
            template.write_text(text[len("```sql\n"):].rstrip()[:-3] + "\n", encoding="utf-8")

    for distribution in config["workload"]:
        command = [
            str((tools_path / "distcomp")), "-i", "tpcds.dst", "-o", "tpcds.idx",
            "-param_dist", distribution["param_dist"],
            "-param_sigma", str(distribution["param_sigma"]),
            "-param_center", str(distribution["param_center"]),
            "-rngseed", str(distribution["rngseed"]),
        ]
        run(command)
        shutil.copyfile(tools_path / "tpcds.idx", Path(f"workload/tpcds_{distribution['id']}.idx"))
        for category in sorted(templates_path.iterdir()):
            if not category.is_dir():
                continue
            for template in sorted(category.glob("query*.tpl")):
                selected = distribution["query_template_names"]
                if selected and template.name not in selected:
                    continue
                destination = Path(f"workload/{distribution['id']}/{category.name}/{template.stem}")
                destination.mkdir(parents=True, exist_ok=True)
                for i in range(distribution["instance_count"]):
                    (tools_path / f"query_{i}.sql").unlink(missing_ok=True)
                command = [
                    str(tools_path / "dsqgen"), "-output_dir", ".", "-streams", str(distribution["instance_count"]),
                    "-directory", str(templates_path / category.name), "-template", template.name,
                    "-dialect", "postgres", "-param_dist", distribution["param_dist"],
                    "-rngseed", str(distribution["rngseed"]),
                ]
                run(command)
                for i in range(distribution["instance_count"]):
                    source = tools_path / f"query_{i}.sql"
                    if not source.is_file() or source.stat().st_size == 0:
                        raise RuntimeError(f"Missing generated query: {source}")
                    shutil.move(source, destination / f"{template.stem}_{i}.sql")
                print(distribution["id"], category.name, template.name, flush=True)


if __name__ == '__main__':
    main()