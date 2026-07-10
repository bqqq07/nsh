import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - لوحة الأدمن
// ═══════════════════════════════════════════════════
struct AdminDashboardView: View {
    @State private var kpi:            KPIData? = nil
    @State private var isLoading       = true
    @State private var weekStart       = Date().previousSunday
    @State private var goRequests      = false
    @State private var goEmployees     = false
    @State private var goReports       = false

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── فلتر الأسبوع ──
                    HStack(spacing: 12) {
                        Button {
                            weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                            Task { await load() }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline).foregroundColor(Color(hex: "#7b5ea7"))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                            Text("\(weekStart.iso) — \(weekEnd.iso)").font(.subheadline.bold())
                        }
                        Spacer()
                        Button {
                            let next = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                            if next <= Date().previousSunday { weekStart = next; Task { await load() } }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline).foregroundColor(Color(hex: "#7b5ea7"))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 4)

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if let kpi = kpi {
                        ScrollView {
                            VStack(spacing: 14) {

                                // روابط NavigationLink مخفية
                                NavigationLink(destination: AdminRequestsView(), isActive: $goRequests) { EmptyView() }
                                NavigationLink(destination: EmployeesListView(), isActive: $goEmployees) { EmptyView() }
                                NavigationLink(destination: AdminReportsView(),  isActive: $goReports)  { EmptyView() }

                                // ── صف 1: الموظفون + التقييمات ──
                                HStack(spacing: 12) {
                                    KPICard(title: "الموظفون", value: "\(kpi.total_employees)",
                                            subtitle: nil, icon: "person.2.fill", color: Color(hex: "#4f8ef7"),
                                            onTap: { goEmployees = true })
                                    KPICard(title: "تقييمات الأسبوع", value: "\(kpi.evals_this_week)",
                                            subtitle: "الأسبوع الماضي: \(kpi.evals_last_week)",
                                            icon: "chart.bar.fill", color: Color(hex: "#7b5ea7"),
                                            onTap: { goReports = true })
                                }

                                // ── صف 2: الطلبات + HR ──
                                HStack(spacing: 12) {
                                    KPICard(title: "طلبات معلقة", value: "\(kpi.pending_requests)",
                                            subtitle: nil, icon: "tray.full.fill", color: Color(hex: "#f39c12"),
                                            onTap: { goRequests = true })
                                    KPICard(title: "مهام HR معلقة", value: "\(kpi.hr_pending_tasks)",
                                            subtitle: nil, icon: "person.badge.clock.fill", color: Color(hex: "#e74c3c"))
                                }

                                // ── صف 3: تغطية الموظفين ──
                                HStack(spacing: 12) {
                                    KPICard(title: "تغطية التقييمات",
                                            value: String(format: "%.1f%%", kpi.emp_coverage),
                                            subtitle: "موظفين مقيّمين / إجمالي",
                                            icon: "checkmark.seal.fill", color: Color(hex: "#2ecc71"),
                                            onTap: { goReports = true })
                                    KPICard(title: "معدل الحضور",
                                            value: String(format: "%.1f%%", kpi.att_rate),
                                            subtitle: "\(kpi.present_count) حضور مسجل",
                                            icon: "calendar.badge.checkmark", color: Color(hex: "#1abc9c"))
                                }

                                // ── صف 4: الإجازات + أيام الإجازة ──
                                HStack(spacing: 12) {
                                    KPICard(title: "معدل الإجازات",
                                            value: String(format: "%.1f%%", kpi.leave_rate),
                                            subtitle: nil,
                                            icon: "bed.double.fill", color: Color(hex: "#9b59b6"))
                                    KPICard(title: "أيام الإجازة",
                                            value: "\(kpi.leave_count)",
                                            subtitle: "هذا الأسبوع",
                                            icon: "calendar.badge.minus", color: Color(hex: "#8e44ad"))
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("الرئيسية")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { kpi = try await NetworkManager.shared.getKPICached(ws: weekStart.iso, we: weekEnd.iso) }
        catch { kpi = nil }
        isLoading = false
    }
}

struct KPICard: View {
    let title:    String
    let value:    String
    let subtitle: String?
    let icon:     String
    let color:    Color
    var onTap:    (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.title3).foregroundColor(color)
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "chevron.left")
                            .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                    }
                }
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1a1f3a"))
                Text(title).font(.caption.bold()).foregroundColor(.secondary)
                Text(subtitle ?? " ").font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: color.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - طلبات الأدمن
// ═══════════════════════════════════════════════════
struct AdminRequestsView: View {
    @State private var requests:    [RequestItem] = []
    @State private var statusFilter = "pending"
    @State private var isLoading    = true
    @State private var selected:    RequestItem? = nil
    @State private var empSummary:  (Employee, EmployeeSummary)? = nil
    @State private var errorMsg     = ""
    @State private var searchText   = ""

    let filters = [("pending","معلقة"),("approved","موافق عليها"),("rejected","مرفوضة"),("all","الكل")]

    var filtered: [RequestItem] {
        guard !searchText.isEmpty else { return requests }
        return requests.filter {
            ($0.employee?.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.employee?.emp_number ?? "").contains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.0) { val, label in
                                Button {
                                    statusFilter = val
                                    Task { await load() }
                                } label: {
                                    Text(label)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(statusFilter == val ? Color(hex: "#7b5ea7") : Color.white)
                                        .foregroundColor(statusFilter == val ? .white : .secondary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color.white)

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
                            Text("لا توجد طلبات").foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        List(filtered) { r in
                            AdminReqCard(request: r,
                                onTap: { selected = r },
                                onEmpTap: { Task { await loadEmpSummary(r) } }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .environment(\.layoutDirection, .rightToLeft)
                        .refreshable { await load() }
                    }
                }
            }
            .navigationTitle("الطلبات")
            .searchable(text: $searchText, prompt: "بحث باسم أو رقم الموظف")
            .alert("خطأ", isPresented: .constant(!errorMsg.isEmpty), actions: {
                Button("حسناً") { errorMsg = "" }
            }, message: { Text(errorMsg) })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
                Task { await load() }
            }
            .sheet(item: $selected) { req in
                DecisionSheet(request: req) {
                    statusFilter = "approved"
                    Task { await load() }
                }
            }
            .sheet(isPresented: Binding(get: { empSummary != nil }, set: { if !$0 { empSummary = nil } })) {
                if let (emp, summary) = empSummary {
                    EmpSummarySheet(employee: emp, summary: summary)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMsg  = ""
        do {
            requests = try await NetworkManager.shared.getAdminRequests(status: statusFilter)
        } catch {
            errorMsg = "تعذّر تحميل الطلبات"
        }
        isLoading = false
    }

    private func loadEmpSummary(_ req: RequestItem) async {
        guard let empId = req.employee?.id,
              let empName = req.employee?.name,
              let empNum  = req.employee?.emp_number else { return }
        let emp = Employee(id: empId, name: empName, emp_number: empNum,
                           department: req.employee?.department, site: nil,
                           status: "active", resigned_at: nil)
        do {
            let result = try await NetworkManager.shared.getEmployeeSummary(empId: empId)
            await MainActor.run { empSummary = (emp, result) }
        } catch { }
    }
}

struct AdminReqCard: View {
    let request: RequestItem
    let onTap: () -> Void
    let onEmpTap: () -> Void

    var statusColor: Color {
        switch request.status {
        case "approved": return Color(hex: "#2ecc71")
        case "rejected": return Color(hex: "#e74c3c")
        default:         return Color(hex: "#f39c12")
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Capsule().fill(statusColor).frame(width: 50, height: 6)
                Spacer()
                Text(request.typeArabic).font(.subheadline.bold()).foregroundColor(Color(hex: "#1a1f3a"))
            }

            // اسم الموظف — قابل للضغط
            if let empName = request.employee?.name {
                Button(action: onEmpTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption).foregroundColor(Color(hex: "#4f8ef7"))
                        Text(empName)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#4f8ef7"))
                            .underline()
                        if let num = request.employee?.emp_number {
                            Text("· \(num)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(request.statusArabic).font(.caption).foregroundColor(statusColor)
                Spacer()
                if let sd = request.start_date { Text(sd).font(.caption2).foregroundColor(.secondary) }
            }
            if let sup = request.supervisor?.name {
                Text("المشرف: \(sup)").font(.caption2).foregroundColor(.secondary)
            }

            // زر فتح تفاصيل الطلب
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text("قرار")
                    Image(systemName: "chevron.left").font(.caption2)
                }
                .font(.caption.bold())
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color(hex: "#7b5ea7").opacity(0.1))
                .foregroundColor(Color(hex: "#7b5ea7"))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
}

// ── ملخص الموظف (Sheet) ─────────────────────────
struct EmpSummarySheet: View {
    let employee: Employee
    let summary: EmployeeSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // بطاقة الموظف
                        VStack(spacing: 8) {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#4f8ef7"), Color(hex: "#7b5ea7")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 70, height: 70)
                                .overlay(Text(String(employee.name.prefix(1))).font(.title.bold()).foregroundColor(.white))
                            Text(employee.name).font(.title3.bold())
                            Text(employee.emp_number).font(.caption).foregroundColor(.secondary)
                            if let dept = employee.department, !dept.isEmpty {
                                Text(dept).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white).cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6)
                        .padding(.horizontal)

                        // إحصائيات الحضور
                        HStack(spacing: 12) {
                            SummaryStatCard(title: "أيام الحضور", value: "\(summary.present)", color: Color(hex: "#2ecc71"))
                            SummaryStatCard(title: "غياب الشهر", value: "\(summary.absent)",  color: Color(hex: "#e74c3c"))
                            SummaryStatCard(title: "غياب كلي", value: "\(summary.absent_all ?? summary.absent)", color: Color(hex: "#4f8ef7"))
                        }
                        .padding(.horizontal)

                        // متوسط التقييم (كل الفترة)
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text("متوسط التقييم (كل الفترة)").font(.caption).foregroundColor(.secondary)
                                if let trend = summary.trend {
                                    if trend == "up" {
                                        Image(systemName: "arrow.up.right").foregroundColor(.green)
                                    } else if trend == "down" {
                                        Image(systemName: "arrow.down.right").foregroundColor(.red)
                                    }
                                }
                            }
                            if let avg = summary.avg_score_all {
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(scoreColor(avg))
                                Text(scoreBand(avg)).font(.subheadline.bold()).foregroundColor(scoreColor(avg))
                                Text("من \(summary.eval_count_all ?? 0) تقييم").font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("لا توجد تقييمات").foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white).cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6)
                        .padding(.horizontal)

                        // متوسط آخر 8 أسابيع (مرجعي)
                        VStack(spacing: 4) {
                            Text("متوسط آخر 8 أسابيع").font(.caption2).foregroundColor(.secondary)
                            if let avg8 = summary.avg_score_8w {
                                Text(String(format: "%.1f", avg8)).font(.headline).foregroundColor(scoreColor(avg8))
                            } else {
                                Text("—").font(.headline).foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("ملخص الموظف")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }

    private func scoreColor(_ v: Double) -> Color {
        if v >= 90 { return Color(hex: "#2ecc71") }
        if v >= 80 { return Color(hex: "#3498db") }
        if v >= 70 { return Color(hex: "#f39c12") }
        return Color(hex: "#e74c3c")
    }

    private func scoreBand(_ v: Double) -> String {
        if v >= 90 { return "ممتاز" }
        if v >= 80 { return "جيد" }
        if v >= 70 { return "مقبول" }
        return "يحتاج تحسين"
    }
}

struct SummaryStatCard: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.white).cornerRadius(14)
        .shadow(color: color.opacity(0.1), radius: 5)
    }
}

// ── ورقة القرار ──────────────────────────────────
struct DecisionSheet: View {
    let request: RequestItem
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var comment       = ""
    @State private var isSaving      = false
    @State private var errorMsg      = ""
    @State private var showRejectConfirm = false
    @State private var showAttachment    = false
    @State private var empSummary: (Employee, EmployeeSummary)? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section("تفاصيل الطلب") {
                        LabeledRow(label: "النوع",   value: request.typeArabic)
                        Button {
                            Task { await loadEmpSummary() }
                        } label: {
                            LabeledRow(label: "الموظف", value: (request.employee?.name ?? "—") + "  ›")
                        }
                        .buttonStyle(.plain)
                        .disabled(request.employee?.id == nil)
                        LabeledRow(label: "المشرف",  value: request.supervisor?.name ?? "—")
                        if let sd = request.start_date { LabeledRow(label: "من",     value: sd) }
                        if let ed = request.end_date   { LabeledRow(label: "إلى",    value: ed) }
                        if let r = request.reason, !r.isEmpty { LabeledRow(label: "السبب", value: r) }
                    }

                    // P4 — عرض مرفق السكليف
                    if request.type == "sick", request.has_attachment == true {
                        Section("التقرير الطبي") {
                            Button {
                                showAttachment = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill").foregroundColor(Color(hex: "#2563eb"))
                                    Text("عرض التقرير الطبي المرفق")
                                        .foregroundColor(Color(hex: "#2563eb"))
                                    Spacer()
                                    Image(systemName: "chevron.left").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section("تعليق الأدمن (اختياري)") {
                        TextField("تعليق", text: $comment, axis: .vertical).lineLimit(2...5)
                    }
                    if !errorMsg.isEmpty {
                        Text(errorMsg).foregroundColor(.red).font(.caption)
                    }
                }

                // P3 — أزرار القرار: رفض أصغر وموافقة أكبر
                HStack(spacing: 12) {
                    Button { showRejectConfirm = true } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("رفض")
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(Color(hex: "#e74c3c").opacity(0.12))
                        .foregroundColor(Color(hex: "#e74c3c"))
                        .cornerRadius(14)
                    }
                    Button { Task { await decide("approved") } } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("موافقة").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(hex: "#2ecc71")).foregroundColor(.white).cornerRadius(14)
                    }
                }
                .padding().disabled(isSaving)
            }
            .navigationTitle("قرار الطلب")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("إلغاء") { dismiss() } }
            }
            // P3 — تأكيد الرفض
            .confirmationDialog("هل تريد رفض هذا الطلب؟", isPresented: $showRejectConfirm, titleVisibility: .visible) {
                Button("تأكيد الرفض", role: .destructive) { Task { await decide("rejected") } }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("لا يمكن التراجع عن هذا القرار")
            }
            .sheet(isPresented: $showAttachment) {
                let token = UserDefaults.standard.string(forKey: "auth_token") ?? ""
                SafariView(url: URL(string: BASE_URL + "/api/requests/\(request.id)/attachment?token=\(token)")!)
            }
            .sheet(isPresented: Binding(get: { empSummary != nil }, set: { if !$0 { empSummary = nil } })) {
                if let (emp, summary) = empSummary {
                    EmpSummarySheet(employee: emp, summary: summary)
                }
            }
        }
    }

    private func loadEmpSummary() async {
        guard let empId   = request.employee?.id,
              let empName = request.employee?.name,
              let empNum  = request.employee?.emp_number else { return }
        let emp = Employee(id: empId, name: empName, emp_number: empNum,
                           department: request.employee?.department, site: nil,
                           status: "active", resigned_at: nil)
        do {
            let result = try await NetworkManager.shared.getEmployeeSummary(empId: empId)
            await MainActor.run { empSummary = (emp, result) }
        } catch { }
    }

    private func decide(_ decision: String) async {
        isSaving = true
        do {
            let ok = try await NetworkManager.shared.decideRequest(reqId: request.id, decision: decision, comment: comment)
            if ok {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(decision == "approved" ? .success : .error)
                onDone()
                dismiss()
            } else {
                errorMsg = "حدث خطأ"
            }
        } catch {
            errorMsg = "تعذّر الاتصال بالسيرفر"
        }
        isSaving = false
    }
}

struct LabeledRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(value).foregroundColor(.primary)
            Spacer()
            Text(label).foregroundColor(.secondary)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - تقارير الأدمن
// ═══════════════════════════════════════════════════
struct AdminReportsView: View {
    @State private var weekly:      [EvalReport] = []
    @State private var daily:       [EvalReport] = []
    @State private var isLoading    = true
    @State private var tab          = 0
    @State private var weekStart    = Date().previousSunday
    @State private var selectedDate = Date()

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("أسبوعي").tag(0)
                        Text("يومي").tag(1)
                    }
                    .pickerStyle(.segmented).padding(.horizontal).padding(.top, 8)
                    .onChange(of: tab) { _ in Task { await load() } }

                    if tab == 0 {
                        HStack(spacing: 12) {
                            Button {
                                weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                                Task { await load() }
                            } label: { Image(systemName: "chevron.right").font(.headline).foregroundColor(Color(hex: "#4f8ef7")) }
                            Spacer()
                            VStack(spacing: 2) {
                                Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                                Text("\(weekStart.iso) — \(weekEnd.iso)").font(.subheadline.bold())
                            }
                            Spacer()
                            Button {
                                let next = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                                if next <= Date().previousSunday { weekStart = next; Task { await load() } }
                            } label: { Image(systemName: "chevron.left").font(.headline).foregroundColor(Color(hex: "#4f8ef7")) }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.white).shadow(color: .black.opacity(0.04), radius: 4)
                    } else {
                        HStack {
                            Spacer()
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ar_SA"))
                                .onChange(of: selectedDate) { _ in Task { await load() } }
                            Spacer()
                        }
                        .padding(.vertical, 8).background(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    }

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else {
                        let list = tab == 0 ? weekly : daily
                        if list.isEmpty {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4)).padding(.bottom, 8)
                            Text("لا توجد تقارير لهذه الفترة").foregroundColor(.secondary)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(list) { r in AdminEvalRow(report: r) }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("التقارير")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            if tab == 0 {
                weekly = try await NetworkManager.shared.getWeeklyReports(ws: weekStart.iso, we: weekEnd.iso)
            } else {
                daily = try await NetworkManager.shared.getDailyReports(date: selectedDate.iso)
            }
        } catch {
            weekly = []; daily = []
        }
        isLoading = false
    }
}

struct AdminEvalRow: View {
    let report: EvalReport
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
            VStack(alignment: .trailing, spacing: 4) {
                Text(report.emp_name).font(.subheadline.bold())
                Text(report.emp_number).font(.caption).foregroundColor(.secondary)
                Text(report.eval_date ?? "\(report.week_start ?? "") — \(report.week_end ?? "")")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(Int(report.total ?? 0))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
//  MARK: - HR Inbox
// ═══════════════════════════════════════════════════
struct HRInboxView: View {
    @State private var tasks:      [HRTask] = []
    @State private var isLoading   = true
    @State private var tab         = "pending"  // pending | all
    @State private var typeFilter  = "all"       // all | leave | sick | permission | warning
    @State private var errorMsg    = ""

    let typeFilters: [(String, String)] = [
        ("all", "الكل"), ("leave", "إجازة"), ("sick", "سكليف"),
        ("permission", "استئذان"), ("warning", "إنذار")
    ]

    var filtered: [HRTask] {
        var list = tab == "pending" ? tasks.filter { $0.status == "pending" } : tasks
        if typeFilter != "all" { list = list.filter { $0.type == typeFilter } }
        return list
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── تبويبان الحالة ──
                    HStack(spacing: 0) {
                        ForEach([("pending","قيد الانتظار"),("all","جميع الطلبات")], id: \.0) { key, label in
                            Button {
                                tab = key
                            } label: {
                                VStack(spacing: 4) {
                                    Text(label).font(.subheadline.bold())
                                        .foregroundColor(tab == key ? Color(hex: "#4f8ef7") : .secondary)
                                    Rectangle()
                                        .fill(tab == key ? Color(hex: "#4f8ef7") : Color.clear)
                                        .frame(height: 2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    // P5 — فلتر النوع
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(typeFilters, id: \.0) { key, label in
                                Button { typeFilter = key } label: {
                                    Text(label).font(.caption.bold())
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(typeFilter == key ? Color(hex: "#2ecc71") : Color.white)
                                        .foregroundColor(typeFilter == key ? .white : .secondary)
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.04), radius: 3)
                                }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: tab == "pending" ? "tray" : "archivebox")
                                .font(.system(size: 50)).foregroundColor(.gray.opacity(0.3))
                            Text(tab == "pending" ? "لا توجد مهام معلقة" : "لا توجد طلبات")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        List(filtered) { task in
                            HRTaskCard(task: task,
                                onApply: { Task { await apply(task) } },
                                onRefresh: { Task { await load() } })
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .environment(\.layoutDirection, .rightToLeft)
                        .refreshable { await load() }
                    }
                }
            }
            .navigationTitle("مهام HR")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .task { await load() }
        .alert("خطأ", isPresented: .constant(!errorMsg.isEmpty), actions: {
            Button("حسناً") { errorMsg = "" }
        }, message: { Text(errorMsg) })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = tasks.isEmpty
        errorMsg  = ""
        do {
            tasks = try await NetworkManager.shared.getHRTasks()
        } catch {
            errorMsg = "تعذّر تحميل المهام"
        }
        isLoading = false
    }

    private func apply(_ task: HRTask) async {
        do {
            _ = try await NetworkManager.shared.applyHRTask(taskId: task.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { }
        await load()
    }
}

struct HRTaskCard: View {
    let task: HRTask
    let onApply: () -> Void
    let onRefresh: () -> Void
    @State private var showPDF = false
    @State private var showSetReason = false
    @State private var showAttachment = false
    @State private var attachmentViewed = false
    var isPending: Bool { task.status == "pending" }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Capsule()
                    .fill(isPending ? Color(hex: "#f39c12") : Color(hex: "#2ecc71"))
                    .frame(width: 60, height: 5)
                Spacer()
                Text(task.typeArabic)
                    .font(.subheadline.bold()).foregroundColor(Color(hex: "#1a1f3a"))
            }
            if let empName = task.employee?.name {
                Text(empName).font(.subheadline).foregroundColor(.secondary)
            }
            // وصف المشرف للمخالفة
            if task.type == "warning" {
                if let desc = task.supervisor_description, !desc.isEmpty {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("وصف المشرف:").font(.caption2).foregroundColor(.secondary)
                        Text(desc).font(.caption).foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(8).background(Color(hex: "#f8f9fa")).cornerRadius(8)
                    }
                }
                if let official = task.official_reason, !official.isEmpty {
                    Text("السبب الرسمي: \(official)")
                        .font(.caption.bold()).foregroundColor(Color(hex: "#e74c3c"))
                }
            }
            if let sd = task.request?.start_date, let ed = task.request?.end_date {
                Text("\(sd) — \(ed)").font(.caption).foregroundColor(.secondary)
            }

            // مرفق السكليف — يجب فتحه قبل السماح بـ"تم التنفيذ"
            if task.type == "sick", task.has_attachment == true, let attUrl = task.attachment_url {
                Button {
                    attachmentViewed = true
                    showAttachment = true
                } label: {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("عرض التقرير الطبي المرفق").font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Color(hex: "#2563eb").opacity(0.1))
                    .foregroundColor(Color(hex: "#2563eb")).cornerRadius(10)
                }
                .sheet(isPresented: $showAttachment) {
                    let token = UserDefaults.standard.string(forKey: "auth_token") ?? ""
                    SafariView(url: URL(string: BASE_URL + attUrl + "?token=\(token)")!)
                }
            }

            // أزرار الإنذار
            if task.type == "warning" {
                if let pdfUrl = task.warning_pdf_url {
                    // PDF جاهز
                    Button { showPDF = true } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("تحميل نموذج الإنذار").font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(hex: "#e74c3c").opacity(0.1))
                        .foregroundColor(Color(hex: "#e74c3c")).cornerRadius(10)
                    }
                    .sheet(isPresented: $showPDF) {
                        let token = UserDefaults.standard.string(forKey: "auth_token") ?? ""
                        SafariView(url: URL(string: BASE_URL + pdfUrl + "?token=\(token)")!)
                    }
                } else if task.reason_set == true {
                    // السبب محدد — في انتظار توقيع المشرف
                    HStack {
                        Image(systemName: "clock.fill").foregroundColor(.orange)
                        Text("في انتظار توقيع الموظف").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6).background(Color(hex: "#fff3cd")).cornerRadius(8)
                } else {
                    // HR لم يحدد السبب بعد
                    Button { showSetReason = true } label: {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("تحديد السبب الرسمي وإرساله للمشرف").font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(hex: "#7b5ea7").opacity(0.1))
                        .foregroundColor(Color(hex: "#7b5ea7")).cornerRadius(10)
                    }
                    .sheet(isPresented: $showSetReason) {
                        HRSetWarningReasonSheet(task: task) { onRefresh() }
                    }
                }
            }

            // زر "تم التنفيذ" — للإنذار: يظهر فقط بعد وصول PDF (أي بعد توقيع الموظف)
            //                    للسكليف: يظهر فقط بعد فتح المرفق الطبي (إن وُجد)
            //                    لباقي الأنواع: يظهر مباشرة
            let sickNeedsReview = task.type == "sick" && task.has_attachment == true && !attachmentViewed
            let canApply = (task.type != "warning" || task.warning_pdf_url != nil) && !sickNeedsReview
            HStack {
                if !canApply {
                    // إنذار لم يكتمل بعد — لا يظهر زر تم التنفيذ
                    EmptyView()
                } else if isPending {
                    Button(action: onApply) {
                        Text("تم التنفيذ ✓").font(.caption.bold())
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color(hex: "#2ecc71")).foregroundColor(.white).cornerRadius(10)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#2ecc71"))
                        Text("تم التنفيذ").font(.caption).foregroundColor(Color(hex: "#2ecc71"))
                    }
                }
                Spacer()
                Text(task.statusArabic).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
}

import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// ═══════════════════════════════════════════════════
//  MARK: - الملف الشخصي
// ═══════════════════════════════════════════════════
struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showConfirm = false

    var roleArabic: String {
        switch session.currentUser?.role {
        case "admin":           return "مدير"
        case "hr":              return "موارد بشرية"
        case "site_supervisor": return "مشرف موقع"
        default:                return "مشرف"
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#4f8ef7"), Color(hex: "#7b5ea7")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                            Text(String(session.currentUser?.name.prefix(1) ?? "؟"))
                                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                        }
                        Text(session.currentUser?.name ?? "").font(.title2.bold())
                        Text(roleArabic)
                            .font(.caption).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color(hex: "#4f8ef7")).cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 8)
                    .padding(.horizontal)

                    Button { showConfirm = true } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("تسجيل الخروج").font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(hex: "#e74c3c").opacity(0.1))
                        .foregroundColor(Color(hex: "#e74c3c"))
                        .cornerRadius(14).padding(.horizontal)
                    }
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationTitle("حسابي")
            .confirmationDialog("هل تريد تسجيل الخروج؟", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("تسجيل الخروج", role: .destructive) {
                    Task {
                        try? await NetworkManager.shared.logout()
                        CacheManager.shared.clearAll()   // تنظيف الـ cache عند الخروج
                        await MainActor.run { session.logout() }
                    }
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - إدارة المستخدمين (أدمن)
// ═══════════════════════════════════════════════════
struct AdminUsersView: View {
    @State private var users:       [UserItem] = []
    @State private var isLoading    = true
    @State private var showHidden   = false
    @State private var showAddUser  = false
    @State private var errorMsg     = ""

    var filtered: [UserItem] {
        showHidden ? users : users.filter { !($0.is_hidden ?? false) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            showHidden.toggle()
                        } label: {
                            Label(showHidden ? "إخفاء المخفيين" : "عرض المخفيين",
                                  systemImage: showHidden ? "eye.slash" : "eye")
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.white)
                                .foregroundColor(Color(hex: "#7b5ea7"))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.05), radius: 4)
                        }
                        .padding(.trailing).padding(.top, 8)
                    }

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if filtered.isEmpty {
                        Spacer()
                        Text("لا يوجد مستخدمون").foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List(filtered) { u in
                            UserRow(user: u,
                                onToggleHide: { Task { await toggleHide(u) } },
                                onResign:     { Task { await resign(u) } }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .opacity((u.is_hidden ?? false) ? 0.45 : 1.0)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("إدارة المستخدمين")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddUser = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(isPresented: $showAddUser) {
                AdminAddUserView { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { users = try await NetworkManager.shared.getAdminUsers() }
        catch { users = [] }
        isLoading = false
    }

    private func toggleHide(_ u: UserItem) async {
        do {
            _ = try await NetworkManager.shared.hideUser(userId: u.id)
        } catch { }
        await load()
    }

    private func resign(_ u: UserItem) async {
        var req = NetworkManager.shared.makeRequest("/api/admin/users/\(u.id)/resign", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = json["employees_unassigned"] as? Int {
                // إشعار الـ site supervisors بالموظفين المعلقين
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshRequests"), object: nil)
                _ = count  // عدد الموظفين المحوّلين
            }
        } catch { }
        await load()
    }
}

struct UserRow: View {
    let user: UserItem
    let onToggleHide: () -> Void
    var onResign: (() -> Void)? = nil
    @State private var showConfirm  = false
    @State private var showResign   = false

    var roleColor: Color {
        switch user.role {
        case "admin":           return Color(hex: "#e74c3c")
        case "site_supervisor": return Color(hex: "#9b59b6")
        case "hr":              return Color(hex: "#1abc9c")
        default:                return Color(hex: "#4f8ef7")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if user.is_hidden ?? false {
                        Image(systemName: "eye.slash").font(.caption2).foregroundColor(.secondary)
                    }
                    Text(user.name).font(.subheadline.bold())
                }
                Text(user.code).font(.caption).foregroundColor(.secondary)
                Text(user.role)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(roleColor.opacity(0.12))
                    .foregroundColor(roleColor)
                    .cornerRadius(8)
            }
            Spacer()

            if user.role != "admin" {
                HStack(spacing: 8) {
                    // زر إخفاء/إظهار
                    Button { showConfirm = true } label: {
                        Image(systemName: (user.is_hidden ?? false) ? "eye" : "eye.slash")
                            .font(.title3)
                            .foregroundColor((user.is_hidden ?? false) ? Color(hex: "#2ecc71") : .secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.06), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        (user.is_hidden ?? false) ? "إظهار \(user.name)؟" : "إخفاء \(user.name) من القائمة؟",
                        isPresented: $showConfirm, titleVisibility: .visible
                    ) {
                        Button((user.is_hidden ?? false) ? "إظهار" : "إخفاء",
                               role: (user.is_hidden ?? false) ? .none : .destructive) { onToggleHide() }
                        Button("إلغاء", role: .cancel) {}
                    }

                    // زر الاستقالة (للمشرفين والـ HR فقط)
                    if user.role == "supervisor" || user.role == "hr" || user.role == "site_supervisor" {
                        Button { showResign = true } label: {
                            Image(systemName: "person.fill.xmark")
                                .font(.title3)
                                .foregroundColor(Color(hex: "#e74c3c"))
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.06), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog(
                            "تسجيل استقالة \(user.name)؟",
                            isPresented: $showResign, titleVisibility: .visible
                        ) {
                            Button("تسجيل الاستقالة", role: .destructive) { onResign?() }
                            Button("إلغاء", role: .cancel) {}
                        } message: {
                            Text("سيتم تعطيل حسابه وتحويل موظفيه إلى قائمة المعلقين")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5)
        .padding(.horizontal)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - مقارنة المشرفين
// ═══════════════════════════════════════════════════
struct SupervisorsRankingView: View {
    @State private var ranking:   SupervisorRanking? = nil
    @State private var isLoading  = true
    @State private var weekStart  = Date().previousSunday

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {

                    // فلتر الأسبوع
                    HStack(spacing: 12) {
                        Button {
                            weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                            Task { await load() }
                        } label: {
                            Image(systemName: "chevron.right").font(.headline)
                                .foregroundColor(Color(hex: "#7b5ea7"))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                            Text("\(weekStart.iso) — \(weekEnd.iso)").font(.subheadline.bold())
                        }
                        Spacer()
                        Button {
                            let next = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                            if next <= Date().previousSunday { weekStart = next; Task { await load() } }
                        } label: {
                            Image(systemName: "chevron.left").font(.headline)
                                .foregroundColor(Color(hex: "#7b5ea7"))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 4)

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if let rows = ranking?.rows, !rows.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                    NavigationLink(destination: SupervisorDetailView(
                                        supId: row.id, supName: row.name)) {
                                        SupervisorRankCard(row: row, rank: index + 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    } else {
                        Spacer()
                        Text("لا توجد بيانات لهذا الأسبوع").foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("ترتيب المشرفين")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { ranking = try await NetworkManager.shared.getSupervisorsRanking(ws: weekStart.iso, we: weekEnd.iso) }
        catch { ranking = nil }
        isLoading = false
    }
}

struct SupervisorRankCard: View {
    let row:  SupervisorRankRow
    let rank: Int

    private var coverageColor: Color {
        if row.coverage >= 90 { return Color(hex: "#2ecc71") }
        if row.coverage >= 70 { return Color(hex: "#f39c12") }
        return Color(hex: "#e74c3c")
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#f1c40f")
        case 2: return Color(hex: "#95a5a6")
        case 3: return Color(hex: "#e67e22")
        default: return Color(hex: "#dfe6e9")
        }
    }

    private var trendIcon: String {
        switch row.trend {
        case "up":   return "arrow.up.circle.fill"
        case "down": return "arrow.down.circle.fill"
        default:     return "minus.circle.fill"
        }
    }

    private var trendColor: Color {
        switch row.trend {
        case "up":   return Color(hex: "#2ecc71")
        case "down": return Color(hex: "#e74c3c")
        default:     return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {

            // رقم الترتيب
            ZStack {
                Circle().fill(rankColor).frame(width: 36, height: 36)
                Text("\(rank)").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }

            // بيانات المشرف
            VStack(alignment: .trailing, spacing: 4) {
                Text(row.name).font(.subheadline.bold())
                Text("كود: \(row.code)").font(.caption).foregroundColor(.secondary)

                // شريط التغطية
                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#ecf0f1"))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(coverageColor)
                            .frame(width: geo.size.width * CGFloat(min(row.coverage, 100)) / 100,
                                   height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // أرقام
            VStack(alignment: .center, spacing: 4) {
                Text(String(format: "%.0f%%", row.coverage))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(coverageColor)
                Text("\(row.done)/\(row.target)")
                    .font(.caption).foregroundColor(.secondary)

                HStack(spacing: 3) {
                    Image(systemName: trendIcon).font(.caption2).foregroundColor(trendColor)
                    Text(row.delta == 0 ? "—" : "\(row.delta > 0 ? "+" : "")\(row.delta)")
                        .font(.caption2).foregroundColor(trendColor)
                }

                if let avg = row.avg_score {
                    Text(String(format: "%.1f", avg))
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "#7b5ea7"))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - تقرير مشرف محدد
// ═══════════════════════════════════════════════════
struct SupervisorDetailView: View {
    let supId:   Int
    let supName: String

    @State private var report:    SupervisorReport? = nil
    @State private var isLoading  = true
    @State private var weekStart  = Date().previousSunday

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
    }

    var body: some View {
        ZStack {
            Color(hex: "#f0f4ff").ignoresSafeArea()
            VStack(spacing: 0) {

                // فلتر الأسبوع
                HStack(spacing: 12) {
                    Button {
                        weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                        Task { await load() }
                    } label: {
                        Image(systemName: "chevron.right").font(.headline)
                            .foregroundColor(Color(hex: "#7b5ea7"))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                        Text("\(weekStart.iso) — \(weekEnd.iso)").font(.subheadline.bold())
                    }
                    Spacer()
                    Button {
                        let next = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                        if next <= Date().previousSunday { weekStart = next; Task { await load() } }
                    } label: {
                        Image(systemName: "chevron.left").font(.headline)
                            .foregroundColor(Color(hex: "#7b5ea7"))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 4)

                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if let r = report {
                    ScrollView {
                        VStack(spacing: 14) {

                            // ── إحصائيات سريعة ──
                            HStack(spacing: 10) {
                                SupStatBox(title: "الموظفون",   value: "\(r.total_emp)",  color: Color(hex: "#4f8ef7"))
                                SupStatBox(title: "مقيَّمون",   value: "\(r.evaluated)",  color: Color(hex: "#2ecc71"))
                                SupStatBox(title: "متوسط الدرجة",
                                           value: r.avg_score != nil ? String(format: "%.1f", r.avg_score!) : "—",
                                           color: Color(hex: "#7b5ea7"))
                                SupStatBox(title: "أيام حضور",  value: "\(r.present_cnt)", color: Color(hex: "#1abc9c"))
                            }
                            .padding(.horizontal)

                            // ── شريط تغطية ──
                            VStack(alignment: .trailing, spacing: 6) {
                                HStack {
                                    Text(r.total_emp > 0 ?
                                         String(format: "%.0f%%", Double(r.evaluated) / Double(r.total_emp) * 100) : "0%")
                                        .font(.caption.bold()).foregroundColor(Color(hex: "#4f8ef7"))
                                    Spacer()
                                    Text("التغطية").font(.caption).foregroundColor(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .trailing) {
                                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: "#ecf0f1")).frame(height: 8)
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color(hex: "#4f8ef7"))
                                            .frame(width: r.total_emp > 0 ?
                                                   geo.size.width * CGFloat(r.evaluated) / CGFloat(r.total_emp) : 0,
                                                   height: 8)
                                    }
                                }.frame(height: 8)
                            }
                            .padding()
                            .background(Color.white).cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 5)
                            .padding(.horizontal)

                            // ── قائمة الموظفين ──
                            VStack(spacing: 8) {
                                ForEach(r.employees) { emp in
                                    NavigationLink(destination: EmployeeReportsView(
                                        employee: Employee(
                                            id: emp.emp_id,
                                            name: emp.name,
                                            emp_number: emp.emp_number,
                                            department: emp.department,
                                            site: nil,
                                            status: "active",
                                            resigned_at: nil
                                        )
                                    )) {
                                        HStack(spacing: 10) {
                                            Image(systemName: emp.evaluated ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                                                .foregroundColor(emp.evaluated ? Color(hex: "#2ecc71") : Color(hex: "#e74c3c"))
                                                .font(.title3)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(emp.name).font(.subheadline.bold())
                                                Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                                                if let d = emp.department, !d.isEmpty {
                                                    Text(d).font(.caption2).foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()

                                            if emp.evaluated, let total = emp.total {
                                                VStack(spacing: 2) {
                                                    Text(String(format: "%.0f", total))
                                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                                        .foregroundColor(bandColor(emp.band))
                                                    Text(emp.band ?? "—")
                                                        .font(.caption2.bold())
                                                        .foregroundColor(bandColor(emp.band))
                                                }
                                            } else {
                                                Text("لم يُقيَّم")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                    }
                                    .foregroundColor(.primary)
                                    Divider().padding(.horizontal)
                                }
                            }
                            .background(Color.white).cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 5)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .navigationTitle(supName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { report = try await NetworkManager.shared.getSupervisorReport(supId: supId, ws: weekStart.iso, we: weekEnd.iso) }
        catch { report = nil }
        isLoading = false
    }

    private func bandColor(_ band: String?) -> Color {
        switch band {
        case "Excellent":    return Color(hex: "#2ecc71")
        case "Good":         return Color(hex: "#3498db")
        case "Satisfactory": return Color(hex: "#f39c12")
        default:             return Color(hex: "#e74c3c")
        }
    }
}

struct SupStatBox: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white).cornerRadius(12)
        .shadow(color: color.opacity(0.1), radius: 4)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - إشعارات الأدمن
// ═══════════════════════════════════════════════════

struct NotifyUser: Codable, Identifiable {
    let id:   Int
    let name: String
    let role: String
    let code: String

    var roleArabic: String {
        role == "site_supervisor" ? "سايت سوبرفايزر" : "مشرف"
    }
}

struct AdminNotifyView: View {
    @State private var title      = ""
    @State private var body_text  = ""
    @State private var target     = "all"
    @State private var users:     [NotifyUser] = []
    @State private var selected:  Set<Int> = []
    @State private var sending    = false
    @State private var resultMsg  = ""
    @State private var showResult = false
    @State private var loadingUsers = false

    let targets = [
        ("all",               "All (Supervisors + Site + HSE)"),
        ("supervisors",       "Supervisors only"),
        ("site_supervisors",  "Site Supervisors only"),
        ("safety_officers",   "Safety Officers only"),
        ("safety_supervisors","Safety Supervisors only"),
        ("custom",            "Custom selection"),
    ]

    var body: some View {
        ZStack {
            Color(hex: "#f0f4ff").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // ── العنوان ──
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("عنوان الإشعار").font(.caption).foregroundColor(.secondary)
                        TextField("مثال: تنبيه مهم", text: $title)
                            .multilineTextAlignment(.trailing)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // ── نص الرسالة ──
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("نص الرسالة").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $body_text)
                            .multilineTextAlignment(.trailing)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // ── الفئة المستهدفة ──
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("المستلمون").font(.caption).foregroundColor(.secondary)
                        VStack(spacing: 0) {
                            ForEach(targets, id: \.0) { key, label in
                                Button {
                                    target = key
                                    if key == "custom" { Task { await loadUsers() } }
                                } label: {
                                    HStack {
                                        Image(systemName: target == key ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(target == key ? Color(hex: "#7b5ea7") : .secondary)
                                        Spacer()
                                        Text(label).foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                }
                                if key != "custom" { Divider().padding(.horizontal) }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // ── قائمة المخصصين ──
                    if target == "custom" {
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack {
                                if loadingUsers { ProgressView().scaleEffect(0.8) }
                                Spacer()
                                Text("اختر المستلمين (\(selected.count) محدد)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(users) { u in
                                    Button {
                                        if selected.contains(u.id) { selected.remove(u.id) }
                                        else { selected.insert(u.id) }
                                    } label: {
                                        HStack {
                                            Image(systemName: selected.contains(u.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selected.contains(u.id) ? Color(hex: "#7b5ea7") : .secondary)
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(u.name).font(.subheadline).foregroundColor(.primary)
                                                Text(u.roleArabic).font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                    }
                                    Divider().padding(.horizontal)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }

                    // ── زر الإرسال ──
                    Button { Task { await send() } } label: {
                        HStack {
                            if sending {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("إرسال الإشعار").fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSend ? Color(hex: "#7b5ea7") : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!canSend || sending)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("إرسال إشعار")
        .environment(\.layoutDirection, .rightToLeft)
        .alert(resultMsg, isPresented: $showResult) {
            Button("حسناً") { }
        }
    }

    var canSend: Bool {
        !title.isEmpty && !body_text.isEmpty &&
        (target != "custom" || !selected.isEmpty)
    }

    func loadUsers() async {
        loadingUsers = true
        do {
            let (data, _) = try await URLSession.shared.data(
                for: NetworkManager.shared.makeRequest("/api/admin/notify/users"))
            users = (try? JSONDecoder().decode([NotifyUser].self, from: data)) ?? []
        } catch {
            users = []
        }
        loadingUsers = false
    }

    func send() async {
        sending = true
        var payload: [String: Any] = ["title": title, "body": body_text, "target": target]
        if target == "custom" { payload["user_ids"] = Array(selected) }
        var req = NetworkManager.shared.makeRequest("/api/admin/notify", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg  = json["message"] as? String {
                resultMsg = msg
            } else {
                resultMsg = "حدث خطأ في الإرسال"
            }
        } catch {
            resultMsg = "تعذّر الاتصال بالسيرفر"
        }
        sending    = false
        showResult = true
        if resultMsg.contains("تم") { title = ""; body_text = ""; selected = [] }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - شاشة اختيار السبب الرسمي (HR)
// ═══════════════════════════════════════════════════

struct HRSetWarningReasonSheet: View {
    let task: HRTask
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var reasons:          [WarningReasonItem] = []
    @State private var selectedReasonId: Int? = nil
    @State private var customReason      = ""
    @State private var showAddReason     = false
    @State private var isSaving          = false
    @State private var errorMsg          = ""

    var finalReason: String {
        if let id = selectedReasonId,
           let r = reasons.first(where: { $0.id == id }) { return r.text }
        return customReason
    }

    var body: some View {
        NavigationView {
            Form {
                // ── وصف المشرف ──
                if let desc = task.supervisor_description, !desc.isEmpty {
                    Section("وصف المشرف للمخالفة") {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.vertical, 4)
                    }
                }

                // ── اختيار السبب الرسمي ──
                Section("السبب الرسمي للإنذار") {
                    ForEach(reasons) { r in
                        Button {
                            selectedReasonId = (selectedReasonId == r.id) ? nil : r.id
                            customReason = ""
                        } label: {
                            HStack {
                                Image(systemName: selectedReasonId == r.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedReasonId == r.id ? Color(hex: "#e74c3c") : .secondary)
                                Spacer()
                                Text(r.text).foregroundColor(.primary)
                            }
                        }
                    }
                    Button {
                        showAddReason = true
                    } label: {
                        Label("إضافة سبب جديد", systemImage: "plus.circle")
                            .foregroundColor(Color(hex: "#7b5ea7"))
                    }
                }

                if selectedReasonId == nil {
                    Section("أو اكتب سبباً مخصصاً") {
                        TextField("اكتب السبب", text: $customReason, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("تحديد سبب الإنذار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إرسال للمشرف") { Task { await save() } }
                        .disabled(finalReason.isEmpty || isSaving)
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showAddReason) {
                AddWarningReasonSheet { text in
                    Task { await addAndSelectReason(text) }
                }
            }
        }
        .task { await loadReasons() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func loadReasons() async {
        do {
            let (data, _) = try await URLSession.shared.data(
                for: NetworkManager.shared.makeRequest("/api/warning/reasons"))
            reasons = (try? JSONDecoder().decode([WarningReasonItem].self, from: data)) ?? []
        } catch {
            reasons = []
        }
    }

    func addAndSelectReason(_ text: String) async {
        var req = NetworkManager.shared.makeRequest("/api/warning/reasons", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try? await URLSession.shared.data(for: req)  // best-effort
        await loadReasons()
        if let newR = reasons.first(where: { $0.text == text }) {
            selectedReasonId = newR.id
        }
    }

    func save() async {
        isSaving = true
        var req = NetworkManager.shared.makeRequest("/api/hr/tasks/\(task.id)/set-reason", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["official_reason": finalReason])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200 {
                onSave()
                dismiss()
            } else {
                errorMsg = "حدث خطأ في الإرسال"
            }
        } catch {
            errorMsg = "تعذّر الاتصال بالسيرفر"
        }
        isSaving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Admin: Add User
// ═══════════════════════════════════════════════════

struct AdminAddUserView: View {
    let onAdded: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var code    = ""
    @State private var name    = ""
    @State private var role    = "supervisor"
    @State private var saving  = false
    @State private var errorMsg = ""

    private let roles: [(id: String, label: String)] = [
        ("supervisor", "مشرف"),
        ("hr",         "HR"),
        ("admin",      "أدمن"),
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات المستخدم الجديد")) {
                    HStack {
                        Text("الكود *").foregroundColor(.secondary)
                        Spacer()
                        TextField("مثال: NSH001", text: $code)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("الاسم (إنجليزي)").foregroundColor(.secondary)
                        Spacer()
                        TextField("Ahmed Ali", text: $name)
                            .autocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("الدور", selection: $role) {
                        ForEach(roles, id: \.id) { r in
                            Text(r.label).tag(r.id)
                        }
                    }
                }

                if !errorMsg.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(errorMsg).font(.subheadline).foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: { Task { await save() } }) {
                        HStack {
                            Spacer()
                            if saving {
                                ProgressView()
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("إضافة المستخدم").bold()
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(
                        code.trimmingCharacters(in: .whitespaces).isEmpty || saving
                            ? Color.gray : Color(hex: "#7b5ea7")
                    )
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
            .navigationTitle("مستخدم جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func save() async {
        let c = code.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        saving = true; errorMsg = ""
        do {
            try await NetworkManager.shared.adminAddUser(code: c, name: name, role: role)
            onAdded()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        saving = false
    }
}

