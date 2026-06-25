# blueprints/reports_from_daily.py
from flask import Blueprint, request, render_template
from datetime import date, timedelta
from sqlalchemy import func, and_

reports_daily_bp = Blueprint('reports_daily', __name__, url_prefix='/admin/reports-daily')


def parse_d(s):
    return date.fromisoformat(s) if s else None


def week_bounds(ws, we):
    if ws and we:
        return ws, we
    today = date.today()
    sunday = today - timedelta(days=(today.weekday() + 1) % 7)
    return sunday, sunday + timedelta(days=4)


def band_from_total(total):
    if total is None:
        return '—'
    t = float(total)
    return 'A' if t >= 90 else 'B' if t >= 80 else 'C' if t >= 70 else 'D' if t >= 60 else 'E'


@reports_daily_bp.get('/all')
def reports_all():
    from flask import g
    from main import db, DailyEvaluation, Employee, User

    ws = parse_d(request.args.get('week_start'))
    we = parse_d(request.args.get('week_end'))
    ws, we = week_bounds(ws, we)
    q = (request.args.get('q') or '').strip()

    company_id = getattr(g, 'company_id', None)
    sup_q = User.query.order_by(User.name.asc())
    if company_id:
        sup_q = sup_q.filter_by(company_id=company_id)
    sup_suggestions = [(str(u.id), u.name) for u in sup_q.all()]

    focus_sup = None
    if q:
        focus_sup = User.query.filter((User.id == q) | (User.name == q)).first()

    base = db.session.query(
        DailyEvaluation.employee_id.label('emp_id'),
        func.avg(DailyEvaluation.targets_score).label('targets_avg'),
        func.avg(DailyEvaluation.performance_score).label('perf_avg'),
        func.avg(DailyEvaluation.total_score).label('total_avg'),
        func.count(DailyEvaluation.id).label('days_count'),
        func.max(DailyEvaluation.evaluator_id).label('sup_id'),
    ).filter(and_(DailyEvaluation.eval_date >= ws, DailyEvaluation.eval_date <= we))

    if focus_sup:
        base = base.filter(DailyEvaluation.evaluator_id == focus_sup.id)

    agg = base.group_by(DailyEvaluation.employee_id).all()

    rows = []
    for rec in agg:
        emp = db.session.get(Employee, rec.emp_id)
        sup = db.session.get(User, rec.sup_id) if rec.sup_id else None
        ev_like = type('X', (), {})()
        ev_like.targets_score     = round(rec.targets_avg or 0, 2)
        ev_like.perf_score        = round(rec.perf_avg or 0, 2)
        ev_like.total_score       = round(rec.total_avg or 0, 2)
        ev_like.overall_band      = band_from_total(ev_like.total_score)
        rows.append((ev_like, emp, sup))

    missing_emps, done_emp_count, total_emp, sup_cov_pct = [], None, None, None
    if focus_sup:
        sup_emps = Employee.query.filter_by(supervisor_id=focus_sup.id).all()
        total_emp = len(sup_emps)
        evaluated_ids = {
            r[0] for r in db.session.query(DailyEvaluation.employee_id)
                  .filter(and_(DailyEvaluation.eval_date >= ws,
                               DailyEvaluation.eval_date <= we,
                               DailyEvaluation.evaluator_id == focus_sup.id)).distinct().all()
        }
        missing_emps = [e for e in sup_emps if e.id not in evaluated_ids]
        done_emp_count = total_emp - len(missing_emps)
        sup_cov_pct = (done_emp_count / total_emp * 100.0) if total_emp else None

    return render_template(
        'admin/reports_all.html',
        ws=ws, we=we, q=q,
        sup_suggestions=sup_suggestions,
        focus_sup=focus_sup,
        sup_cov_pct=sup_cov_pct,
        done_emp_count=done_emp_count,
        total_emp=total_emp,
        missing_emps=missing_emps,
        rows=rows,
    )
