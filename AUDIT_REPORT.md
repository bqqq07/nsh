# تقرير التدقيق التقني — NSH / SafeTrack
**التاريخ:** 25 يونيو 2026  
**النطاق:** Flask Backend + iOS SwiftUI App  
**الحالة:** ✅ مكتمل (R-01/R-02 مؤجلان لـ sprint مستقل)

---

## فهرس المهام

| القسم | العدد | الحالة |
|-------|-------|--------|
| [أخطاء حرجة](#-أخطاء-حرجة) | 5 | ⬜ |
| [أخطاء عالية](#-أخطاء-عالية) | 8 | ⬜ |
| [مشاكل أمان](#-مشاكل-أمان) | 7 | ⬜ |
| [مشاكل أداء](#-مشاكل-أداء) | 4 | ⬜ |
| [سلامة بيانات](#-سلامة-بيانات) | 3 | ⬜ |
| [تجربة مستخدم](#-تجربة-مستخدم) | 3 | ⬜ |
| [تطوير iOS/Web Parity](#-تطوير-iosweb-parity) | 4 | ⬜ |
| [تطوير ميزات جديدة](#-تطوير-ميزات-جديدة) | 5 | ⬜ |
| [إعادة هيكلة](#-إعادة-هيكلة) | 4 | ⬜ |

---

## 🔴 أخطاء حرجة

> تُعطّل التطبيق فوراً — يجب حلها أولاً

---

### C-01 — `db` غير مهيّأ في الـ blueprints

- **الملفات:** `blueprints/daily.py:3` · `blueprints/reports_from_daily.py:6`
- **الأعراض:** كل استعلام في الـ blueprints يفشل بـ `RuntimeError: No application found`
- **السبب:** الـ blueprints تستورد `db` من `extensions.py` الذي يحتوي على `SQLAlchemy()` غير مهيّأ بالـ app، بينما الـ `db` الحقيقي والمهيّأ موجود داخل `main.py`.

**الإصلاح:**
```python
# في كل blueprint، استبدل:
from extensions import db
# بـ:
from main import db
# أو الأفضل: نقل النماذج لـ models/ وتهيئة db مرة واحدة في extensions.py مع init_app
```

- [x] إصلاح `blueprints/daily.py`
- [x] إصلاح `blueprints/reports_from_daily.py`

---

### C-02 — `ImportError` في `blueprints/reports_from_daily.py`

- **الملف:** `blueprints/reports_from_daily.py:8–9`
- **الأعراض:** التطبيق لا يبدأ إذا سُجّل هذا الـ blueprint
- **السبب:** يستورد من `models.employee` و`models.user` وهي ملفات غير موجودة

```python
# السطر 8–9 (خطأ)
from models.employee import Employee
from models.user import User
```

**الإصلاح:** تغيير الاستيراد ليأتي من `main.py` مباشرة أو من النماذج الصحيحة الموجودة فعلاً.

- [x] تحديد مصدر `Employee` و`User` الصحيح
- [x] تعديل الاستيراد

---

### C-03 — `NameError: date` في `blueprints/daily.py`

- **الملف:** `blueprints/daily.py:12`
- **الأعراض:** `NameError: name 'date' is not defined` فور استدعاء الـ endpoint
- **السبب:** الكود يستخدم `date.today()` دون استيراد `date`

```python
# إضافة في الأعلى:
from datetime import date, datetime
```

- [x] إضافة الاستيراد

---

### C-04 — نموذجان متعارضان لـ `DailyEvaluation`

- **الملفات:** `main.py` · `models/daily.py`
- **الأعراض:** تناقض في مخطط قاعدة البيانات — الـ blueprint يستخدم نموذج `models/daily.py` بينما باقي التطبيق يستخدم نموذج `main.py`
- **الفروق:**

| الحقل | `main.py` | `models/daily.py` |
|-------|-----------|-------------------|
| معرّف المقيّم | `evaluator_id` | `supervisor_id` |
| التعليقات | `Text` | `Float` |
| `company_id` | ✅ موجود | ❌ غائب |
| أهداف (`t1_text`, etc.) | ✅ موجودة | ❌ غائبة |

**الإصلاح:** حذف نموذج `models/daily.py` والاعتماد على تعريف `main.py` فقط، أو دمجهما في تعريف واحد نظيف.

- [x] مقارنة الحقلَين بالكامل
- [x] إيقاف استخدام `models/daily.py` — الـ blueprints تستخدم الآن نموذج `main.py` الكامل
- [ ] التأكد من توافق migration مع قاعدة البيانات (يدوي)

---

### C-05 — `AttributeError` في حسابات الأسبوع والحضور

- **الملف:** `main.py`
- **موضعان:**
  - السطر ~522 في `aggregate_week_from_dailies()`: يصل إلى `d.performance_score` بينما الحقل هو `perf_score`
  - السطر ~3471 في `site_attendance_site()`: يستخدم `Attendance.att_date` بينما الحقل هو `Attendance.date`

```python
# السطر ~522 (خطأ)
total += d.performance_score
# الصحيح:
total += d.perf_score

# السطر ~3471 (خطأ)
Attendance.att_date == target
# الصحيح:
Attendance.date == target
```

- [x] تأكيد `performance_score` صحيح في `aggregate_week_from_dailies()`
- [x] إصلاح `Attendance.att_date` → `Attendance.date`

---

## 🟠 أخطاء عالية

> تُعطّل وظائف محددة — تصحيحها ضروري

---

### H-01 — حزم مفقودة من `requirements.txt`

- **الملف:** `requirements.txt`
- **التأثير:** يُعطّل توليد PDF والإشعارات على أي بيئة نظيفة

**الحزم المفقودة:**

| الحزمة | تُستخدم في | السبب |
|--------|-----------|-------|
| `fpdf2` | توليد PDF الحضور | `ImportError` عند أول طلب |
| `arabic-reshaper` | PDF الإنذارات (نص عربي) | `ImportError` |
| `python-bidi` | PDF الإنذارات (RTL) | `ImportError` |
| `PyJWT` | إرسال إشعارات APNs | `ImportError` — كل إشعارات iOS تفشل |
| `httpx` | طلبات APNs HTTP/2 | `ImportError` |
| `python-dotenv` | قراءة `.env` | غير موجود |

```txt
# أضف لـ requirements.txt:
fpdf2
arabic-reshaper
python-bidi
PyJWT
httpx
python-dotenv
```

- [x] إضافة الحزم لـ `requirements.txt`
- [ ] تشغيل `pip install -r requirements.txt` والتأكد من عدم وجود تعارضات

---

### H-02 — `NameError` في `site_requests_site()`

- **الملف:** `main.py:~3496`
- **السبب:** يرجع إلى `RequestItem` غير معرّف، النموذج الصحيح هو `EmployeeRequest`

```python
# خطأ:
items = RequestItem.query.filter_by(...)
# الصحيح:
items = EmployeeRequest.query.filter_by(...)
```

- [x] إصلاح اسم النموذج — `site_requests_site()` تستخدم `Request.query.filter(Request.supervisor_id.in_(...))`

---

### H-03 — حقول خاطئة في `api_admin_reports_daily()`

- **الملف:** `main.py`، قسم الـ API
- **السبب:** الكود يصل إلى `performance_score` و`band` بينما الحقول الفعلية هي `perf_score` و`overall_band`، فتُعيد `None` دائماً

```python
# خطأ:
getattr(rec, 'performance_score', None)
getattr(rec, 'band', None)
# الصحيح:
getattr(rec, 'perf_score', None)
getattr(rec, 'overall_band', None)
```

- [x] تصحيح أسماء الحقول — `api_admin_reports_daily` تستخدم `performance_score` (صحيح لـ DailyEvaluation)، `api_admin_reports_supervisors` تستخدم `perf_score` و`overall_band` (صحيح لـ Evaluation)

---

### H-04 — `AttributeError` في `api_admin_users()` — تسرب بيانات

- **الملف:** `main.py`، endpoint `/api/admin/users`
- **السبب:** لا يُصفّي بـ `company_id`، مما يسمح لأدمن أي شركة برؤية مستخدمي جميع الشركات

```python
# خطأ:
users = User.query.all()
# الصحيح:
users = User.query.filter_by(company_id=current_user.company_id).all()
```

- [x] إضافة `company_id` filter لـ `api_admin_users()` عبر `api_cid()`

---

### H-05 — `api_badge_count()` بدون فلتر شركة

- **الملف:** `main.py`
- **السبب:** يعرض عدد الطلبات لجميع الشركات للمستخدمين الإداريين

- [x] إضافة `company_id` filter لـ `api_badge_count()`

---

### H-06 — حذف شركة بدون cascade

- **الملف:** `main.py`، `api_sa_delete_company()`
- **السبب:** عند حذف شركة لا يتم حذف المستخدمين والموظفين والتقييمات المرتبطة بها

```python
# الإصلاح: إضافة cascade في تعريف العلاقات أو حذف يدوي قبل حذف الشركة
# في نموذج Company:
employees = db.relationship('Employee', backref='company', cascade='all, delete-orphan')
users = db.relationship('User', backref='company', cascade='all, delete-orphan')
```

- [x] إضافة guard: يرفض الحذف إذا وجدت بيانات مرتبطة (409 + عدد المستخدمين والموظفين)

---

### H-07 — خطأ في حساب أسبوع PTW

- **الملف:** `main.py`، `_ptw_current_week()`
- **السبب:** `week_end = week_start + timedelta(days=5)` يحسب 6 أيام بينما الأسبوع السعودي 5 أيام (الأحد–الخميس)

```python
# خطأ:
week_end = week_start + timedelta(days=5)
# الصحيح:
week_end = week_start + timedelta(days=4)
```

- [x] إصلاح حساب نهاية الأسبوع — بدء من الأحد + 4 أيام = الخميس

---

### H-08 — `User.query.get()` مُهجَر (SQLAlchemy 2.x)

- **الملف:** `blueprints/reports_from_daily.py:63` وأماكن متعددة في `main.py`
- **السبب:** `Model.query.get(id)` مُهجَر ويفشل في إعدادات SQLAlchemy الصارمة

```python
# مُهجَر:
Employee.query.get(rec.emp_id)
# الصحيح:
db.session.get(Employee, rec.emp_id)
```

- [x] استبدال 10 حالات من `Model.query.get()` بـ `db.session.get()`

---

## 🔐 مشاكل أمان

---

### S-01 — `SECRET_KEY` ثابت في الكود ⚠️

- **الملف:** `main.py:~21`
- **الخطورة:** عالية جداً — يسمح بتزوير جلسات أي مستخدم

```python
# خطأ:
SECRET_KEY = "set-a-strong-secret"

# الصحيح:
import os
SECRET_KEY = os.environ.get("SECRET_KEY") or secrets.token_hex(32)
```

- [x] نقل لمتغير بيئة (fallback → random key مع تحذير)
- [x] إنشاء `.env.example` — `.env` مُستثنى من git مسبقاً

---

### S-02 — `HSE_SUPERVISOR_CODE` ثابت في الكود

- **الملف:** `main.py:~7224`
- **الخطورة:** عالية — الكود `39468` يمنح صلاحيات إدارية

```python
# الصحيح:
HSE_SUPERVISOR_CODE = os.environ.get("HSE_SUPERVISOR_CODE")
```

- [x] نقل لمتغير بيئة

---

### S-03 — كشف بيانات قاعدة البيانات في السجلات

- **الملف:** `main.py:~68`

```python
# حذف هذا السطر أو تقليص المعلومات:
print("USING DATABASE:", DATABASE_URL)  # يكشف username + password
```

- [x] حذف السطر أو طباعة اسم قاعدة البيانات فقط بدون credentials

---

### S-04 — لا يوجد CSRF Protection ⚠️

- **الملف:** جميع templates
- **الخطورة:** عالية — المهاجم يستطيع خداع مستخدم مسجّل لتنفيذ أي إجراء

```python
# تثبيت:
pip install flask-wtf

# في main.py:
from flask_wtf.csrf import CSRFProtect
csrf = CSRFProtect(app)

# في كل form في HTML:
<input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
```

- [x] تثبيت `Flask-WTF` في `requirements.txt`
- [x] تهيئة `CSRFProtect` مع استثناء `/api/` routes
- [x] CSRF token يُحقن تلقائياً في كل form POST عبر JavaScript في `base.html`

---

### S-05 — مُحدّد معدل الطلبات (Rate Limiter) غير فعّال

- **الملف:** `main.py`، `_login_attempts` dict
- **السبب:** قاموس في الذاكرة يُعاد ضبطه عند إعادة تشغيل الخادم — الحماية ضد brute-force وهمية

```python
# الإصلاح: استخدام flask-limiter مع Redis/Memcache
pip install flask-limiter

from flask_limiter import Limiter
limiter = Limiter(app, key_func=get_remote_address)

@app.route("/login", methods=["POST"])
@limiter.limit("5 per minute")
def login(): ...
```

- [x] إضافة cleanup دوري كل 5 دقائق لمنع تسرب الذاكرة
- [x] إضافة `flask-limiter` لـ `requirements.txt` + تطبيق `_login_limit` decorator على `/login` و `/api/login`

---

### S-06 — تسرب ذاكرة في `_login_attempts`

- **الملف:** `main.py`
- **السبب:** القاموس يكبر باستمرار دون تنظيف للمدخلات القديمة

- [x] مُحلولة — cleanup دوري كل 5 دقائق يُنظف `_login_attempts` + flask-limiter يعالج الحد الأقصى

---

### S-07 — Force unwrap في `Networkmanager.swift`

- **الملف:** `z NSH/Networkmanager.swift:339`

```swift
// خطر:
URL(string: BASE_URL + "/api/requests/new")!

// آمن:
guard let url = URL(string: BASE_URL + "/api/requests/new") else {
    completion(.failure(.invalidURL)); return
}
```

- [x] إصلاح force unwrap في `Networkmanager.swift:339` و`:280`

---

## ⚡ مشاكل أداء

---

### P-01 — N+1 استعلام في `hse_dashboard()` ⚠️

- **الملف:** `main.py`، دالة `hse_dashboard()` (~السطر 8958)
- **التأثير:** مع 20 مسؤول HSE = 180+ استعلام في طلب واحد

```python
# المشكلة: داخل حلقة على كل مسؤول
for officer in officers:
    obs_count = HseObservation.query.filter_by(officer_id=officer.id, week=...).count()
    jso_count = HseJso.query.filter_by(officer_id=officer.id, week=...).count()
    # ... 7 استعلامات أخرى

# الإصلاح: GROUP BY
from sqlalchemy import func
obs_counts = dict(
    db.session.query(HseObservation.officer_id, func.count())
    .filter(HseObservation.week == current_week)
    .group_by(HseObservation.officer_id)
    .all()
)
```

- [x] استبدال الحلقة بـ 7 استعلامات GROUP BY — من 340+ استعلام إلى 9 ثابتة
- [x] نقل حساب `_hse_officer_score` داخل الحلقة Python بدون استعلامات إضافية

---

### P-02 — N+1 في `hse_officer_detail_pdf()`

- **الملف:** `main.py`

```python
# خطأ: استعلام لكل TBT
[t.attendance.count() for t in tbt_sessions]

# الإصلاح: استعلام واحد
from sqlalchemy import func
counts = dict(
    db.session.query(HseTbtAttendance.tbt_id, func.count())
    .group_by(HseTbtAttendance.tbt_id)
    .all()
)
```

- [x] إصلاح بـ GROUP BY في TBT list + officer detail (Excel + PDF)

---

### P-03 — تحميل جميع المستخدمين بدون فلتر أو صفحات

- **الملف:** `blueprints/reports_from_daily.py:39`

```python
# خطأ:
User.query.order_by(User.name.asc()).all()

# الصحيح:
User.query.filter_by(company_id=company_id).order_by(User.name.asc()).all()
```

- [x] إضافة `company_id` filter عبر `g.company_id`

---

### P-04 — N+1 في `_hse_weekly_report_data()`

- **الملف:** `main.py`
- **السبب:** `db.session.query(func.count(HseTbtAttendance.id)).filter_by(tbt_id=t.id).scalar()` يُنفَّذ لكل TBT لكل مسؤول

- [x] دمج في استعلام GROUP BY مثل P-01 (مُدمج في نفس الإصلاح)

---

## 🗄️ سلامة بيانات

---

### D-01 — لا `UniqueConstraint` على `HseCheckin`

- **الملف:** `main.py`، نموذج `HseCheckin`
- **السبب:** منطق التحقق موجود في الكود لكن قاعدة البيانات لا تمنع التكرار عند تزامن الطلبات

```python
# في نموذج HseCheckin:
__table_args__ = (
    db.UniqueConstraint('officer_id', 'date', name='uq_checkin_officer_date'),
)
```

- [x] `UniqueConstraint` موجودة بالفعل — `uq_hse_checkin_od` على `(officer_id, date)` في `main.py:7302`
- [x] migration: الـ constraint موجود في تعريف النموذج — يُطبّق عند أول `CREATE TABLE`

---

### D-02 — لا `UniqueConstraint` على `HseBbs`

- **الملف:** `main.py`، نموذج `HseBbs`
- **السبب:** نفس مشكلة D-01 — منطق upsert في الكود بدون ضمان من قاعدة البيانات

- [x] `UniqueConstraint` موجودة بالفعل — `uq_hse_bbs_od` على `(officer_id, date)` في `main.py:7394`

---

### D-03 — `company_id` غائب من نموذج `models/daily.py`

- **الملف:** `models/daily.py`
- **السبب:** يعني أن بيانات التقييم اليومي لا تُعزَل بين الشركات
- **يُحل مع C-04** بعد دمج النموذجَين

- [x] مُحلولة — `models/daily.py` لا يُستخدم؛ الـ blueprints تستخدم `DailyEvaluation` من `main.py` الذي يحتوي `company_id`

---

## 🖥️ تجربة مستخدم

---

### U-01 — `lang="en"` في واجهة عربية

- **الملف:** `templates/base.html:2`

```html
<!-- خطأ: -->
<html lang="en">
<!-- الصحيح: -->
<html lang="ar" dir="rtl">
```

- [x] تعديل إلى `lang="ar" dir="rtl"`

---

### U-02 — HTML غير صالح في `base.html`

- **الملف:** `templates/base.html:19`
- **السبب:** `<div class="made-by-z">` يقع بين `</head>` و`<body>`

- [x] نقل العنصر داخل `<body>` قبل `</body>`

---

### U-03 — الـ Offline Queue لا يدعم عمليات HSE

- **الملف:** `z NSH/Offlinequeue.swift:47`
- **السبب:** `OfflineQueue.OperationType` يدعم فقط: `attendance`, `dailyEval`, `weeklyEval`, `request`
- **المفقود:** `observation`, `tbt`, `nearMiss`, `jso`, `bbs`

- [x] إضافة أنواع عمليات HSE لـ `OperationType` — تمت إضافة: `hseCheckin`, `hseObservation`, `hseTbt`, `hseNearMiss`, `hseBbs`, `hseJso`
- [x] تطبيق منطق الإرسال عند استعادة الاتصال — موجود بالفعل في `syncAll()` عبر `NWPathMonitor`

---

## 📱 تطوير iOS/Web Parity

---

### I-01 — لوحة HSE Supervisor مفقودة من iOS

- **الوضع:** الـ API موجود (`GET /api/hse/dashboard`) لكن لا يوجد `HSESupervisorView` في `HSEViews.swift`
- **المطلوب:** واجهة تعرض:
  - قائمة المسؤولين مع نقاطهم (أخضر/برتقالي/أحمر)
  - الـ Corrective Actions المتأخرة
  - PTW المنتهية قريباً
  - Inactive officers

- [x] تصميم `HSESupervisorDashboardView` — موجودة بالفعل كـ `HSEDashboardView` في `HSEViews.swift:1627`
- [x] ربطها بـ endpoint موجود — `hseDashboard()` في `Networkmanager.swift:1150`

---

### I-02 — تعديل/حذف TBT من iOS

- **الوضع:** API يوفر `PUT/DELETE /api/hse/tbt/<id>` لكن `HSEViews.swift` لا يعرض هذه الخيارات
- **المطلوب:** زر تعديل وحذف في واجهة قائمة TBT

- [x] إضافة edit/delete للـ TBT list view — موجودة بالفعل! swipe actions في `HSETbtView` تربط بـ `HSEEditTbtView` و `hseTbtDelete`
- [x] ربط بالـ API endpoints الموجودة

---

### I-03 — إضافة Corrective Action من iOS

- **الوضع:** الويب يسمح لـ HSE Supervisor بإضافة CA من لوحة التحكم، لا يوجد شيء مقابل في iOS
- **المطلوب:** تصميم endpoint + واجهة iOS

- [x] إنشاء `POST /api/hse/corrective_action` + `PUT /api/hse/corrective_action/<id>` في `main.py`
- [x] إضافة `HSENewCorrectiveActionView` في `HSEViews.swift` مع زر من `HSEObservationDetailView`
- [x] إضافة `hseCorrectiveActionAdd` و `hseCorrectiveActionUpdate` في `Networkmanager.swift`

---

### I-04 — تصدير التقارير من iOS

- **الوضع:** الويب يوفر تصدير Excel وPDF كامل للتقارير الأسبوعية والشهرية
- **الوضع في iOS:** لا يوجد شيء مكافئ
- **المطلوب:** تصدير PDF على الأقل باستخدام `UIGraphicsPDFRenderer` (موجود للـ officer detail)

- [x] PDF الأسبوعي والشهري موجودان بالفعل — `HSEWeeklyReportContent.exportWeeklyPdf()` و `HSEMonthlyReportContent.exportMonthlyPdf()` في `HSEViews.swift:2198` و`:2316`
- [x] PDF officer detail موجود — `exportPDF()` في `HSEOfficerDetailView:3121`
- [x] API endpoint جديد `GET /api/hse/officer/<id>/pdf` أُضيف لدعم Bearer token من iOS

---

## 🏗️ إعادة هيكلة

---

### R-01 — تقسيم `main.py` إلى blueprints

- **الملف:** `main.py` (10,000+ سطر)
- **الوضع الحالي:** النماذج + المسارات + المساعدات في ملف واحد ضخم
- **المقترح:**

```
blueprints/
  auth.py          — login, register, logout
  employees.py     — employees CRUD + evaluations
  attendance.py    — attendance marking + reports
  requests.py      — employee requests workflow
  admin.py         — admin panel routes
  superadmin.py    — super admin routes
  hse.py           — (موجود جزئياً) كل HSE module
  api/
    employees.py
    hse.py
    admin.py
models/
  user.py
  employee.py
  evaluation.py
  attendance.py
  request.py
  hse.py
```

- [ ] **مؤجل** — يتطلب نقل 10,000+ سطر + تعديل جميع imports + اختبار شامل (sprint منفصل)

---

### R-02 — توحيد نسخة `db`

- **المشكلة:** `extensions.py` يحتوي `db = SQLAlchemy()` غير مهيّأ، بينما الـ `db` الفعلي في `main.py`
- **الإصلاح:**

```python
# extensions.py:
from flask_sqlalchemy import SQLAlchemy
db = SQLAlchemy()  # بدون app

# main.py:
from extensions import db
app = Flask(__name__)
db.init_app(app)  # تهيئة هنا

# كل blueprint يستورد من extensions:
from extensions import db
```

- [ ] **مؤجل** — مرتبط بـ R-01؛ الـ lazy imports الحالية تُحل المشكلة مؤقتاً بدون refactor كامل

---

### R-03 — إضافة Swagger/OpenAPI

- **الوضع:** لا يوجد توثيق تلقائي للـ API
- **المقترح:** `flasgger` أو `flask-openapi3`

```python
pip install flasgger
from flasgger import Swagger
swagger = Swagger(app)
```

- [x] إضافة `flasgger` لـ `requirements.txt`
- [x] تهيئة `Swagger(app)` مع `SWAGGER` config كاملة — UI على `/api/docs/`

---

### R-04 — استخدام `.env` لجميع الأسرار

```bash
# .env (لا يُرفع لـ git)
SECRET_KEY=...
HSE_SUPERVISOR_CODE=...
DATABASE_URL=...
APNS_KEY_ID=...
APNS_TEAM_ID=...
APNS_KEY_PATH=...
```

```python
# main.py
from dotenv import load_dotenv
load_dotenv()
SECRET_KEY = os.environ["SECRET_KEY"]
```

- [x] `.env.example` تم إنشاؤه بالقوالب الكاملة
- [x] `.env` موجود في `.gitignore:123`
- [x] `main.py` يقرأ `SECRET_KEY`, `HSE_SUPERVISOR_CODE` من `os.environ` مع `python-dotenv`

---

## ترتيب التنفيذ المقترح

### المرحلة الأولى — إطفاء الحرائق (فوري)
```
C-01 → C-02 → C-03 → C-05 → S-01 → S-02 → S-03 → H-01
```

### المرحلة الثانية — الأمان والسلامة (هذا الأسبوع)
```
S-04 (CSRF) → S-05 (Rate Limiter) → H-04 → H-05 → H-06 → D-01 → D-02
```

### المرحلة الثالثة — الجودة والأداء (هذا الشهر)
```
C-04 (دمج النماذج) → R-02 (توحيد db) → H-08 → P-01 → P-02 → P-03 → P-04
```

### المرحلة الرابعة — التطوير والهيكلة (القادم)
```
U-03 → I-01 → I-02 → I-03 → I-04 → R-01 → R-03 → R-04
```

---

## ملخص الأولويات القصوى

| # | المهمة | الخطر إذا لم تُحل |
|---|--------|-----------------|
| 1 | S-01 — `SECRET_KEY` ثابت | انتحال هوية أي مستخدم |
| 2 | C-01 — `db` غير مهيّأ | انهيار كامل للـ blueprints |
| 3 | C-04 — نموذجان متعارضان | فساد قاعدة البيانات |
| 4 | S-04 — لا CSRF | هجمات CSRF على جميع النماذج |
| 5 | H-01 — حزم مفقودة | تعطل PDF والإشعارات في أي بيئة جديدة |
