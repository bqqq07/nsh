# blueprints/daily.py
from flask import Blueprint, render_template, request, jsonify
from datetime import date

daily_bp = Blueprint("daily", __name__, url_prefix="/admin/daily")


@daily_bp.get("/new")
def daily_form():
    return render_template("daily_eval_form.html", emps=[], sups=[], today=date.today())


@daily_bp.get("/")
def daily_list():
    from main import db, DailyEvaluation
    rows = DailyEvaluation.query.order_by(DailyEvaluation.eval_date.desc()).all()
    return render_template("daily_list.html", rows=rows)


@daily_bp.post("/api/upsert")
def daily_upsert():
    from main import db, DailyEvaluation
    data = request.get_json(silent=True) or request.form
    emp_id = int(data["employee_id"])
    d = data["eval_date"]

    row = DailyEvaluation.query.filter_by(employee_id=emp_id, eval_date=d).one_or_none()
    if not row:
        row = DailyEvaluation(employee_id=emp_id, eval_date=d)

    row.evaluator_id      = data.get("supervisor_id")
    row.targets_score     = float(data.get("targets_score") or 0)
    row.performance_score = float(data.get("perf_score") or 0)
    row.total_score       = row.targets_score + row.performance_score
    row.overall_band      = data.get("overall_band") or "—"

    db.session.add(row)
    db.session.commit()
    return jsonify({"status": "ok", "id": row.id})
