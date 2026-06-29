import Foundation
import SwiftUI
import UserNotifications
import Combine

// ═══════════════════════════════════════════════════
//  رابط السيرفر
// ═══════════════════════════════════════════════════
let BASE_URL = "https://nsh.z-app.biz"

// ═══════════════════════════════════════════════════
//  MARK: - Models
// ═══════════════════════════════════════════════════

struct AppUser: Codable {
    let id:           Int
    let name:         String
    let code:         String
    let role:         String
    let hse_access:   Bool?
    let company_id:   Int?
    let company_name: String?
}

struct LoginResponse: Codable {
    let token: String
    let user: AppUser
}

struct Employee: Codable, Identifiable, Hashable {
    let id:          Int
    let name:        String
    let emp_number:  String
    let department:  String?
    let site:        String?
    let status:      String?   // active | resigned | unassigned
    let resigned_at: String?
}

struct SupervisorEmployees: Codable {
    let active:   [Employee]
    let resigned: [Employee]
}

struct UnassignedEmployee: Codable, Identifiable {
    let id:         Int
    let name:       String
    let emp_number: String
    let department: String
    let site:       String
}

struct RequestItem: Codable, Identifiable {
    let id: Int
    let type: String
    let status: String
    let start_date: String?
    let end_date: String?
    let reason: String?
    let created_at: String?
    let admin_comment: String?
    let employee: EmployeeRef?
    let supervisor: SupervisorRef?
    let has_attachment: Bool?
    let official_reason: String?
    // نموذج الإجازة
    let has_leave_form: Bool?
    let leave_signed: Bool?
    let leave_pdf_url: String?
    // استئذان
    let permission_signed: Bool?
    // إنذار
    let warning_signed: Bool?
    let warning_pdf_url: String?

    var statusColor: String {
        switch status {
        case "approved": return "green"
        case "rejected": return "red"
        default:         return "orange"
        }
    }
    var statusArabic: String {
        switch status {
        case "approved": return "تمت الموافقة"
        case "rejected": return "مرفوض"
        default:         return "قيد المراجعة"
        }
    }
    var typeArabic: String {
        switch type {
        case "leave":      return "إجازة"
        case "sick":       return "سكليف"
        case "secondment": return "إعارة"
        case "permission": return "استئذان"
        case "warning":    return "إنذار"
        case "late":       return "تأخر"
        default:           return type
        }
    }
}

struct EmployeeRef: Codable {
    let id: Int?
    let name: String?
    let emp_number: String?
    let department: String?
}

struct SupervisorRef: Codable {
    let id: Int?
    let name: String?
}

struct HRTask: Codable, Identifiable {
    let id: Int
    let type: String
    let status: String
    let created_at: String?
    let applied_at: String?
    let employee: EmployeeRef?
    let request: RequestRef?
    let warning_pdf_url:        String?
    let official_reason:        String?
    let supervisor_description: String?
    let reason_set:             Bool?

    var statusArabic: String { status == "applied" ? "تم التنفيذ" : "قيد الانتظار" }
    var typeArabic: String {
        switch type {
        case "leave":      return "إجازة"
        case "secondment": return "إعارة"
        case "permission": return "استئذان"
        case "warning":    return "إنذار"
        case "late":       return "تأخر"
        default:           return type
        }
    }
}

struct RequestRef: Codable {
    let id: Int?
    let start_date: String?
    let end_date: String?
    let reason: String?
}

struct KPIData: Codable {
    let total_employees:  Int
    let evals_this_week:  Int
    let evals_last_week:  Int
    let pending_requests: Int
    let hr_pending_tasks: Int
    let emp_coverage:     Double
    let att_rate:         Double
    let leave_rate:       Double
    let present_count:    Int
    let leave_count:      Int
    let week_start:       String
    let week_end:         String
}

struct EvalReport: Codable, Identifiable {
    let id: Int
    let emp_id: Int
    let emp_name: String
    let emp_number: String
    let department: String?
    let targets: Double?
    let perf: Double?
    let total: Double?
    let band: String?
    let week_start: String?
    let week_end: String?
    let eval_date: String?

    enum CodingKeys: String, CodingKey {
        case id = "eval_id"
        case emp_id, emp_name, emp_number, department
        case targets, perf, total, band
        case week_start, week_end, eval_date
    }

    var bandColor: Color {
        switch band {
        case "Excellent": return .green
        case "Good":      return .blue
        case "Average":   return .orange
        default:          return .red
        }
    }
}

struct EmployeeSummary: Codable {
    let total_days:    Int
    let present:       Int
    let absent:        Int
    let avg_score_8w:  Double?
    let eval_count_8w: Int
}

struct UserItem: Codable, Identifiable {
    let id:        Int
    let name:      String
    let code:      String
    let role:      String
    let is_active: Bool
    let is_hidden: Bool?
}

struct AttendanceRow: Identifiable {
    let id = UUID()
    var empId: Int
    var empNumber: String
    var name: String
    var department: String?
    var site: String?
    var status: String?
    var remarks: String
}

// ═══════════════════════════════════════════════════
//  MARK: - Session Manager
// ═══════════════════════════════════════════════════
class SessionManager: ObservableObject {

    static let shared = SessionManager()

    @Published var token: String?
    @Published var currentUser: AppUser?

    var isLoggedIn: Bool { token != nil && currentUser != nil }

    private init() {
        self.token = UserDefaults.standard.string(forKey: "auth_token")
        if let data = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(AppUser.self, from: data) {
            self.currentUser = user
        }
    }

    func save(token: String, user: AppUser) {
        self.token       = token
        self.currentUser = user
        UserDefaults.standard.set(token, forKey: "auth_token")
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "current_user")
        }
        // Save company info
        if let cid = user.company_id {
            UserDefaults.standard.set(cid, forKey: "company_id")
        }
        if let cname = user.company_name {
            UserDefaults.standard.set(cname, forKey: "company_name")
        }
        // أرسل device token إذا كان محفوظاً
        if let dt = UserDefaults.standard.string(forKey: "apns_device_token") {
            Task { try? await NetworkManager.shared.registerDeviceToken(dt) }
        }
        // جدوّل الإشعار فقط للسوبرفايزر
        if user.role == "supervisor" {
            AppDelegate.scheduleWednesdayReminder()
        }
    }

    func logout() {
        token       = nil
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        UserDefaults.standard.removeObject(forKey: "company_id")
        UserDefaults.standard.removeObject(forKey: "company_name")
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["wednesday_eval_reminder"])
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Network Manager
// ═══════════════════════════════════════════════════
class NetworkManager {
    static let shared = NetworkManager()
    let session = URLSession.shared

    func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        // استخدام guard بدل force unwrap لتجنب crash لو الـ path يحتوي أحرف خاصة
        let urlString = BASE_URL + path
        guard let url = URL(string: urlString) else {
            // fallback آمن — URL فارغ بدل crash
            var fallback = URLRequest(url: URL(string: "about:blank")!)
            fallback.httpMethod = method
            return fallback
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = SessionManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    func login(code: String, deviceToken: String? = nil) async throws -> LoginResponse {
        var body: [String: Any] = ["code": code]
        if let dt = deviceToken { body["device_token"] = dt }
        let req = makeRequest("/api/login", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Login failed"
            throw NSError(domain: "Login", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    func loginWithEmail(email: String, password: String, deviceToken: String? = nil) async throws -> LoginResponse {
        var body: [String: Any] = ["email": email, "password": password]
        if let dt = deviceToken { body["device_token"] = dt }
        let req = makeRequest("/api/login", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Login failed"
            throw NSError(domain: "Login", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    func logout() async throws {
        let req = makeRequest("/api/logout", method: "POST")
        _ = try await session.data(for: req)
    }

    func getEmployees() async throws -> [Employee] {
        let (data, _) = try await session.data(for: makeRequest("/api/employees"))
        return try JSONDecoder().decode([Employee].self, from: data)
    }

    func getMyRequests() async throws -> [RequestItem] {
        let (data, _) = try await session.data(for: makeRequest("/api/requests/mine"))
        return try JSONDecoder().decode([RequestItem].self, from: data)
    }

    func submitRequest(employeeId: Int, type: String, reason: String,
                       startDate: String?, endDate: String?,
                       pdfData: Data?, pdfName: String?) async throws -> Bool {
        let boundary = UUID().uuidString
        guard let reqURL = URL(string: BASE_URL + "/api/requests/new") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = SessionManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("employee_id", "\(employeeId)")
        field("type", type)
        field("reason", reason)
        if let s = startDate { field("start_date", s) }
        if let e = endDate   { field("end_date", e) }
        if let pdf = pdfData, let name = pdfName {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"pdf_file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
            body.append(pdf)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (_, response) = try await session.data(for: req)
        return (response as? HTTPURLResponse)?.statusCode == 201
    }

    func getAdminRequests(status: String = "pending") async throws -> [RequestItem] {
        let (data, _) = try await session.data(for: makeRequest("/api/admin/requests?status=\(status)"))
        return try JSONDecoder().decode([RequestItem].self, from: data)
    }

    func decideRequest(reqId: Int, decision: String, comment: String) async throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: ["decision": decision, "comment": comment])
        var req  = makeRequest("/api/admin/requests/\(reqId)/decide", method: "POST", body: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("decideRequest status:", code, String(data: data, encoding: .utf8) ?? "")
        return code == 200
    }

    func getHRTasks() async throws -> [HRTask] {
        let (data, _) = try await session.data(for: makeRequest("/api/hr/inbox"))
        return try JSONDecoder().decode([HRTask].self, from: data)
    }

    func applyHRTask(taskId: Int) async throws -> Bool {
        let req = makeRequest("/api/hr/tasks/\(taskId)/apply", method: "POST")
        let (_, response) = try await session.data(for: req)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    func getKPI(ws: String? = nil, we: String? = nil) async throws -> KPIData {
        var path = "/api/admin/kpi"
        if let ws = ws, let we = we { path += "?week_start=\(ws)&week_end=\(we)" }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(KPIData.self, from: data)
    }

    func getEmployeeSummary(empId: Int) async throws -> EmployeeSummary {
        let (data, _) = try await session.data(for: makeRequest("/api/employees/\(empId)/summary"))
        // استخدام Codable بدل parse يدوي — لو السيرفر غيّر اسم field يظهر خطأ واضح
        struct Wrapper: Codable { let summary: EmployeeSummary }
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        return wrapper.summary
    }

    func getAttendance(date: String) async throws -> [AttendanceRow] {
        let (data, _) = try await session.data(for: makeRequest("/api/attendance?date=\(date)"))
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let empId = d["emp_id"] as? Int,
                  let name  = d["name"] as? String ?? d["emp_name"] as? String else { return nil }
            return AttendanceRow(
                empId:      empId,
                empNumber:  d["emp_number"] as? String ?? "",
                name:       name,
                department: d["department"] as? String,
                site:       d["site"] as? String,
                status:     d["status"] as? String,
                remarks:    d["remarks"] as? String ?? ""
            )
        }
    }

    func saveAttendance(date: String, records: [[String: Any]]) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["date": date, "records": records])
        _ = try await session.data(for: makeRequest("/api/attendance/save", method: "POST", body: body))
    }

    func saveDailyEval(payload: [String: Any]) async throws -> (Double, String) {
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(for: makeRequest("/api/daily-eval/save", method: "POST", body: body))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["total"] as? Double ?? 0, json?["band"] as? String ?? "—")
    }

    func saveWeeklyEval(payload: [String: Any]) async throws -> (Double, String) {
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(for: makeRequest("/api/weekly-eval/save", method: "POST", body: body))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["total"] as? Double ?? 0, json?["band"] as? String ?? "—")
    }

    func editWeeklyEval(evalId: Int, payload: [String: Any]) async throws -> (Double, String) {
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(for: makeRequest("/api/weekly-eval/\(evalId)", method: "PUT", body: body))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let err = json?["error"] as? String { throw NSError(domain: err, code: 0) }
        return (json?["total"] as? Double ?? 0, json?["band"] as? String ?? "—")
    }

    func getWeeklyEvalDetail(evalId: Int) async throws -> [String: Any] {
        let (data, _) = try await session.data(for: makeRequest("/api/weekly-eval/\(evalId)"))
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func getWeeklyReports(ws: String, we: String) async throws -> [EvalReport] {
        let (data, _) = try await session.data(for: makeRequest("/api/reports/weekly?week_start=\(ws)&week_end=\(we)"))
        return try JSONDecoder().decode([EvalReport].self, from: data)
    }

    func getDailyReports(date: String) async throws -> [EvalReport] {
        let (data, _) = try await session.data(for: makeRequest("/api/reports/daily?date=\(date)"))
        return try JSONDecoder().decode([EvalReport].self, from: data)
    }

    func registerDeviceToken(_ token: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["device_token": token])
        _ = try await session.data(for: makeRequest("/api/device-token", method: "POST", body: body))
    }
}

extension NetworkManager {
    func getEmployeeWeeklyReports(empId: Int) async throws -> [EvalReport] {
        let (data, _) = try await session.data(for: makeRequest("/api/employees/\(empId)/reports/weekly"))
        return try JSONDecoder().decode([EvalReport].self, from: data)
    }

    func getEmployeeDailyReports(empId: Int) async throws -> [EvalReport] {
        let (data, _) = try await session.data(for: makeRequest("/api/employees/\(empId)/reports/daily"))
        return try JSONDecoder().decode([EvalReport].self, from: data)
    }
    func getAdminUsers() async throws -> [UserItem] {
        let (data, _) = try await session.data(for: makeRequest("/api/admin/users"))
        return try JSONDecoder().decode([UserItem].self, from: data)
    }

    func hideUser(userId: Int) async throws -> Bool {
        var req = makeRequest("/api/admin/users/\(userId)/hide")
        req.httpMethod = "POST"
        let (_, resp) = try await session.data(for: req)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
    func getSupervisorsRanking(ws: String, we: String) async throws -> SupervisorRanking {
        let (data, _) = try await session.data(for: makeRequest(
            "/api/admin/supervisors/ranking?week_start=\(ws)&week_end=\(we)"))
        return try JSONDecoder().decode(SupervisorRanking.self, from: data)
    }
    func getSupervisorReport(supId: Int, ws: String, we: String) async throws -> SupervisorReport {
        let (data, _) = try await session.data(for: makeRequest(
            "/api/admin/supervisors/\(supId)/report?week_start=\(ws)&week_end=\(we)"))
        return try JSONDecoder().decode(SupervisorReport.self, from: data)
    }
    func getSupervisorEmployeesFull() async throws -> SupervisorEmployees {
        let (data, _) = try await session.data(for: makeRequest("/api/supervisor/employees"))
        return try JSONDecoder().decode(SupervisorEmployees.self, from: data)
    }

    func getSiteSupervisors(ws: String? = nil, we: String? = nil) async throws -> [SiteSupRow] {
        var path = "/api/site/supervisors"
        if let ws = ws, let we = we { path += "?week_start=\(ws)&week_end=\(we)" }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode([SiteSupRow].self, from: data)
    }

    func getSiteSupEmployees(supId: Int) async throws -> [SiteEmpRow] {
        let (data, _) = try await session.data(for: makeRequest("/api/site/supervisors/\(supId)/employees"))
        return try JSONDecoder().decode([SiteEmpRow].self, from: data)
    }

    func getSiteReportsSummary(ws: String? = nil, we: String? = nil) async throws -> SiteReportsSummary {
        var path = "/api/site/reports/summary"
        if let ws = ws, let we = we { path += "?week_start=\(ws)&week_end=\(we)" }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(SiteReportsSummary.self, from: data)
    }

    func getSiteAttSupervisors(date: String) async throws -> [SiteAttSupRow] {
        let (data, _) = try await session.data(for: makeRequest("/api/site/attendance/supervisors?d=\(date)"))
        return try JSONDecoder().decode([SiteAttSupRow].self, from: data)
    }

    func getSiteAttDetail(supId: Int, date: String) async throws -> SiteAttDetail {
        let (data, _) = try await session.data(for: makeRequest("/api/site/attendance/supervisor/\(supId)?d=\(date)"))
        return try JSONDecoder().decode(SiteAttDetail.self, from: data)
    }

    func getSiteRequests() async throws -> [SiteRequestRow] {
        let (data, _) = try await session.data(for: makeRequest("/api/site/requests"))
        return try JSONDecoder().decode([SiteRequestRow].self, from: data)
    }

    func getSiteTbtList(days: Int = 30) async throws -> [SiteTbtRow] {
        let (data, _) = try await session.data(for: makeRequest("/api/site/tbt?days=\(days)"))
        return try JSONDecoder().decode([SiteTbtRow].self, from: data)
    }

    func getSiteTbtDetail(id: Int) async throws -> SiteTbtDetail {
        let (data, _) = try await session.data(for: makeRequest("/api/site/tbt/\(id)"))
        return try JSONDecoder().decode(SiteTbtDetail.self, from: data)
    }

    func getSiteSupEval(supId: Int, weekStart: String? = nil, weekEnd: String? = nil) async throws -> SiteSupEvalData {
        var path = "/api/site/supervisor/\(supId)/report"
        if let ws = weekStart, let we = weekEnd {
            path += "?week_start=\(ws)&week_end=\(we)"
        }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(SiteSupEvalData.self, from: data)
    }

    func getUnassignedEmployees() async throws -> [UnassignedEmployee] {
        let (data, _) = try await session.data(for: makeRequest("/api/employees/unassigned"))
        return try JSONDecoder().decode([UnassignedEmployee].self, from: data)
    }
}

// ── موديلات مقارنة المشرفين ──
struct SupervisorRankRow: Codable, Identifiable {
    let id:        Int
    let name:      String
    let code:      String
    let target:    Int
    let done:      Int
    let done_prev: Int
    let coverage:  Double
    let avg_score: Double?
    let delta:     Int
    let trend:     String
}

struct SupervisorRanking: Codable {
    let week_start: String
    let week_end:   String
    let rows:       [SupervisorRankRow]
}

// ── موديلات تقرير المشرف ──
struct SupervisorReport: Codable {
    let supervisor:  SupervisorInfo
    let week_start:  String
    let week_end:    String
    let total_emp:   Int
    let evaluated:   Int
    let avg_score:   Double?
    let present_cnt: Int
    let employees:   [SupervisorEmpRow]
}

struct SupervisorInfo: Codable {
    let id:   Int
    let name: String
    let code: String
}

struct SupervisorEmpRow: Codable, Identifiable {
    let emp_id:     Int
    let emp_number: String
    let name:       String
    let department: String?
    let evaluated:  Bool
    let total:      Double?
    let band:       String?
    var id: Int { emp_id }
}

// ═══════════════════════════════════════════════════
//  MARK: - HSE Models
// ═══════════════════════════════════════════════════

struct HseCheckinItem: Codable {
    let id:       Int
    let date:     String
    let location: String
}

struct HseObsPhoto: Codable {
    let path:       String
    let photo_type: String
}

struct HseObservationItem: Codable, Identifiable {
    let id:             Int
    let date:           String
    let location:       String
    let obs_type:       String
    let category:       String
    let risk_level:     String
    let description:    String
    let action_taken:   String
    let status:         String
    let closed_at:      String?
    let closure_action: String
    let photos:         [HseObsPhoto]?
    let officer_name:   String?
}

struct HseObservationsResponse: Codable {
    let items: [HseObservationItem]
    let page:  Int
    let pages: Int
    let total: Int
}

struct HseAccessEntry: Codable, Identifiable {
    let user_id:   Int
    let name:      String
    let code:      String
    let role:      String
    let access_id: Int
    var id: Int { access_id }
}

struct HseJsoItem: Codable, Identifiable {
    let id:           Int
    let date:         String
    let jso_number:   String
    let location:     String
    let action_taken: String
    let photo_path:   String?
    let officer_name: String?
}

struct HseJsoResponse: Codable {
    let items: [HseJsoItem]
    let page:  Int
    let pages: Int
    let total: Int
}

struct HseTbtAttendee: Codable {
    let emp_number: String
    let emp_name:   String
}

struct HseTbtItem: Codable, Identifiable {
    let id:              Int
    let date:            String
    let topic:           String
    let location:        String
    let supervisor_name: String?
    let supervisor_role: String?
    let officer_name:    String?
    let attendee_count:  Int
    let attendees:       [HseTbtAttendee]

    var supervisorPositionLabel: String {
        switch supervisor_role ?? "" {
        case "supervisor":           return "Supervisor"
        case "site_supervisor":      return "Site Supervisor"
        case "safety_officer":       return "Safety Officer"
        case "admin", "super_admin": return "Admin"
        default:                     return "Supervisor"
        }
    }
}

struct HseTbtResponse: Codable {
    let items: [HseTbtItem]
    let page:  Int
    let pages: Int
    let total: Int
}

struct HseNearMissItem: Codable, Identifiable {
    let id:              Int
    let date:            String
    let location:        String
    let description:     String
    let immediate_cause: String
    let action_taken:    String
    let reported_to:     String
    let photo_path:      String?
}

struct HseNearMissResponse: Codable {
    let items: [HseNearMissItem]
    let page:  Int
    let pages: Int
    let total: Int
}

struct HseBbsItem: Codable, Identifiable {
    let id:           Int
    let date:         String
    let card_count:   Int
    let notes:        String
    let officer_name: String?
}

struct HsePtwItem: Codable, Identifiable {
    let id:             Int
    let permit_number:  String
    let permit_type:    String
    let description:    String
    let location:       String
    let week_start:     String
    let week_end:       String
    let status:         String
    let attached_to_id: Int?
    let expired:        Bool
    let officer_name:   String?
}

struct HseManpowerItem: Codable, Identifiable {
    let id:           Int
    let date:         String
    let location:     String
    let total_count:  Int
    let breakdown:    [String: Int]?
    let notes:        String
    let officer_name: String?
}

struct HseChecklistEntry: Codable {
    let item: String
    let ok:   Bool
    let note: String
}

struct HseInspectionItem: Codable, Identifiable {
    let id:            Int
    let date:          String
    let location:      String
    let overall_score: Double?
    let notes:         String
    let checklist:     [HseChecklistEntry]?
}

struct HseInspectionHistoryItem: Codable, Identifiable {
    let id:            Int
    let date:          String
    let location:      String
    let overall_score: Double?
    let notes:         String
    let officer_name:  String?
}

struct HseCaItem: Codable, Identifiable {
    let id:                Int
    let observation_id:    Int
    let assigned_to:       String
    let due_date:          String
    let action_required:   String
    let status:            String
    let overdue:           Bool
    let completed_at:      String?
    let completion_notes:  String
    let created_at:        String
}

struct HseEmployeeLookup: Codable {
    let found:      Bool
    let name:       String?
    let emp_number: String?
}

struct HseDashboardOfficer: Codable, Identifiable {
    let id:         Int
    let name:       String
    let checked_in: Bool
    let location:   String?
    let obs_week:   Int
    let jso_week:   Int
    let tbt_week:   Int
    let nm_week:    Int
    let bbs_week:   Int
    let total_week: Int
}

struct HseHighRiskItem: Codable, Identifiable {
    let id:          Int
    let date:        String
    let officer:     String
    let category:    String
    let location:    String
    let description: String
}

struct HseDashboard: Codable {
    let today:           String
    let week_start:      String
    let officers:        [HseDashboardOfficer]
    let high_risk_open:  [HseHighRiskItem]
}

struct HseTbtDetailItem: Codable, Identifiable {
    let id:              Int
    let date:            String
    let topic:           String
    let location:        String
    let sign_photo_path: String?
    let supervisor_name: String?
    let supervisor_role: String?
    let attendee_count:  Int
    let attendees:       [HseTbtAttendee]?

    var supervisorPositionLabel: String {
        switch supervisor_role ?? "" {
        case "supervisor":      return "Supervisor"
        case "site_supervisor": return "Site Supervisor"
        case "safety_officer":  return "Safety Officer"
        case "admin", "super_admin": return "Admin"
        default: return "Supervisor"
        }
    }
}

struct HseOfficerInfo: Codable {
    let id:   Int
    let name: String
}

struct HseOfficerDetailResponse: Codable {
    let officer:         HseOfficerInfo
    let checkin_today:   HseCheckinItem?
    let checkin_history: [HseCheckinItem]
    let period_days:     Int
    let observations:    [HseObservationItem]
    let tbts:            [HseTbtDetailItem]
    let jso_closures:    [HseJsoItem]
    let near_misses:     [HseNearMissItem]
    let bbs:             [HseBbsItem]
}

struct HseReportRow: Codable, Identifiable {
    let officer_id:      Int
    let officer_name:    String
    let checkin_days:    Int
    let obs_total:       Int
    let obs_unsafe_act:  Int
    let obs_unsafe_cond: Int
    let obs_positive:    Int
    let obs_high:        Int
    let obs_open:        Int
    let jso:             Int
    let tbt:             Int
    let tbt_attendees:   Int
    let nm:              Int
    let bbs:             Int
    let ptw:             Int
    let mp_total:        Int
    let avg_insp:        Double?
    let ca_open:         Int
    let score:           Double
    let total_activity:  Int
    var id: Int { officer_id }
}

struct HseWeeklyReport: Codable {
    let week_start: String
    let week_end:   String
    let rows:       [HseReportRow]
    let prev_rows:  [HseReportRow]?   // optional: old server may not return it
}

struct HseMonthlyReport: Codable {
    let year:      Int
    let month:     Int
    let rows:      [HseReportRow]
    let prev_rows: [HseReportRow]?    // optional: old server may not return it
}

struct HseObsTrend: Codable {
    let labels:      [String]
    let unsafe_act:  [Int]
    let unsafe_cond: [Int]
    let positive:    [Int]
}

struct HseOfficerScores: Codable {
    let labels: [String]
    let scores: [Double]
}

struct HseMpTrend: Codable {
    let labels: [String]
    let counts: [Int]
}

struct HseChartsData: Codable {
    let obs_trend:      HseObsTrend
    let cat_data:       [String: Int]
    let officer_scores: HseOfficerScores
    let mp_data:        HseMpTrend
}

struct UserLocationItem {
    let pkg: Int
    let unit: String
    let areaText: String
    let updatedAt: String
}

struct SafetyOfficerStat: Identifiable {
    let id: Int
    let name: String
    let code: String
    let checkedIn: Bool
    let checkinLocation: String?
    let obsWeek: Int
    let tbtWeek: Int
    let nmWeek: Int
    let jsoWeek: Int
    let bbsWeek: Int
    let ptwWeek: Int
    let inspWeek: Int
    let totalWeek: Int
    let score: Double
    let locationPkg: Int?
    let locationUnit: String?
}

struct NearestPerson: Identifiable {
    let id = UUID()
    let userId: Int
    let name: String
    let role: String
    let supervisorCode: String
    let pkg: Int
    let unit: String
    let areaText: String
    let proximity: Int

    var proximityLabel: String {
        switch proximity {
        case 0: return "Same Area"
        case 1: return "Same PKG"
        default: return "Diff. PKG"
        }
    }
    var locationString: String {
        var s = "PKG \(pkg) · Unit \(unit)"
        if !areaText.isEmpty { s += " — \(areaText)" }
        return s
    }
    var roleLabel: String {
        switch role {
        case "safety_officer":  return "Safety Officer"
        case "supervisor":      return "Supervisor"
        case "site_supervisor": return "Site Supervisor"
        default:                return role
        }
    }
}

struct TbtEmployee: Identifiable {
    let id = UUID()
    let empNumber: String
    let name: String
    let department: String
}

// ═══════════════════════════════════════════════════
//  MARK: - HSE Network Methods (extension)
// ═══════════════════════════════════════════════════

extension NetworkManager {

    // Locations autocomplete
    func hseLocations() async throws -> [String] {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/locations"))
        return try JSONDecoder().decode([String].self, from: data)
    }

    // Check-in
    // ── Status check helper — throws on non-2xx with server error message ──
    private func hseCheck(_ resp: URLResponse, data: Data) throws {
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                      ?? "خطأ \(code)"
            throw NSError(domain: "HSE", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    func hseCheckinToday() async throws -> HseCheckinItem? {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/checkin/today"))
        if data == Data("null".utf8) { return nil }
        return try JSONDecoder().decode(HseCheckinItem.self, from: data)
    }

    func hseCheckin(location: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["location": location])
        let req = makeRequest("/api/hse/checkin", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // Observations
    func getHseDashboard() async throws -> HseDashboard {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/dashboard"))
        return try JSONDecoder().decode(HseDashboard.self, from: data)
    }

    func getHseWeeklyReport(weekStart: String? = nil) async throws -> HseWeeklyReport {
        var path = "/api/hse/reports/weekly"
        if let ws = weekStart { path += "?week_start=\(ws)" }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(HseWeeklyReport.self, from: data)
    }

    func hseObservations(page: Int = 1, status: String = "") async throws -> HseObservationsResponse {
        var path = "/api/hse/observations?page=\(page)"
        if !status.isEmpty { path += "&status=\(status)" }
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(HseObservationsResponse.self, from: data)
    }

    func hseObservationCreate(date: String, location: String, obsType: String, category: String,
                               riskLevel: String, description: String, actionTaken: String) async throws -> Int {
        let body: [String: Any] = ["date": date, "location": location, "obs_type": obsType,
                                   "category": category, "risk_level": riskLevel,
                                   "description": description, "action_taken": actionTaken]
        let req = makeRequest("/api/hse/observation", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int ?? 0
    }

    func hseObservationClose(id: Int, closureAction: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["closure_action": closureAction])
        let req = makeRequest("/api/hse/observation/\(id)/close", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseObservationDelete(id: Int) async throws {
        let req = makeRequest("/api/hse/observation/\(id)", method: "DELETE")
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // JSO
    func hseJsoList(page: Int = 1) async throws -> HseJsoResponse {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/jso?page=\(page)"))
        return try JSONDecoder().decode(HseJsoResponse.self, from: data)
    }

    func hseJsoCreate(date: String, jsoNumber: String, location: String, actionTaken: String) async throws -> Int {
        let body: [String: Any] = ["date": date, "jso_number": jsoNumber,
                                   "location": location, "action_taken": actionTaken]
        let req = makeRequest("/api/hse/jso", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int ?? 0
    }

    func hseJsoDelete(id: Int) async throws {
        let req = makeRequest("/api/hse/jso/\(id)", method: "DELETE")
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // TBT
    func hseTbtList(page: Int = 1) async throws -> HseTbtResponse {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/tbt?page=\(page)"))
        return try JSONDecoder().decode(HseTbtResponse.self, from: data)
    }

    func hseSupervisorLookup(code: String) async throws -> (found: Bool, name: String?) {
        let (data, resp) = try await session.data(for: makeRequest(
            "/api/hse/supervisor_lookup?code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)"))
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let found = json?["found"] as? Bool ?? false
        let name  = json?["name"]  as? String
        return (found, name)
    }

    func hseTbtCreate(date: String, topic: String, location: String,
                      supervisorCode: String?, attendees: [[String: String]]) async throws -> Int {
        var body: [String: Any] = ["date": date, "topic": topic,
                                   "location": location, "attendees": attendees]
        if let code = supervisorCode, !code.isEmpty { body["supervisor_code"] = code }
        let req = makeRequest("/api/hse/tbt", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int ?? 0
    }

    func hseTbtDelete(id: Int) async throws {
        let req = makeRequest("/api/hse/tbt/\(id)", method: "DELETE")
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // Near Miss
    func hseNearMissList(page: Int = 1) async throws -> HseNearMissResponse {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/nearmiss?page=\(page)"))
        return try JSONDecoder().decode(HseNearMissResponse.self, from: data)
    }

    func hseNearMissCreate(date: String, location: String, description: String,
                            immediateCause: String, actionTaken: String, reportedTo: String) async throws -> Int {
        let body: [String: Any] = ["date": date, "location": location, "description": description,
                                   "immediate_cause": immediateCause, "action_taken": actionTaken,
                                   "reported_to": reportedTo]
        let req = makeRequest("/api/hse/nearmiss", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int ?? 0
    }

    func hseNearMissDelete(id: Int) async throws {
        let req = makeRequest("/api/hse/nearmiss/\(id)", method: "DELETE")
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // BBS
    func hseBbsToday() async throws -> HseBbsItem? {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/bbs/today"))
        if data == Data("null".utf8) { return nil }
        return try JSONDecoder().decode(HseBbsItem.self, from: data)
    }

    func hseBbsList() async throws -> [HseBbsItem] {
        let (data, _) = try await session.data(for: makeRequest("/api/hse/bbs"))
        return try JSONDecoder().decode([HseBbsItem].self, from: data)
    }

    func hseBbsSave(cardCount: Int, notes: String) async throws {
        let body: [String: Any] = ["card_count": cardCount, "notes": notes]
        let req = makeRequest("/api/hse/bbs", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseBbsDelete(id: Int) async throws {
        let req = makeRequest("/api/hse/bbs/\(id)", method: "DELETE")
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // ── Update (PUT) ────────────────────────────────────────────────────

    func hseObservationUpdate(id: Int, location: String, obsType: String, category: String,
                               riskLevel: String, description: String, actionTaken: String) async throws {
        let body: [String: Any] = ["location": location, "obs_type": obsType, "category": category,
                                   "risk_level": riskLevel, "description": description,
                                   "action_taken": actionTaken]
        let req = makeRequest("/api/hse/observation/\(id)", method: "PUT",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseJsoUpdate(id: Int, jsoNumber: String, location: String, actionTaken: String) async throws {
        let body: [String: Any] = ["jso_number": jsoNumber, "location": location,
                                   "action_taken": actionTaken]
        let req = makeRequest("/api/hse/jso/\(id)", method: "PUT",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseTbtUpdate(id: Int, topic: String, location: String,
                      attendees: [[String: String]]) async throws {
        let body: [String: Any] = ["topic": topic, "location": location, "attendees": attendees]
        let req = makeRequest("/api/hse/tbt/\(id)", method: "PUT",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseNearMissUpdate(id: Int, location: String, description: String,
                            immediateCause: String, actionTaken: String, reportedTo: String) async throws {
        let body: [String: Any] = ["location": location, "description": description,
                                   "immediate_cause": immediateCause, "action_taken": actionTaken,
                                   "reported_to": reportedTo]
        let req = makeRequest("/api/hse/nearmiss/\(id)", method: "PUT",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // ── Photo Upload (multipart) ────────────────────────────────────────

    func hseUploadPhoto(path: String, imageData: Data, fieldName: String = "photo") async throws {
        let boundary = "HSEBoundary-\(UUID().uuidString)"
        var req = makeRequest(path, method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let nl = "\r\n"
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"photo.jpg\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(nl)\(nl)".data(using: .utf8)!)
        body.append(imageData)
        body.append("\(nl)--\(boundary)--\(nl)".data(using: .utf8)!)
        let (data, resp) = try await session.upload(for: req, from: body)
        try hseCheck(resp, data: data)
    }

    func hseObservationUploadPhoto(obsId: Int, imageData: Data) async throws {
        try await hseUploadPhoto(path: "/api/hse/observation/\(obsId)/photo", imageData: imageData)
    }

    func hseJsoUploadPhoto(jsoId: Int, imageData: Data) async throws {
        try await hseUploadPhoto(path: "/api/hse/jso/\(jsoId)/photo", imageData: imageData)
    }

    func hseNearMissUploadPhoto(nmId: Int, imageData: Data) async throws {
        try await hseUploadPhoto(path: "/api/hse/nearmiss/\(nmId)/photo", imageData: imageData)
    }

    func hseTbtUploadPhoto(tbtId: Int, imageData: Data) async throws {
        try await hseUploadPhoto(path: "/api/hse/tbt/\(tbtId)/photo", imageData: imageData)
    }

    // Employee lookup for TBT
    func hseEmployeeLookup(empNumber: String) async throws -> HseEmployeeLookup {
        let path = "/api/hse/employee_lookup?emp_number=\(empNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? empNumber)"
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode(HseEmployeeLookup.self, from: data)
    }

    // Supervisor dashboard
    func hseDashboard() async throws -> HseDashboard {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/dashboard"))
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw NSError(domain: "HSE", code: code,
                          userInfo: ["statusCode": code])
        }
        return try JSONDecoder().decode(HseDashboard.self, from: data)
    }

    func hseOfficerDetail(officerId: Int, days: Int = 30) async throws -> HseOfficerDetailResponse {
        let (data, resp) = try await session.data(for:
            makeRequest("/api/hse/officer/\(officerId)/detail?days=\(days)"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode(HseOfficerDetailResponse.self, from: data)
    }

    // ── PTW ──────────────────────────────────────────────────────────
    func hsePtwList() async throws -> [HsePtwItem] {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/ptw"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode([HsePtwItem].self, from: data)
    }

    func hsePtwCreate(permitNumber: String, permitType: String, description: String,
                      location: String, weekStart: String?) async throws -> Int {
        var body: [String: Any] = [
            "permit_number": permitNumber,
            "permit_type":   permitType,
            "description":   description,
            "location":      location,
        ]
        if let ws = weekStart { body["week_start"] = ws }
        let req = makeRequest("/api/hse/ptw", method: "POST",
                              body: try! JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["id"] as? Int ?? 0
    }

    func hsePtwUpdateStatus(id: Int, status: String) async throws {
        let body = try! JSONSerialization.data(withJSONObject: ["status": status])
        let req = makeRequest("/api/hse/ptw/\(id)/status", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // ── Man Power ─────────────────────────────────────────────────────
    func hseManpowerToday() async throws -> HseManpowerItem? {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/manpower/today"))
        try hseCheck(resp, data: data)
        if let json = try? JSONSerialization.jsonObject(with: data),
           case Optional<Any>.none = json as AnyObject as Any? { return nil }
        if data == "null".data(using: .utf8) { return nil }
        return try JSONDecoder().decode(HseManpowerItem.self, from: data)
    }

    func hseManpowerSave(totalCount: Int, location: String, notes: String,
                         breakdown: [String: Int]) async throws {
        let body = try! JSONSerialization.data(withJSONObject: [
            "total_count": totalCount,
            "location":    location,
            "notes":       notes,
            "breakdown":   breakdown,
        ])
        let req = makeRequest("/api/hse/manpower", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func hseManpowerHistory() async throws -> [HseManpowerItem] {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/manpower/history"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode([HseManpowerItem].self, from: data)
    }

    // ── Inspection ────────────────────────────────────────────────────
    func hseInspectionToday() async throws -> HseInspectionItem? {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/inspection/today"))
        try hseCheck(resp, data: data)
        if data == "null".data(using: .utf8) { return nil }
        return try JSONDecoder().decode(HseInspectionItem.self, from: data)
    }

    func hseInspectionSave(location: String, notes: String,
                           checklist: [HseChecklistEntry]) async throws -> Double {
        let items = checklist.map { ["item": $0.item, "ok": $0.ok, "note": $0.note] as [String: Any] }
        let body = try! JSONSerialization.data(withJSONObject: [
            "location":  location,
            "notes":     notes,
            "checklist": items,
        ])
        let req = makeRequest("/api/hse/inspection", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["score"] as? Double ?? 0.0
    }

    func hseInspectionHistory() async throws -> [HseInspectionHistoryItem] {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/inspection/history"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode([HseInspectionHistoryItem].self, from: data)
    }

    func hseMyCa() async throws -> [HseCaItem] {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/my-ca"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode([HseCaItem].self, from: data)
    }

    // ── Report: Weekly ────────────────────────────────────────────────
    func hseWeeklyReport(weekStart: String) async throws -> HseWeeklyReport {
        let (data, resp) = try await session.data(for:
            makeRequest("/api/hse/reports/weekly?week_start=\(weekStart)"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode(HseWeeklyReport.self, from: data)
    }

    // ── Report: Monthly ───────────────────────────────────────────────
    func hseMonthlyReport(year: Int, month: Int) async throws -> HseMonthlyReport {
        let (data, resp) = try await session.data(for:
            makeRequest("/api/hse/reports/monthly?year=\(year)&month=\(month)"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode(HseMonthlyReport.self, from: data)
    }

    // ── Charts ────────────────────────────────────────────────────────
    func hseCharts() async throws -> HseChartsData {
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/charts"))
        try hseCheck(resp, data: data)
        return try JSONDecoder().decode(HseChartsData.self, from: data)
    }

    // ── Observation closure photo (after type) ─────────────────────────
    func hseObservationUploadClosurePhoto(obsId: Int, imageData: Data) async throws {
        let boundary = "HSEBoundary-\(UUID().uuidString)"
        var req = makeRequest("/api/hse/observation/\(obsId)/photo", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        let nl = "\r\n"
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo_type\"\(nl)\(nl)".data(using: .utf8)!)
        body.append("after\(nl)".data(using: .utf8)!)
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"closure.jpg\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(nl)\(nl)".data(using: .utf8)!)
        body.append(imageData)
        body.append("\(nl)--\(boundary)--\(nl)".data(using: .utf8)!)
        let (data, resp) = try await session.upload(for: req, from: body)
        try hseCheck(resp, data: data)
    }

    // ── Corrective Actions ────────────────────────────────────────────
    func hseCorrectiveActionAdd(observationId: Int, assignedTo: String,
                                dueDate: String, actionRequired: String) async throws -> Int {
        let body: [String: Any] = [
            "observation_id":  observationId,
            "assigned_to":     assignedTo,
            "due_date":        dueDate,
            "action_required": actionRequired,
        ]
        let req = makeRequest("/api/hse/corrective_action", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int ?? 0
    }

    func hseCorrectiveActionUpdate(caId: Int, status: String, completionNotes: String = "") async throws {
        var body: [String: Any] = ["status": status]
        if !completionNotes.isEmpty { body["completion_notes"] = completionNotes }
        let req = makeRequest("/api/hse/corrective_action/\(caId)", method: "PUT",
                              body: try JSONSerialization.data(withJSONObject: body))
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // ── Requests: Leave & Permission Signing ─────────────────────────
    struct LeaveFormInfo: Codable {
        let request_id: Int
        let employee_name: String
        let emp_number: String
        let department: String?
        let site: String?
        let supervisor: String?
        let start_date: String
        let end_date: String
        let days: String
        let reason: String?
        let approved_at: String?
        let has_form: Bool
        let pdf_url: String?
        let signed: Bool
        let signed_at: String?
        let signer_name: String?
    }

    struct PermissionFormInfo: Codable {
        let request_id: Int
        let employee_name: String
        let emp_number: String
        let department: String?
        let supervisor: String?
        let date: String
        let reason: String?
        let status: String
        let signed: Bool
        let signed_at: String?
        let signer_name: String?
        let pdf_url: String?
    }

    func leaveFormInfo(requestId: Int) async throws -> LeaveFormInfo {
        let req = makeRequest("/api/leave/form/\(requestId)")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(LeaveFormInfo.self, from: data)
    }

    func leaveSign(requestId: Int, signature: String, employeeName: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "signature": signature, "employee_name": employeeName])
        let req = makeRequest("/api/leave/sign/\(requestId)", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    func permissionFormInfo(requestId: Int) async throws -> PermissionFormInfo {
        let req = makeRequest("/api/permission/form/\(requestId)")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(PermissionFormInfo.self, from: data)
    }

    func permissionSign(requestId: Int, signature: String, employeeName: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "signature": signature, "employee_name": employeeName])
        let req = makeRequest("/api/permission/sign/\(requestId)", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        try hseCheck(resp, data: data)
    }

    // ── Location ──────────────────────────────────────────────────────
    func saveLocation(pkg: Int, unit: String, areaText: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "pkg": pkg, "unit": unit, "area_text": areaText])
        let req = makeRequest("/api/location", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Loc", code: http.statusCode)
        }
        _ = data
    }

    func getMyLocation() async throws -> UserLocationItem? {
        let (data, _) = try await session.data(for: makeRequest("/api/location/me"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let locDict = json?["location"] as? [String: Any] else { return nil }
        return UserLocationItem(
            pkg: locDict["pkg"] as? Int ?? 0,
            unit: locDict["unit"] as? String ?? "",
            areaText: locDict["area_text"] as? String ?? "",
            updatedAt: locDict["updated_at"] as? String ?? ""
        )
    }

    func getNearestPersons() async throws -> [NearestPerson] {
        let (data, resp) = try await session.data(for: makeRequest("/api/location/nearest"))
        if let http = resp as? HTTPURLResponse, http.statusCode == 400 { return [] }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let arr = json?["nearest"] as? [[String: Any]] ?? []
        return arr.map { d in
            NearestPerson(
                userId: d["user_id"] as? Int ?? 0,
                name: d["name"] as? String ?? "",
                role: d["role"] as? String ?? "",
                supervisorCode: d["supervisor_code"] as? String ?? "",
                pkg: d["pkg"] as? Int ?? 0,
                unit: d["unit"] as? String ?? "",
                areaText: d["area_text"] as? String ?? "",
                proximity: d["proximity"] as? Int ?? 2
            )
        }
    }

    func getMySupervisorsLocations() async throws -> [NearestPerson] {
        let (data, resp) = try await session.data(for: makeRequest("/api/location/my-supervisors"))
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return [] }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let arr = json?["supervisors"] as? [[String: Any]] ?? []
        return arr.map { d in
            NearestPerson(
                userId: d["user_id"] as? Int ?? 0,
                name: d["name"] as? String ?? "",
                role: "supervisor",
                supervisorCode: d["supervisor_code"] as? String ?? "",
                pkg: d["pkg"] as? Int ?? 0,
                unit: d["unit"] as? String ?? "",
                areaText: d["area_text"] as? String ?? "",
                proximity: 0
            )
        }
    }

    func getAllLocations() async throws -> [NearestPerson] {
        let (data, resp) = try await session.data(for: makeRequest("/api/location/all"))
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return [] }
        let arr = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return arr.map { d in
            NearestPerson(
                userId: d["user_id"] as? Int ?? 0,
                name: d["name"] as? String ?? "",
                role: d["role"] as? String ?? "",
                supervisorCode: d["supervisor_code"] as? String ?? "",
                pkg: d["pkg"] as? Int ?? 0,
                unit: d["unit"] as? String ?? "",
                areaText: d["area_text"] as? String ?? "",
                proximity: -1
            )
        }
    }

    func hseTbtSupervisorEmployees(supervisorCode: String) async throws -> (supervisorName: String, employees: [TbtEmployee]) {
        let code = supervisorCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? supervisorCode
        let (data, resp) = try await session.data(for: makeRequest("/api/hse/tbt/supervisor-employees?supervisor_code=\(code)"))
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 {
            throw NSError(domain: "TBT", code: 404, userInfo: [NSLocalizedDescriptionKey: "المشرف غير موجود"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let supName = (json?["supervisor"] as? [String: Any])?["name"] as? String ?? ""
        let emps = (json?["employees"] as? [[String: Any]] ?? []).map { d in
            TbtEmployee(empNumber: d["emp_number"] as? String ?? "",
                        name: d["name"] as? String ?? "",
                        department: d["department"] as? String ?? "")
        }
        return (supName, emps)
    }

    // ── Admin: Add User ───────────────────────────────────────────────
    func adminAddUser(code: String, name: String, role: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["code": code, "name": name, "role": role])
        let req = makeRequest("/api/admin/users/add", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                      ?? "فشل إضافة المستخدم"
            throw NSError(domain: "Admin", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // ── Safety Supervisor: officers list ──────────────────
    func getSafetyOfficers() async throws -> [SafetyOfficerStat] {
        let (data, resp) = try await session.data(for: makeRequest("/api/safety-supervisor/officers"))
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return [] }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let arr = json?["officers"] as? [[String: Any]] ?? []
        return arr.map { d in
            SafetyOfficerStat(
                id: d["id"] as? Int ?? 0,
                name: d["name"] as? String ?? "",
                code: d["code"] as? String ?? "",
                checkedIn: d["checked_in"] as? Bool ?? false,
                checkinLocation: d["checkin_location"] as? String,
                obsWeek: d["obs_week"] as? Int ?? 0,
                tbtWeek: d["tbt_week"] as? Int ?? 0,
                nmWeek: d["nm_week"] as? Int ?? 0,
                jsoWeek: d["jso_week"] as? Int ?? 0,
                bbsWeek: d["bbs_week"] as? Int ?? 0,
                ptwWeek: d["ptw_week"] as? Int ?? 0,
                inspWeek: d["insp_week"] as? Int ?? 0,
                totalWeek: d["total_week"] as? Int ?? 0,
                score: d["score"] as? Double ?? 0,
                locationPkg: d["location_pkg"] as? Int,
                locationUnit: d["location_unit"] as? String
            )
        }
    }

    // ── Admin: HSE Access ─────────────────────────────────────────────
    func adminHseAccessList() async throws -> [HseAccessEntry] {
        let (data, _) = try await session.data(for: makeRequest("/api/admin/hse-access"))
        return try JSONDecoder().decode([HseAccessEntry].self, from: data)
    }

    func adminHseAccessGrant(code: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["code": code])
        let req = makeRequest("/api/admin/hse-access/grant", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "HSE", code: 0, userInfo: [NSLocalizedDescriptionKey: msg ?? "Error"])
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["name"] as? String ?? code
    }

    func adminHseAccessRevoke(userId: Int) async throws {
        let req = makeRequest("/api/admin/hse-access/\(userId)", method: "DELETE")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "HSE", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to revoke"])
        }
    }
}
