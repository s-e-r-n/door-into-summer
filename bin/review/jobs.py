import json
import subprocess
import sys

answer_seconds = 30
field_types = {"batch": int}
read_jobs: dict[str, dict | None] = {}


def answer(job_id: str) -> dict | str:
    try:
        result = subprocess.run(["higgsfield", "generate", "get", "--json", "--", job_id],
                                capture_output=True, timeout=answer_seconds)
    except OSError as error:
        return f"higgsfield did not run: {error.strerror}"
    except subprocess.TimeoutExpired:
        return f"higgsfield did not answer within {answer_seconds} s"
    if result.returncode != 0:
        return " ".join(result.stderr.decode(errors="replace").split()) or f"higgsfield exited {result.returncode}"
    try:
        job = json.loads(result.stdout)
    except ValueError:
        return "higgsfield answered no JSON"
    return job if isinstance(job, dict) else "higgsfield answered no job object"


def shown_fields(job_id: str, job: dict) -> dict:
    params = job["params"] if isinstance(job.get("params"), dict) else {}
    width, height = params.get("width"), params.get("height")
    fields = {"id": job_id, "model": job.get("display_name"), "aspect": params.get("aspect_ratio"),
              "quality": params.get("quality"), "batch": params.get("batch_size"), "resolution": params.get("resolution"),
              "size": f"{width}x{height}" if type(width) is int and type(height) is int else None,
              "mode": params.get("mode"), "prompt": params.get("prompt"), "created_at": job.get("created_at")}
    return {name: value for name, value in fields.items() if type(value) is field_types.get(name, str)}


def shown_job(job_id: str) -> dict | None:
    if job_id not in read_jobs:
        outcome = answer(job_id)
        if isinstance(outcome, str):
            print(f"job {job_id} unread: {outcome}", file=sys.stderr, flush=True)
        read_jobs[job_id] = None if isinstance(outcome, str) else shown_fields(job_id, outcome)
    return read_jobs[job_id]
