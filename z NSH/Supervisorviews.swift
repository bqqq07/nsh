import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════
//  MARK: - قائمة الموظفين
// ═══════════════════════════════════════════════════
struct EmployeesListView: View {
    @State private var employees:     [Employee] = []
    @State private var isLoading      = true
    @State private var showAddSheet   = false
    @State private var searchText     = ""
    @State private var errorMsg       = ""

    var filtered: [Employee] {
        searchText.isEmpty ? employees :
        employees.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.emp_number.contains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEach(filtered) { emp in
                            NavigationLink(destination: EmployeeDetailView(employee: emp)) {
                                EmpRow(emp: emp)
                            }
                            .listRowBackground(Color.white)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deactivate(emp) }
                                } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "بحث باسم أو رقم")
                    .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .navigationTitle("الموظفون")
            .alert("خطأ", isPresented: .constant(!errorMsg.isEmpty), actions: {
                Button("حسناً") { errorMsg = "" }
            }, message: { Text(errorMsg) })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEmployeeSheet { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMsg  = ""
        do {
            employees = try await NetworkManager.shared.getEmployeesCached()
        } catch {
            errorMsg  = "تعذّر تحميل الموظفين"
            employees = []
        }
        isLoading = false
    }

    private func deactivate(_ emp: Employee) async {
        let req = NetworkManager.shared.makeRequest("/api/employees/\(emp.id)/deactivate", method: "POST")
        _ = try? await URLSession.shared.data(for: req)
        await load()
    }
}

struct EmpRow: View {
    let emp: Employee
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "#4f8ef7").opacity(0.12)).frame(width: 44, height: 44)
                Text(String(emp.name.prefix(1)))
                    .font(.headline).foregroundColor(Color(hex: "#4f8ef7"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(emp.name).font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                    if let d = emp.department, !d.isEmpty {
                        Text("• \(d)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// ── ورقة إضافة موظف ──────────────────────────────

struct FormRow: View {
    let label: String
    let hint: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(hint, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - تفاصيل الموظف
// ═══════════════════════════════════════════════════


// ═══════════════════════════════════════════════════
//  MARK: - الحضور
// ═══════════════════════════════════════════════════
struct AttendanceView: View {
    @State private var rows:       [AttendanceRow] = []
    @State private var date        = Date()
    @State private var isLoading   = true
    @State private var isSaving    = false
    @State private var successMsg  = ""
    @State private var viewMode    = 0  // 0=يومي، 1=أسبوعي
    @State private var weekStart   = Date().previousSunday
    let statuses = [("present","حاضر"),("absent","غائب"),("leave","إجازة")]

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── سيجمنت يومي/أسبوعي ──
                    Picker("", selection: $viewMode) {
                        Text("يومي").tag(0)
                        Text("أسبوعي").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal).padding(.top, 8)
                    .onChange(of: viewMode) { _ in Task { await load() } }

                    // ── شريط التاريخ ──
                    if viewMode == 0 {
                        HStack {
                            Button {
                                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                                Task { await load() }
                            } label: { Image(systemName: "chevron.right").foregroundColor(Color(hex: "#4f8ef7")) }

                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ar_SA"))
                                .onChange(of: date) { _ in Task { await load() } }
                            Spacer()

                            Button {
                                let next = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                                if next <= Date() { date = next; Task { await load() } }
                            } label: { Image(systemName: "chevron.left").foregroundColor(Color(hex: "#4f8ef7")) }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    } else {
                        HStack(spacing: 12) {
                            Button {
                                weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                                Task { await load() }
                            } label: { Image(systemName: "chevron.right").foregroundColor(Color(hex: "#4f8ef7")).font(.headline) }

                            Spacer()
                            VStack(spacing: 2) {
                                Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                                Text("\(weekStart.iso) — \(weekEnd.iso)").font(.subheadline.bold())
                            }
                            Spacer()

                            Button {
                                let next = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                                if next <= Date().previousSunday { weekStart = next; Task { await load() } }
                            } label: { Image(systemName: "chevron.left").foregroundColor(Color(hex: "#4f8ef7")).font(.headline) }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    }

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if rows.isEmpty {
                        Spacer()
                        Text("لا يوجد بيانات").foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List($rows) { $row in
                            AttRowView(row: $row, statuses: statuses)
                                .listRowBackground(Color.white)
                        }
                        .listStyle(.plain)
                    }

                    // ── زر الحفظ (يومي فقط) ──
                    if viewMode == 0 {
                        VStack(spacing: 4) {
                            if !successMsg.isEmpty {
                                Text(successMsg).font(.caption).foregroundColor(.green)
                            }
                            Button { Task { await saveAll() } } label: {
                                HStack {
                                    if isSaving { ProgressView().tint(.white) }
                                    else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("حفظ الحضور").font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color(hex: "#2ecc71")).foregroundColor(.white)
                                .cornerRadius(14).padding(.horizontal)
                            }
                            .disabled(isSaving)
                            .padding(.bottom, 8)
                        }
                        .background(Color.white)
                    }
                }
            }
            .navigationTitle("الحضور والغياب")
            .safeAreaInset(edge: .top) { OfflineBanner() }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        if viewMode == 0 {
            do {
                rows = try await NetworkManager.shared.getAttendance(date: date.iso)
            } catch {
                rows = []
            }
        } else {
            var allRows: [AttendanceRow] = []
            for i in 0..<5 {
                let d = Calendar.current.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                if let dayRows = try? await NetworkManager.shared.getAttendance(date: d.iso) {
                    allRows.append(contentsOf: dayRows)
                }
            }
            rows = allRows
        }
        isLoading = false
    }

    private func saveAll() async {
        isSaving = true
        let records: [[String: Any]] = rows.compactMap { r in
            guard let status = r.status else { return nil }
            return ["emp_id": r.empId, "status": status, "remarks": r.remarks]
        }
        let payload: [String: Any] = ["date": date.iso, "records": records]

        if OfflineQueue.shared.isOnline {
            // شبكة متوفرة — أرسل مباشرة
            do {
                try await NetworkManager.shared.saveAttendance(date: date.iso, records: records)
                successMsg = "تم حفظ الحضور ✓"
            } catch {
                // فشل الإرسال — احفظ للـ queue
                OfflineQueue.shared.enqueue(
                    type: .attendance,
                    endpoint: "/api/attendance/save",
                    payload: payload
                )
                successMsg = "حُفظ محلياً — سيُرسل لاحقاً ⏳"
            }
        } else {
            // بدون شبكة — احفظ للـ queue مباشرة
            OfflineQueue.shared.enqueue(
                type: .attendance,
                endpoint: "/api/attendance/save",
                payload: payload
            )
            successMsg = "حُفظ محلياً — سيُرسل عند الاتصال ⏳"
        }
        isSaving = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { successMsg = "" }
    }
}

struct AttRowView: View {
    @Binding var row: AttendanceRow
    let statuses: [(String, String)]

    var statusColor: Color {
        switch row.status {
        case "present": return Color(hex: "#2ecc71")
        case "absent":  return Color(hex: "#e74c3c")
        case "leave":   return Color(hex: "#f39c12")
        default:        return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.subheadline.bold())
                Text(row.empNumber).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { row.status ?? "" },
                set: { row.status = $0.isEmpty ? nil : $0 }
            )) {
                Text("—").tag("")
                ForEach(statuses, id: \.0) { val, label in Text(label).tag(val) }
            }
            .pickerStyle(.menu).tint(statusColor)
        }
        .padding(.vertical, 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - التقييم اليومي
// ═══════════════════════════════════════════════════

struct TargetData {
    var text = ""
    var pct: Double = 0
}

// RatingRow و TargetRow معرّفتان في EmployeeAndEvalViews.swift



// ═══════════════════════════════════════════════════
//  MARK: - التقييم الأسبوعي
// ═══════════════════════════════════════════════════

// ═══════════════════════════════════════════════════
//  MARK: - تقارير موظف
// ═══════════════════════════════════════════════════

struct EvalCard: View {
    let report:  EvalReport
    var onEdit:  (() -> Void)? = nil

    var bandColor: Color {
        switch report.band {
        case "Excellent":    return Color(hex: "#2ecc71")
        case "Good":         return Color(hex: "#3498db")
        case "Satisfactory": return Color(hex: "#f39c12")
        default:             return Color(hex: "#e74c3c")
        }
    }
    var body: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 6) {
                Text(report.eval_date ?? "\(report.week_start ?? "") — \(report.week_end ?? "")")
                    .font(.caption).foregroundColor(.secondary)
                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text("\(Int(report.targets ?? 0))/40").font(.caption.bold())
                        Text("الأهداف").font(.caption2).foregroundColor(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(report.perf ?? 0))/60").font(.caption.bold())
                        Text("الأداء").font(.caption2).foregroundColor(.secondary)
                    }
                }
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Label("تعديل", systemImage: "pencil")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: "#4f8ef7").opacity(0.1))
                            .foregroundColor(Color(hex: "#4f8ef7"))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(Int(report.total ?? 0))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(bandColor)
                Text(report.band ?? "—").font(.caption.bold()).foregroundColor(bandColor)
            }
        }
        .padding()
        .background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - طلباتي
// ═══════════════════════════════════════════════════
struct MyRequestsView: View {
    @State private var requests: [RequestItem] = []
    @State private var isLoading = true
    @State private var showNew   = false
    @State private var filter    = "all"

    let filters = [("all","الكل"),("pending","قيد المراجعة"),("approved","موافق"),("rejected","مرفوض")]

    var filtered: [RequestItem] {
        filter == "all" ? requests : requests.filter { $0.status == filter }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {
                    // ── فلتر الحالة ──
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.0) { key, label in
                                Button {
                                    filter = key
                                } label: {
                                    Text(label).font(.caption.bold())
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(filter == key ? Color(hex: "#4f8ef7") : Color.white)
                                        .foregroundColor(filter == key ? .white : .secondary)
                                        .cornerRadius(20)
                                        .shadow(color: .black.opacity(0.05), radius: 3)
                                }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 10)
                    }

                    if isLoading && requests.isEmpty {
                        Spacer(); ProgressView(); Spacer()
                    } else if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text").font(.system(size: 50)).foregroundColor(.gray.opacity(0.4))
                            Text("لا توجد طلبات").foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        List(filtered) { r in
                            RequestCard(request: r)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .environment(\.layoutDirection, .rightToLeft)
                        .refreshable { await load() }
                    }
                }
            }
            .navigationTitle("طلباتي")
            .safeAreaInset(edge: .top) { OfflineBanner() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showNew = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(isPresented: $showNew) { NewRequestView(preselectedEmployee: nil) { Task { await load() } } }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = requests.isEmpty
        do {
            requests = try await NetworkManager.shared.getMyRequestsCached()
        } catch {
            // أبق القائمة الموجودة ولا تمسحها عند خطأ الشبكة
        }
        isLoading = false
    }
}

struct RequestCard: View {
    let request: RequestItem
    @State private var showWarningForm    = false
    @State private var showLeaveForm      = false
    @State private var showPermissionForm = false

    var statusColor: Color {
        switch request.status {
        case "approved": return Color(hex: "#2ecc71")
        case "rejected": return Color(hex: "#e74c3c")
        default:         return Color(hex: "#f39c12")
        }
    }

    // مراحل تتبع الطلب
    var trackingSteps: [(String, String, Bool)] {
        // (اسم المرحلة, أيقونة, مكتملة)
        let sent     = true
        let approved = request.status == "approved" || request.status == "rejected"
        let atHR     = request.status == "approved"
        let hrDone: Bool = {
            switch request.type {
            case "warning":    return approved && request.official_reason != nil
            case "leave":      return approved && (request.leave_signed == true)
            case "permission": return approved && (request.permission_signed == true)
            default:           return atHR
            }
        }()

        switch request.type {
        case "warning":
            return [("أُرسل","paperplane.fill",sent),
                    ("قرار الإدارة","checkmark.shield.fill",approved),
                    ("لدى HR","person.badge.clock.fill",atHR),
                    ("جاهز للتوقيع","signature",hrDone)]
        case "leave":
            return [("أُرسل","paperplane.fill",sent),
                    ("موافقة","checkmark.shield.fill",approved),
                    ("لدى HR","person.badge.clock.fill",atHR),
                    ("وقّع النموذج","signature",hrDone)]
        case "permission":
            return [("أُرسل","paperplane.fill",sent),
                    ("قرار الإدارة","checkmark.shield.fill",approved),
                    ("لدى HR","person.badge.clock.fill",atHR),
                    ("وقّع النموذج","signature",hrDone)]
        default:
            return [("أُرسل","paperplane.fill",sent),
                    ("قرار الإدارة","checkmark.shield.fill",approved),
                    ("لدى HR","person.badge.clock.fill",atHR)]
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // ── رأس البطاقة ──
            HStack {
                Circle().fill(statusColor).frame(width: 9, height: 9)
                Text(request.statusArabic).font(.caption.bold()).foregroundColor(statusColor)
                Spacer()
                Text(request.typeArabic).font(.subheadline.bold()).foregroundColor(Color(hex: "#1a1f3a"))
            }

            if let emp = request.employee?.name {
                Text(emp).font(.caption).foregroundColor(.secondary)
            }
            if let sd = request.start_date {
                Text(sd).font(.caption2).foregroundColor(.secondary)
            }
            if let reason = request.reason, !reason.isEmpty {
                Text(request.type == "warning" ? "وصف المخالفة: \(reason)" : reason)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let comment = request.admin_comment, !comment.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill").font(.caption2).foregroundColor(.orange)
                    Text(comment).font(.caption).foregroundColor(.secondary).italic()
                }
            }

            // ── شريط تتبع المراحل ──
            Divider()
            HStack(spacing: 0) {
                ForEach(Array(trackingSteps.enumerated()), id: \.offset) { i, step in
                    let (label, icon, done) = step
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(done ? statusColor : Color(hex: "#e0e0e0"))
                                .frame(width: 28, height: 28)
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundColor(done ? .white : Color(hex: "#aaaaaa"))
                        }
                        Text(label).font(.system(size: 9)).foregroundColor(done ? statusColor : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    if i < trackingSteps.count - 1 {
                        Rectangle()
                            .fill(trackingSteps[i+1].2 ? statusColor : Color(hex: "#e0e0e0"))
                            .frame(height: 2)
                            .frame(maxWidth: 20)
                    }
                }
            }
            .padding(.vertical, 4)

            // ── أزرار النماذج حسب النوع ──
            if request.status == "approved" {
                // إجازة
                if request.type == "leave" {
                    if request.has_leave_form == true {
                        Button { showLeaveForm = true } label: {
                            HStack {
                                Image(systemName: request.leave_signed == true ? "checkmark.seal.fill" : "signature")
                                Text(request.leave_signed == true ? "عرض نموذج الإجازة" : "وقّع نموذج الإجازة")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background((request.leave_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#2563eb")).opacity(0.12))
                            .foregroundColor(request.leave_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#2563eb"))
                            .cornerRadius(10)
                        }
                        .sheet(isPresented: $showLeaveForm) { LeaveFormView(requestId: request.id) }
                    }
                }
                // سكليف
                else if request.type == "sick" {
                    HStack(spacing: 6) {
                        Image(systemName: "cross.case.fill").foregroundColor(Color(hex: "#e74c3c"))
                        Text("سكليف — تم تسجيل الغياب تلقائياً")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 7).background(Color(hex: "#fdecea")).cornerRadius(8)
                }
                // استئذان
                else if request.type == "permission" {
                    Button { showPermissionForm = true } label: {
                        HStack {
                            Image(systemName: request.permission_signed == true ? "checkmark.seal.fill" : "signature")
                            Text(request.permission_signed == true ? "عرض نموذج الاستئذان" : "وقّع نموذج الاستئذان")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background((request.permission_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#f39c12")).opacity(0.12))
                        .foregroundColor(request.permission_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#f39c12"))
                        .cornerRadius(10)
                    }
                    .sheet(isPresented: $showPermissionForm) { PermissionFormView(requestId: request.id) }
                }
                // إنذار
                else if request.type == "warning" {
                    if request.official_reason != nil {
                        Button { showWarningForm = true } label: {
                            HStack {
                                Image(systemName: request.warning_signed == true ? "checkmark.seal.fill" : "doc.text.fill")
                                Text(request.warning_signed == true ? "عرض نموذج الإنذار" : "فتح نموذج الإنذار")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background((request.warning_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#e74c3c")).opacity(0.12))
                            .foregroundColor(request.warning_signed == true ? Color(hex: "#2ecc71") : Color(hex: "#e74c3c"))
                            .cornerRadius(10)
                        }
                        .sheet(isPresented: $showWarningForm) { WarningFormView(requestId: request.id) }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill").foregroundColor(.orange)
                            Text("في انتظار تحديد السبب الرسمي من HR")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 7).background(Color(hex: "#fff3cd")).cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white).cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - طلب جديد
// ═══════════════════════════════════════════════════
struct NewRequestView: View {
    var preselectedEmployee: Employee?
    var onDone: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionManager

    @State private var employees:      [Employee] = []
    @State private var selectedEmp:    Employee?  = nil
    @State private var reqType         = "leave"
    @State private var reason          = ""
    @State private var startDate       = Date()
    @State private var endDate         = Date()
    @State private var isSaving        = false
    @State private var errorMsg        = ""
    // سكليف — رفع ملف
    @State private var showFilePicker  = false
    @State private var showPhotoPicker = false
    @State private var sickFileData:   Data?   = nil
    @State private var sickFileName:   String? = nil

    let types = [("leave","إجازة"),("sick","سكليف"),("secondment","إعارة"),
                 ("permission","استئذان"),("warning","إنذار"),("late","تأخر")]

    var finalReason: String { reason }

    var body: some View {
        NavigationView {
            Form {
                Section("الموظف") {
                    if let emp = preselectedEmployee {
                        Text(emp.name)
                    } else {
                        Picker("اختر موظفاً", selection: $selectedEmp) {
                            Text("—").tag(Optional<Employee>.none)
                            ForEach(employees) { e in
                                Text(e.name).tag(Optional(e))
                            }
                        }
                    }
                }
                Section("نوع الطلب") {
                    Picker("النوع", selection: $reqType) {
                        ForEach(types, id: \.0) { val, label in Text(label).tag(val) }
                    }
                    .pickerStyle(.menu)
                }
                if ["leave","sick","secondment"].contains(reqType) {
                    Section("التواريخ") {
                        DatePicker("من",  selection: $startDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "ar_SA"))
                        DatePicker("إلى", selection: $endDate,   displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "ar_SA"))
                    }
                }
                if reqType == "sick" {
                    Section("التقرير الطبي") {
                        if let name = sickFileName {
                            HStack {
                                Image(systemName: "doc.fill").foregroundColor(.green)
                                Text(name).font(.caption).lineLimit(1)
                                Spacer()
                                Button { sickFileData = nil; sickFileName = nil } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button { showPhotoPicker = true } label: {
                                    Label("صورة", systemImage: "camera.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                Button { showFilePicker = true } label: {
                                    Label("PDF", systemImage: "doc.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill").foregroundColor(.blue)
                            Text("سيتم تسجيل الغياب تلقائياً بعد الموافقة")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section(reqType == "warning" ? "وصف المخالفة" : "السبب") {
                    TextField(reqType == "warning" ? "اكتب وصف المخالفة بالتفصيل" : "اكتب السبب",
                              text: $reason, axis: .vertical).lineLimit(3...6)
                }
                if reqType == "warning" {
                    Text("ملاحظة: سيقوم الـ HR بتحديد السبب الرسمي بعد الموافقة")
                        .font(.caption2).foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("طلب جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إرسال") { Task { await submit() } }.disabled(isSaving)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: Binding(
                get: { nil as PhotosPickerItem? },
                set: { item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            sickFileData = data
                            sickFileName = "تقرير_طبي.jpg"
                        }
                    }
                }
            ), matching: .images)
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.pdf, .jpeg, .png],
                          allowsMultipleSelection: false) { result in
                if let url = try? result.get().first,
                   url.startAccessingSecurityScopedResource(),
                   let data = try? Data(contentsOf: url) {
                    sickFileData = data
                    sickFileName = url.lastPathComponent
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        .task {
            if preselectedEmployee == nil {
                employees = (try? await NetworkManager.shared.getEmployees()) ?? []
            }
        }
    }

    private func submit() async {
        let emp = preselectedEmployee ?? selectedEmp
        guard let emp = emp else { errorMsg = "اختر موظفاً أولاً"; return }
        isSaving = true; errorMsg = ""
        let requestPayload: [String: Any] = [
            "employee_id": emp.id,
            "type": reqType,
            "reason": reason,
            "start_date": (reqType == "leave" || reqType == "secondment") ? startDate.iso : "",
            "end_date":   (reqType == "leave" || reqType == "secondment") ? endDate.iso   : "",
        ]

        if OfflineQueue.shared.isOnline {
            do {
                let ok = try await NetworkManager.shared.submitRequest(
                    employeeId: emp.id, type: reqType, reason: reason,
                    startDate: ["leave","sick","secondment"].contains(reqType) ? startDate.iso : nil,
                    endDate:   ["leave","sick","secondment"].contains(reqType) ? endDate.iso   : nil,
                    pdfData: reqType == "sick" ? sickFileData : nil,
                    pdfName: reqType == "sick" ? sickFileName : nil)
                if ok { onDone?(); dismiss() }
                else  { errorMsg = "حدث خطأ في الإرسال" }
            } catch {
                OfflineQueue.shared.enqueue(type: .request, endpoint: "/api/requests/new", payload: requestPayload)
                errorMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        } else {
            OfflineQueue.shared.enqueue(type: .request, endpoint: "/api/requests/new", payload: requestPayload)
            errorMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
        isSaving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - الرئيسية (مشرف)
// ═══════════════════════════════════════════════════
struct SupervisorHomeView: View {
    var showQuickActions: Bool = false  // true لـ HSE Supervisor

    @State private var employees:      [Employee] = []
    @State private var weeklyDone:     Set<Int>   = []
    @State private var isLoading       = true
    @State private var pendingRequests = 0
    @State private var showMyRequests  = false
    @State private var showManagement  = false

    private var weekStart: Date { Date().previousSunday }
    private var weekEnd:   Date { Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart }

    private var notEvaluated: [Employee] {
        employees.filter { !weeklyDone.contains($0.id) }
    }

    private var isEndOfWeek: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 4 || weekday == 5
    }

    private var daysLeft: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard weekday == 4 || weekday == 5 else { return 0 }
        return max(0, 5 - weekday)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if employees.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 52)).foregroundColor(.secondary.opacity(0.3))
                        Text("لا يوجد موظفون في قائمتك")
                            .font(.headline).foregroundColor(.secondary)
                        Text("تواصل مع الأدمن لإضافة موظفين")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // P7 — بطاقات الملخص
                            HStack(spacing: 10) {
                                HomeStatCard(
                                    title: "طلباتي المعلقة",
                                    value: "\(pendingRequests)",
                                    icon: "tray.full.fill",
                                    color: Color(hex: "#f39c12")
                                )
                                HomeStatCard(
                                    title: "الموظفون",
                                    value: "\(employees.count)",
                                    icon: "person.2.fill",
                                    color: Color(hex: "#4f8ef7")
                                )
                                HomeStatCard(
                                    title: "مقيَّمون",
                                    value: "\(weeklyDone.count)/\(employees.count)",
                                    icon: "checkmark.seal.fill",
                                    color: Color(hex: "#2ecc71")
                                )
                            }
                            .padding(.horizontal)

                            // ── تنبيه نهاية الأسبوع ──
                            if isEndOfWeek && !notEvaluated.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(daysLeft == 0 ? Color(hex: "#e74c3c") : Color(hex: "#f39c12"))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(daysLeft == 0 ? "اليوم آخر يوم!" : "باقي \(daysLeft) يوم على نهاية الأسبوع")
                                            .font(.subheadline.bold())
                                            .foregroundColor(daysLeft == 0 ? Color(hex: "#e74c3c") : Color(hex: "#f39c12"))
                                        Text("\(notEvaluated.count) موظف لم يُقيَّم بعد")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    (daysLeft == 0 ? Color(hex: "#e74c3c") : Color(hex: "#f39c12"))
                                        .opacity(0.1)
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(daysLeft == 0 ? Color(hex: "#e74c3c") : Color(hex: "#f39c12"),
                                                lineWidth: 1.5)
                                )
                                .padding(.horizontal)
                            }

                            // ── إحصائيات التقييم ──
                            HStack(spacing: 12) {
                                StatMiniCard(
                                    title: "مقيَّمون",
                                    value: "\(weeklyDone.count)",
                                    total: employees.count,
                                    color: Color(hex: "#2ecc71")
                                )
                                StatMiniCard(
                                    title: "لم يُقيَّموا",
                                    value: "\(notEvaluated.count)",
                                    total: employees.count,
                                    color: Color(hex: "#e74c3c")
                                )
                            }
                            .padding(.horizontal)

                            // ── شريط تقدم ──
                            VStack(alignment: .trailing, spacing: 8) {
                                HStack {
                                    Text(String(format: "%.0f%%", employees.isEmpty ? 0 :
                                            Double(weeklyDone.count) / Double(employees.count) * 100))
                                        .font(.caption.bold())
                                        .foregroundColor(Color(hex: "#4f8ef7"))
                                    Spacer()
                                    Text("تغطية الأسبوع: \(weekStart.iso) — \(weekEnd.iso)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .trailing) {
                                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#ecf0f1")).frame(height: 10)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: "#4f8ef7"))
                                            .frame(width: employees.isEmpty ? 0 :
                                                    geo.size.width * CGFloat(weeklyDone.count) / CGFloat(employees.count),
                                                   height: 10)
                                    }
                                }
                                .frame(height: 10)
                            }
                            .padding()
                            .background(Color.white).cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .padding(.horizontal)

                            // ── قائمة غير المقيَّمين ──
                            if !notEvaluated.isEmpty {
                                VStack(alignment: .trailing, spacing: 8) {
                                    Text("لم يُقيَّموا هذا الأسبوع")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal)
                                    ForEach(notEvaluated) { emp in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle().fill(Color(hex: "#e74c3c").opacity(0.1)).frame(width: 38, height: 38)
                                                Text(String(emp.name.prefix(1))).font(.subheadline.bold())
                                                    .foregroundColor(Color(hex: "#e74c3c"))
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(emp.name).font(.subheadline.bold())
                                                Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "clock.badge.exclamationmark")
                                                .foregroundColor(Color(hex: "#f39c12"))
                                        }
                                        .padding(.horizontal, 20).padding(.vertical, 6)
                                    }
                                }
                                .padding(.vertical, 12)
                                .background(Color.white).cornerRadius(14)
                                .shadow(color: .black.opacity(0.05), radius: 5)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("الرئيسية")
            .toolbar {
                // أزرار الوصول السريع لـ HSE Supervisor (طلباتي + إدارة)
                if showQuickActions {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 14) {
                            Button { showMyRequests = true } label: {
                                Image(systemName: "doc.text.fill")
                            }
                            Button { showManagement = true } label: {
                                Image(systemName: "person.badge.gear")
                            }
                        }
                    }
                } else {
                    // إدارة الموظفين فقط للـ supervisor العادي (بدلاً عن tab منفصل)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { showManagement = true } label: {
                            Image(systemName: "person.badge.gear")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(isPresented: $showMyRequests) { MyRequestsView() }
            .sheet(isPresented: $showManagement) {
                NavigationView { EmployeeManagementView() }
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            employees  = try await NetworkManager.shared.getEmployeesCached()
            let reports = try await NetworkManager.shared.getWeeklyReportsCached(
                ws: weekStart.iso, we: weekEnd.iso)
            weeklyDone = Set(reports.map { $0.emp_id })
            let reqs   = (try? await NetworkManager.shared.getMyRequestsCached()) ?? []
            pendingRequests = reqs.filter { $0.status == "pending" }.count
        } catch {
            // أبق البيانات الموجودة عند خطأ مؤقت
        }
        isLoading = false
    }
}

struct HomeStatCard: View {
    let title: String
    let value: String
    let icon:  String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#1a1f3a"))
            Text(title).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white).cornerRadius(14)
        .shadow(color: color.opacity(0.1), radius: 5)
    }
}

struct StatMiniCard: View {
    let title: String
    let value: String
    let total: Int
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(title).font(.caption.bold()).foregroundColor(.secondary)
            Text("من \(total)").font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.white).cornerRadius(14)
        .shadow(color: color.opacity(0.1), radius: 5)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - تعديل التقييم الأسبوعي
// ═══════════════════════════════════════════════════
struct WeeklyEvalEditView: View {
    let report:   EvalReport
    let employee: Employee
    let onSaved:  () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var weekStart: Date
    @State private var t1 = TargetData(); @State private var t2 = TargetData()
    @State private var t3 = TargetData(); @State private var t4 = TargetData()
    @State private var t1_remarks = ""; @State private var t2_remarks = ""
    @State private var t3_remarks = ""; @State private var t4_remarks = ""
    @State private var p_punc = 0; @State private var p_qual = 0
    @State private var p_prod = 0; @State private var p_comm = 0
    @State private var p_prob = 0; @State private var p_comp = 0
    @State private var c_punc = ""; @State private var c_qual = ""
    @State private var c_prod = ""; @State private var c_comm = ""
    @State private var c_prob = ""; @State private var c_comp = ""
    @State private var strengths = ""; @State private var improvements = ""; @State private var training = ""
    @State private var isSaving = false; @State private var resultMsg = ""; @State private var isError = false

    var weekEnd: Date { Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart }

    init(report: EvalReport, employee: Employee, onSaved: @escaping () -> Void) {
        self.report   = report
        self.employee = employee
        self.onSaved  = onSaved
        // تحميل التاريخ من التقرير
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        _weekStart = State(initialValue: df.date(from: report.week_start ?? "") ?? Date().previousSunday)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("أسبوع التقييم") {
                    DatePicker("بداية الأسبوع (أحد)", selection: $weekStart, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ar_SA"))
                    HStack {
                        Spacer()
                        Text("نهاية الأسبوع: \(weekEnd.iso)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("الأهداف (40 درجة)") {
                    TargetRow(label: "الهدف 1", data: $t1)
                    TargetRow(label: "الهدف 2", data: $t2)
                    TargetRow(label: "الهدف 3", data: $t3)
                    TargetRow(label: "الهدف 4", data: $t4)
                }
                Section("الأداء (60 درجة)") {
                    RatingRow(label: "الانضباط",    value: $p_punc)
                    RatingRow(label: "الجودة",      value: $p_qual)
                    RatingRow(label: "الإنتاجية",   value: $p_prod)
                    RatingRow(label: "التواصل",     value: $p_comm)
                    RatingRow(label: "حل المشكلات", value: $p_prob)
                    RatingRow(label: "الامتثال",    value: $p_comp)
                }
                Section("ملاحظات") {
                    TextField("نقاط القوة",      text: $strengths,    axis: .vertical).lineLimit(2...4)
                    TextField("نقاط التحسين",    text: $improvements, axis: .vertical).lineLimit(2...4)
                    TextField("التدريب المطلوب", text: $training,     axis: .vertical).lineLimit(2...4)
                }
                if !resultMsg.isEmpty {
                    Text(resultMsg).foregroundColor(isError ? .red : .green).font(.caption)
                }
            }
            .navigationTitle("تعديل تقييم — \(employee.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { Task { await save() } }.disabled(isSaving)
                }
            }
        }
        .task { loadExisting() }
    }

    private func loadExisting() {
        // تحميل القيم الموجودة — نجلبها من الـ API
        Task {
            if let data = try? await NetworkManager.shared.getWeeklyEvalDetail(evalId: report.id) {
                await MainActor.run {
                    t1 = TargetData(text: data["t1_text"] as? String ?? "", pct: data["t1_percent"] as? Double ?? Double(data["t1_percent"] as? Int ?? 0))
                    t2 = TargetData(text: data["t2_text"] as? String ?? "", pct: data["t2_percent"] as? Double ?? Double(data["t2_percent"] as? Int ?? 0))
                    t3 = TargetData(text: data["t3_text"] as? String ?? "", pct: data["t3_percent"] as? Double ?? Double(data["t3_percent"] as? Int ?? 0))
                    t4 = TargetData(text: data["t4_text"] as? String ?? "", pct: data["t4_percent"] as? Double ?? Double(data["t4_percent"] as? Int ?? 0))
                    t1_remarks = data["t1_remarks"] as? String ?? ""
                    t2_remarks = data["t2_remarks"] as? String ?? ""
                    t3_remarks = data["t3_remarks"] as? String ?? ""
                    t4_remarks = data["t4_remarks"] as? String ?? ""
                    p_punc = data["p_punctuality"]   as? Int ?? 0
                    p_qual = data["p_quality"]        as? Int ?? 0
                    p_prod = data["p_productivity"]   as? Int ?? 0
                    p_comm = data["p_communication"]  as? Int ?? 0
                    p_prob = data["p_problemsolving"] as? Int ?? 0
                    p_comp = data["p_compliance"]     as? Int ?? 0
                    c_punc = data["c_punctuality"]   as? String ?? ""
                    c_qual = data["c_quality"]        as? String ?? ""
                    c_prod = data["c_productivity"]   as? String ?? ""
                    c_comm = data["c_communication"]  as? String ?? ""
                    c_prob = data["c_problemsolving"] as? String ?? ""
                    c_comp = data["c_compliance"]     as? String ?? ""
                    strengths    = data["strengths"]       as? String ?? ""
                    improvements = data["improvements"]    as? String ?? ""
                    training     = data["training_needed"] as? String ?? ""
                }
            }
        }
    }

    private func save() async {
        isSaving = true; resultMsg = ""; isError = false
        let payload: [String: Any] = [
            "week_start": weekStart.iso, "week_end": weekEnd.iso,
            "t1_text": t1.text, "t1_percent": t1.pct, "t1_remarks": t1_remarks,
            "t2_text": t2.text, "t2_percent": t2.pct, "t2_remarks": t2_remarks,
            "t3_text": t3.text, "t3_percent": t3.pct, "t3_remarks": t3_remarks,
            "t4_text": t4.text, "t4_percent": t4.pct, "t4_remarks": t4_remarks,
            "p_punctuality": p_punc, "c_punctuality": c_punc,
            "p_quality": p_qual,     "c_quality": c_qual,
            "p_productivity": p_prod,"c_productivity": c_prod,
            "p_communication": p_comm,"c_communication": c_comm,
            "p_problemsolving": p_prob,"c_problemsolving": c_prob,
            "p_compliance": p_comp,  "c_compliance": c_comp,
            "strengths": strengths, "improvements": improvements, "training_needed": training,
        ]
        if OfflineQueue.shared.isOnline {
            do {
                let (total, band) = try await NetworkManager.shared.editWeeklyEval(evalId: report.id, payload: payload)
                resultMsg = "تم التعديل ✓  المجموع: \(Int(total)) — \(band)"
                onSaved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                // فشل — احفظ offline
                var offlinePayload = payload
                offlinePayload["employee_id"] = report.emp_id
                OfflineQueue.shared.enqueue(
                    type: .weeklyEval,
                    endpoint: "/api/weekly-eval/\(report.id)",
                    method: "PUT",
                    payload: offlinePayload
                )
                resultMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                onSaved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        } else {
            var offlinePayload = payload
            offlinePayload["employee_id"] = report.emp_id
            OfflineQueue.shared.enqueue(
                type: .weeklyEval,
                endpoint: "/api/weekly-eval/\(report.id)",
                method: "PUT",
                payload: offlinePayload
            )
            resultMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
            onSaved()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
        isSaving = false
    }
}

// ═══════════════════════════════════════════════════
// MARK: - شاشة إدارة الموظفين (supervisor)
// ═══════════════════════════════════════════════════

struct EmployeeManagementView: View {
    @State private var data: SupervisorEmployees = SupervisorEmployees(active: [], resigned: [])
    @State private var loading = true
    @State private var confirmEmp: Employee? = nil
    @State private var confirmAction: EmployeeAction = .resign
    @State private var showConfirm = false
    @State private var resultMsg = ""
    @State private var showResult = false
    @State private var search = ""

    enum EmployeeAction { case resign, unassign }

    var filteredActive: [Employee] {
        search.isEmpty ? data.active : data.active.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.emp_number.contains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("بحث...", text: $search)
            }
            .padding(10).background(Color.white).cornerRadius(10)
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else {
                List {
                    // النشطون
                    if !filteredActive.isEmpty {
                        Section {
                            ForEach(filteredActive) { emp in
                                EmpManageRow(emp: emp) { action in
                                    confirmEmp    = emp
                                    confirmAction = action
                                    showConfirm   = true
                                }
                            }
                        } header: {
                            Text("النشطون (\(data.active.count))")
                                .font(.caption).foregroundColor(.green)
                        }
                    }

                    // المستقيلون
                    if !data.resigned.isEmpty {
                        Section {
                            ForEach(data.resigned) { emp in
                                HStack {
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(emp.name).font(.subheadline)
                                        Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                                        if let d = emp.resigned_at {
                                            Text("استقال: \(d)").font(.caption2).foregroundColor(.red)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "person.fill.xmark").foregroundColor(.red)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text("المستقيلون (\(data.resigned.count))")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("إدارة الموظفين")
        .alert("تأكيد", isPresented: $showConfirm) {
            Button("تأكيد", role: .destructive) { Task { await doAction() } }
            Button("إلغاء", role: .cancel) { }
        } message: {
            if let emp = confirmEmp {
                Text(confirmAction == .resign
                     ? "تسجيل استقالة \(emp.name)؟"
                     : "فصل \(emp.name) عن قائمتك؟ سيصبح موظفاً غير معيّن")
            }
        }
        .alert(resultMsg, isPresented: $showResult) {
            Button("حسناً") { }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        do {
            let d = try await NetworkManager.shared.getSupervisorEmployeesFull()
            data = d
        } catch {
            // أبق البيانات الموجودة
        }
        loading = false
    }

    func doAction() async {
        guard let emp = confirmEmp else { return }
        let path = confirmAction == .resign
            ? "/api/employees/\(emp.id)/resign"
            : "/api/employees/\(emp.id)/unassign"
        let req = NetworkManager.shared.makeRequest(path, method: "POST")
        _ = try? await URLSession.shared.data(for: req)
        await load()
        resultMsg  = confirmAction == .resign ? "تم تسجيل الاستقالة" : "تم الفصل"
        showResult = true
    }
}

struct EmpManageRow: View {
    let emp: Employee
    let onAction: (EmployeeManagementView.EmployeeAction) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 3) {
                Text(emp.name).font(.subheadline).fontWeight(.semibold)
                Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                if let d = emp.department, !d.isEmpty {
                    Text(d).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Menu {
                Button(role: .destructive) { onAction(.resign) } label: {
                    Label("تسجيل استقالة", systemImage: "person.fill.xmark")
                }
                Button { onAction(.unassign) } label: {
                    Label("فصل عن قائمتي", systemImage: "person.fill.questionmark")
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}


// ═══════════════════════════════════════════════════
// MARK: - موديلات الإنذار
// ═══════════════════════════════════════════════════

struct WarningReasonItem: Codable, Identifiable {
    let id:         Int
    let text:       String
    let is_default: Bool
}

struct WarningFormData: Codable {
    let request_id:    Int
    let employee_name: String
    let emp_number:    String
    let department:    String?
    let reason:        String?
    let date:          String
    let signed:        Bool
    let signed_at:     String?
    let signer_name:   String?
}

// ═══════════════════════════════════════════════════
// MARK: - Sheet إضافة سبب إنذار جديد
// ═══════════════════════════════════════════════════

struct AddWarningReasonSheet: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var text = ""

    var body: some View {
        NavigationView {
            Form {
                Section("سبب الإنذار الجديد") {
                    TextField("اكتب السبب بالعربية", text: $text, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("إضافة سبب")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - نموذج الإنذار (توقيع الموظف)
// ═══════════════════════════════════════════════════

struct WarningFormView: View {
    let requestId: Int
    @Environment(\.dismiss) var dismiss
    @State private var formData:     WarningFormData? = nil
    @State private var isLoading     = true
    @State private var showSignature = false
    @State private var signedSuccess = false
    @State private var errorMsg      = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f8f9fa").ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if formData == nil {
                    // رسالة خطأ بدل شاشة فارغة
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle).foregroundColor(.orange)
                        Text("تعذّر تحميل نموذج الإنذار")
                            .font(.headline)
                        Text("تحقق من الاتصال وأعد المحاولة")
                            .font(.caption).foregroundColor(.secondary)
                        Button("إعادة المحاولة") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else if let f = formData {
                    ScrollView {
                        VStack(spacing: 0) {

                            // ── رأس النموذج ──
                            VStack(spacing: 8) {
                                // شعار الشركة
                                AsyncImage(url: URL(string: "\(BASE_URL)/logo")) { img in
                                    img.resizable().scaledToFit().frame(height: 60)
                                } placeholder: {
                                    Image(systemName: "building.2.fill")
                                        .font(.largeTitle).foregroundColor(Color(hex: "#7b5ea7"))
                                }

                                Text("نموذج إنذار")
                                    .font(.title2.bold())
                                Text("Warning Notice")
                                    .font(.subheadline).foregroundColor(.secondary)

                                Divider().padding(.top, 4)
                            }
                            .padding()
                            .background(Color.white)

                            // ── بيانات الموظف ──
                            VStack(spacing: 0) {
                                WarningFormRow(label: "اسم الموظف", value: f.employee_name)
                                WarningFormRow(label: "رقم الموظف", value: f.emp_number)
                                if let dept = f.department, !dept.isEmpty {
                                    WarningFormRow(label: "القسم", value: dept)
                                }
                                WarningFormRow(label: "التاريخ", value: f.date)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 6)
                            .padding()

                            // ── سبب الإنذار ──
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("سبب الإنذار").font(.caption.bold()).foregroundColor(.secondary)
                                Text(f.reason ?? "—")
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding()
                                    .background(Color(hex: "#fff3cd"))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)

                            // ── التوقيع ──
                            VStack(spacing: 12) {
                                if f.signed || signedSuccess {
                                    VStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.largeTitle).foregroundColor(Color(hex: "#2ecc71"))
                                        Text("تم التوقيع ✓")
                                            .font(.headline).foregroundColor(Color(hex: "#2ecc71"))
                                        if let at = f.signed_at {
                                            Text(at.prefix(16)).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(hex: "#d5f5e3"))
                                    .cornerRadius(12)
                                } else {
                                    Button {
                                        showSignature = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "signature")
                                            Text("توقيع الموظف")
                                                .fontWeight(.bold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(hex: "#e74c3c"))
                                        .foregroundColor(.white)
                                        .cornerRadius(14)
                                    }
                                }

                                if !errorMsg.isEmpty {
                                    Text(errorMsg).font(.caption).foregroundColor(.red)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("نموذج الإنذار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .sheet(isPresented: $showSignature) {
                SignaturePadView { signatureBase64 in
                    Task { await submitSignature(signatureBase64) }
                }
            }
        }
        .task { await load() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func load() async {
        isLoading = true
        if let (data, _) = try? await URLSession.shared.data(
            for: NetworkManager.shared.makeRequest("/api/warning/form/\(requestId)")) {
            formData = try? JSONDecoder().decode(WarningFormData.self, from: data)
        }
        isLoading = false
    }

    func submitSignature(_ base64: String) async {
        var req = NetworkManager.shared.makeRequest("/api/warning/sign/\(requestId)", method: "POST")
        let body: [String: Any] = ["signature": base64, "employee_name": formData?.employee_name ?? ""]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            signedSuccess = true
            await load()
        } else {
            errorMsg = "حدث خطأ في حفظ التوقيع"
        }
    }
}

struct WarningFormRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(value).font(.subheadline)
            Spacer()
            Text(label).font(.caption.bold()).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        Divider().padding(.horizontal)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - نموذج الإجازة
// ═══════════════════════════════════════════════════
struct LeaveFormView: View {
    let requestId: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionManager
    @State private var info: NetworkManager.LeaveFormInfo? = nil
    @State private var isLoading    = true
    @State private var showSign     = false
    @State private var signedOK     = false
    @State private var errorMsg     = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f8f9fa").ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if let f = info {
                    ScrollView {
                        VStack(spacing: 0) {
                            // رأس
                            VStack(spacing: 6) {
                                AsyncImage(url: URL(string: "\(BASE_URL)/logo")) { img in
                                    img.resizable().scaledToFit().frame(height: 56)
                                } placeholder: {
                                    Image(systemName: "building.2.fill")
                                        .font(.largeTitle).foregroundColor(Color(hex: "#2563eb"))
                                }
                                Text("نموذج طلب إجازة").font(.title2.bold())
                                Text("LEAVE REQUEST FORM").font(.caption).foregroundColor(.secondary)
                                Divider().padding(.top, 4)
                            }
                            .padding().background(Color.white)

                            // بيانات
                            VStack(spacing: 0) {
                                WarningFormRow(label: "اسم الموظف",    value: f.employee_name)
                                WarningFormRow(label: "رقم الموظف",    value: f.emp_number)
                                if let dept = f.department, !dept.isEmpty {
                                    WarningFormRow(label: "القسم",     value: dept)
                                }
                                if let site = f.site, !site.isEmpty {
                                    WarningFormRow(label: "الموقع",    value: site)
                                }
                                if let sup = f.supervisor, !sup.isEmpty {
                                    WarningFormRow(label: "المشرف",    value: sup)
                                }
                                WarningFormRow(label: "من",            value: f.start_date)
                                WarningFormRow(label: "إلى",           value: f.end_date)
                                WarningFormRow(label: "عدد الأيام",    value: f.days)
                                if let reason = f.reason, !reason.isEmpty {
                                    WarningFormRow(label: "السبب",     value: reason)
                                }
                                if let ap = f.approved_at, !ap.isEmpty {
                                    WarningFormRow(label: "تاريخ الموافقة", value: ap)
                                }
                            }
                            .background(Color.white).cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 6).padding()

                            // التوقيع
                            VStack(spacing: 12) {
                                if f.signed || signedOK {
                                    VStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.largeTitle).foregroundColor(Color(hex: "#2ecc71"))
                                        Text("تم التوقيع ✓").font(.headline)
                                            .foregroundColor(Color(hex: "#2ecc71"))
                                        if let at = f.signed_at {
                                            Text(at.prefix(16)).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding().frame(maxWidth: .infinity)
                                    .background(Color(hex: "#d5f5e3")).cornerRadius(12)

                                    // زر تحميل PDF
                                    if let url = f.pdf_url {
                                        Link(destination: URL(string: "\(BASE_URL)\(url)?token=\(SessionManager.shared.token ?? "")")!) {
                                            HStack {
                                                Image(systemName: "arrow.down.doc.fill")
                                                Text("تحميل PDF")
                                            }
                                            .frame(maxWidth: .infinity).padding()
                                            .background(Color(hex: "#2563eb"))
                                            .foregroundColor(.white).cornerRadius(12)
                                        }
                                    }
                                } else {
                                    Button { showSign = true } label: {
                                        HStack {
                                            Image(systemName: "signature")
                                            Text("توقيع الموظف").fontWeight(.bold)
                                        }
                                        .frame(maxWidth: .infinity).padding()
                                        .background(Color(hex: "#2563eb"))
                                        .foregroundColor(.white).cornerRadius(14)
                                    }
                                }
                                if !errorMsg.isEmpty {
                                    Text(errorMsg).font(.caption).foregroundColor(.red)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("نموذج الإجازة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("إغلاق") { dismiss() } } }
            .sheet(isPresented: $showSign) {
                SignaturePadView { sig64 in
                    showSign = false
                    Task {
                        do {
                            let name = session.currentUser?.name ?? ""
                            try await NetworkManager.shared.leaveSign(requestId: requestId, signature: sig64, employeeName: name)
                            signedOK = true
                            await load()
                        } catch {
                            errorMsg = "فشل حفظ التوقيع"
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .task { await load() }
    }
    private func load() async {
        isLoading = true
        info = try? await NetworkManager.shared.leaveFormInfo(requestId: requestId)
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
// MARK: - نموذج الاستئذان
// ═══════════════════════════════════════════════════
struct PermissionFormView: View {
    let requestId: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionManager
    @State private var info: NetworkManager.PermissionFormInfo? = nil
    @State private var isLoading = true
    @State private var showSign  = false
    @State private var signedOK  = false
    @State private var errorMsg  = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f8f9fa").ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if let f = info {
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 6) {
                                AsyncImage(url: URL(string: "\(BASE_URL)/logo")) { img in
                                    img.resizable().scaledToFit().frame(height: 56)
                                } placeholder: {
                                    Image(systemName: "building.2.fill")
                                        .font(.largeTitle).foregroundColor(Color(hex: "#2563eb"))
                                }
                                Text("نموذج استئذان").font(.title2.bold())
                                Text("PERMISSION FORM").font(.caption).foregroundColor(.secondary)
                                Divider().padding(.top, 4)
                            }
                            .padding().background(Color.white)

                            VStack(spacing: 0) {
                                WarningFormRow(label: "اسم الموظف", value: f.employee_name)
                                WarningFormRow(label: "رقم الموظف", value: f.emp_number)
                                if let dept = f.department, !dept.isEmpty {
                                    WarningFormRow(label: "القسم", value: dept)
                                }
                                if let sup = f.supervisor, !sup.isEmpty {
                                    WarningFormRow(label: "المشرف", value: sup)
                                }
                                WarningFormRow(label: "التاريخ", value: f.date)
                                if let reason = f.reason, !reason.isEmpty {
                                    WarningFormRow(label: "السبب", value: reason)
                                }
                            }
                            .background(Color.white).cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 6).padding()

                            VStack(spacing: 12) {
                                if f.signed || signedOK {
                                    VStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.largeTitle).foregroundColor(Color(hex: "#2ecc71"))
                                        Text("تم التوقيع ✓").font(.headline)
                                            .foregroundColor(Color(hex: "#2ecc71"))
                                        if let at = f.signed_at { Text(at.prefix(16)).font(.caption).foregroundColor(.secondary) }
                                    }
                                    .padding().frame(maxWidth: .infinity)
                                    .background(Color(hex: "#d5f5e3")).cornerRadius(12)

                                    if let url = f.pdf_url {
                                        Link(destination: URL(string: "\(BASE_URL)\(url)?token=\(SessionManager.shared.token ?? "")")!) {
                                            HStack {
                                                Image(systemName: "arrow.down.doc.fill")
                                                Text("تحميل PDF")
                                            }
                                            .frame(maxWidth: .infinity).padding()
                                            .background(Color(hex: "#2563eb"))
                                            .foregroundColor(.white).cornerRadius(12)
                                        }
                                    }
                                } else {
                                    Button { showSign = true } label: {
                                        HStack {
                                            Image(systemName: "signature")
                                            Text("توقيع الموظف").fontWeight(.bold)
                                        }
                                        .frame(maxWidth: .infinity).padding()
                                        .background(Color(hex: "#f39c12"))
                                        .foregroundColor(.white).cornerRadius(14)
                                    }
                                }
                                if !errorMsg.isEmpty {
                                    Text(errorMsg).font(.caption).foregroundColor(.red)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("نموذج الاستئذان")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("إغلاق") { dismiss() } } }
            .sheet(isPresented: $showSign) {
                SignaturePadView { sig64 in
                    showSign = false
                    Task {
                        do {
                            let name = session.currentUser?.name ?? ""
                            try await NetworkManager.shared.permissionSign(requestId: requestId, signature: sig64, employeeName: name)
                            signedOK = true
                            await load()
                        } catch {
                            errorMsg = "فشل حفظ التوقيع"
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .task { await load() }
    }
    private func load() async {
        isLoading = true
        info = try? await NetworkManager.shared.permissionFormInfo(requestId: requestId)
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
// MARK: - لوحة التوقيع بالإصبع
// ═══════════════════════════════════════════════════

import UIKit

struct SignaturePadView: UIViewControllerRepresentable {
    let onSave: (String) -> Void

    func makeUIViewController(context: Context) -> SignaturePadVC {
        let vc = SignaturePadVC()
        vc.onSave = onSave
        return vc
    }
    func updateUIViewController(_ vc: SignaturePadVC, context: Context) {}
}

class SignaturePadVC: UIViewController {
    var onSave: ((String) -> Void)?
    private var lines: [[CGPoint]] = []
    private var currentLine: [CGPoint] = []
    private let canvas = UIView()
    private let imgView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "توقيع الموظف"
        // منع إغلاق الـ sheet بالسحب أثناء التوقيع
        isModalInPresentation = true

        // Canvas
        canvas.backgroundColor = UIColor(hex: "#f8f9fa")
        canvas.layer.cornerRadius = 12
        canvas.layer.borderWidth = 1.5
        canvas.layer.borderColor = UIColor(hex: "#dee2e6").cgColor
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        imgView.contentMode = .scaleAspectFit
        imgView.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(imgView)

        // منع الـ scroll عند الرسم على الـ canvas
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        canvas.addGestureRecognizer(pan)

        // Label
        let lbl = UILabel()
        lbl.text = "وقّع هنا بإصبعك"
        lbl.textColor = .systemGray3
        lbl.font = .systemFont(ofSize: 16)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(lbl)

        // Buttons
        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("مسح", for: .normal)
        clearBtn.addTarget(self, action: #selector(clear), for: .touchUpInside)

        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("حفظ التوقيع", for: .normal)
        saveBtn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        saveBtn.backgroundColor = UIColor(hex: "#2ecc71")
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 10
        saveBtn.addTarget(self, action: #selector(save), for: .touchUpInside)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("إلغاء", for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [cancelBtn, clearBtn, saveBtn])
        btnStack.axis = .horizontal
        btnStack.distribution = .fillEqually
        btnStack.spacing = 10
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(btnStack)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            canvas.bottomAnchor.constraint(equalTo: btnStack.topAnchor, constant: -20),
            imgView.topAnchor.constraint(equalTo: canvas.topAnchor),
            imgView.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            imgView.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            lbl.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
            btnStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            btnStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            btnStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            btnStack.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // تم حذف touchesBegan/Moved/Ended — handlePan يتولى الرسم بالكامل لتجنب التعارض

    private func drawAll() {
        let size = canvas.bounds.size
        guard size.width > 0 else { return }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for line in lines + [currentLine] {
            guard line.count > 1 else { continue }
            ctx.move(to: line[0])
            for pt in line.dropFirst() { ctx.addLine(to: pt) }
            ctx.strokePath()
        }
        imgView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    @objc func clear() { lines = []; currentLine = []; imgView.image = nil }

    @objc func save() {
        let size = canvas.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        imgView.image?.draw(in: CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let data = img?.pngData() {
            let b64 = data.base64EncodedString()
            onSave?(b64)
            dismiss(animated: true)
        }
    }

    @objc func cancel() { dismiss(animated: true) }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: canvas)
        switch g.state {
        case .began:
            currentLine = [pt]
        case .changed:
            currentLine.append(pt)
            drawAll()
        case .ended, .cancelled:
            lines.append(currentLine)
            currentLine = []
        default: break
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: CGFloat((rgb >> 16) & 0xFF)/255,
                  green: CGFloat((rgb >> 8)  & 0xFF)/255,
                  blue:  CGFloat( rgb        & 0xFF)/255,
                  alpha: 1)
    }
}
