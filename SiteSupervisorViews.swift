import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - Models
// ═══════════════════════════════════════════════════

struct SiteSupRow: Codable, Identifiable {
    let id:              Int
    let name:            String
    let code:            String
    let emp_count:       Int
    let evaluated:       Bool
    let evaluated_count: Int
    let progress:        Int
    let week_start:      String
    let week_end:        String
}

struct SiteEmpRow: Codable, Identifiable {
    let id:           Int
    let name:         String
    let emp_number:   String
    let department:   String
    let evaluated:    Bool
    let eval_id:      Int?
    let total_score:  Double?
    let overall_band: String?
    let week_start:   String
    let week_end:     String
}

struct SiteReportsSummary: Codable {
    let week_start:          String
    let week_end:            String
    let total:               Int
    let evaluated_count:     Int
    let not_evaluated_count: Int
    let not_evaluated:       [SiteReportEmpRow]
    let evaluated:           [SiteReportEmpRow]
}

struct SiteReportEmpRow: Codable, Identifiable {
    let id:           Int
    let name:         String
    let emp_number:   String
    let department:   String
    let supervisor:   String
    let evaluated:    Bool
    let total_score:  Double?
    let overall_band: String?
}

struct SiteAttSupRow: Codable, Identifiable {
    let id:         Int
    let name:       String
    let code:       String
    let emp_count:  Int
    let recorded:   Int
    let did_attend: Bool
    let date:       String
}

struct SiteAttDetail: Codable {
    let date:    String
    let summary: SiteAttSummary
    let rows:    [SiteAttEmpRow]
}

struct SiteAttSummary: Codable {
    let present: Int
    let absent:  Int
    let leave:   Int
}

struct SiteAttEmpRow: Codable, Identifiable {
    let id:         Int
    let emp_id:     Int
    let emp_name:   String
    let emp_number: String
    let status:     String
    let remarks:    String

    enum CodingKeys: String, CodingKey {
        case id = "att_id"
        case emp_id, emp_name, emp_number, status, remarks
    }
}

struct SiteRequestRow: Codable, Identifiable {
    let id:              Int
    let type:            String
    let status:          String
    let supervisor_id:   Int
    let supervisor_name: String
    let created_at:      String
    let notes:           String

    var typeArabic: String {
        switch type {
        case "leave":      return "إجازة"
        case "secondment": return "إعارة"
        case "permission": return "استئذان"
        case "warning":    return "تحذير"
        case "late":       return "تأخر"
        default:           return type
        }
    }
    var statusArabic: String {
        switch status {
        case "approved": return "موافق عليها"
        case "rejected": return "مرفوضة"
        default:         return "معلقة"
        }
    }
    var statusColor: Color {
        switch status {
        case "approved": return .green
        case "rejected": return .red
        default:         return .orange
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Network Extensions
// ═══════════════════════════════════════════════════


// ═══════════════════════════════════════════════════
//  MARK: - Tab View
// ═══════════════════════════════════════════════════

struct SiteSupervisorTabView: View {
    var body: some View {
        TabView {
            NavigationView { SiteDashboardView() }
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }

            NavigationView { SiteSupervisorsListView() }
                .tabItem { Label("مشرفوني", systemImage: "person.3.fill") }

            NavigationView { SiteReportsView() }
                .tabItem { Label("التقارير", systemImage: "chart.bar.fill") }

            NavigationView { SiteAttendanceView() }
                .tabItem { Label("الحضور", systemImage: "calendar.badge.checkmark") }

            NavigationView { SiteRequestsView() }
                .tabItem { Label("الطلبات", systemImage: "tray.full.fill") }

            NavigationView { SiteUnassignedView() }
                .tabItem { Label("معلقون", systemImage: "person.fill.questionmark") }

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#6C63FF"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Dashboard
// ═══════════════════════════════════════════════════

struct SiteDashboardView: View {
    @State private var supervisors: [SiteSupRow] = []
    @State private var summary: SiteReportsSummary?
    @State private var loading = true
    @State private var weekOffset = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("لوحة الإشراف")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top)

                HStack {
                    Button { weekOffset += 1; Task { await load() } } label: {
                        Image(systemName: "chevron.left").padding(8)
                    }
                    Spacer()
                    if let s = summary {
                        VStack(spacing: 2) {
                            Text("\(s.week_start) — \(s.week_end)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button { weekOffset -= 1; Task { await load() } } label: {
                        Image(systemName: "chevron.right").padding(8)
                    }
                    .disabled(weekOffset == 0)
                }
                .padding(.horizontal)

                if loading {
                    ProgressView().padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        SiteKPICard(title: "المشرفون",     value: "\(supervisors.count)",                          icon: "person.3.fill",       color: .purple)
                        SiteKPICard(title: "قيّموا موظفيهم", value: "\(supervisors.filter { $0.evaluated }.count)", icon: "checkmark.seal.fill", color: .green)
                        if let s = summary {
                            SiteKPICard(title: "تم تقييمهم", value: "\(s.evaluated_count)",     icon: "person.fill.checkmark", color: .blue)
                            SiteKPICard(title: "متبقي",       value: "\(s.not_evaluated_count)", icon: "clock.fill",            color: .orange)
                        }
                    }
                    .padding(.horizontal)

                    if let s = summary, !s.not_evaluated.isEmpty {
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack {
                                Spacer()
                                Text("لم يُقيَّموا بعد (\(s.not_evaluated_count))")
                                    .font(.headline).foregroundColor(.orange)
                            }
                            .padding(.horizontal)

                            ForEach(s.not_evaluated) { emp in
                                HStack {
                                    Text(emp.supervisor)
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(emp.name).font(.subheadline).fontWeight(.semibold)
                                        Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.04), radius: 4)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("الرئيسية")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        let (ws, we) = weekDates(offset: weekOffset)
        do {
            async let sups = NetworkManager.shared.getSiteSupervisors(ws: ws, we: we)
            async let sum  = NetworkManager.shared.getSiteReportsSummary(ws: ws, we: we)
            supervisors = try await sups
            summary     = try await sum
        } catch {
            supervisors = []
        }
        loading = false
    }

    func weekDates(offset: Int) -> (String, String) {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysSinceSun = (weekday - 1 + 7) % 7
        let sun = cal.date(byAdding: .day, value: -daysSinceSun + (offset * 7), to: today)!
        let thu = cal.date(byAdding: .day, value: 4, to: sun)!
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: sun), fmt.string(from: thu))
    }
}

struct SiteKPICard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack { Spacer(); Image(systemName: icon).foregroundColor(color) }
            Text(value).font(.system(size: 26, weight: .bold))
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisors List
// ═══════════════════════════════════════════════════

struct SiteSupervisorsListView: View {
    @State private var supervisors: [SiteSupRow] = []
    @State private var loading = true
    @State private var search = ""

    var filtered: [SiteSupRow] {
        search.isEmpty ? supervisors : supervisors.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.code.contains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("بحث...", text: $search)
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else {
                List(filtered) { sup in
                    NavigationLink(destination: SiteSupEmployeesView(supervisor: sup)) {
                        SiteSupRowView(sup: sup)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .background(Color(hex: "#F0F2FF"))
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("مشرفوني")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysSinceSun = (weekday - 1 + 7) % 7
        let sun = cal.date(byAdding: .day, value: -daysSinceSun, to: today)!
        let thu = cal.date(byAdding: .day, value: 4, to: sun)!
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        do {
            supervisors = try await NetworkManager.shared.getSiteSupervisors(
                ws: fmt.string(from: sun), we: fmt.string(from: thu))
        } catch {
            supervisors = []
        }
        loading = false
    }
}

struct SiteSupRowView: View {
    let sup: SiteSupRow
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(sup.evaluated ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: sup.evaluated ? "checkmark.seal.fill" : "clock.fill")
                        .foregroundColor(sup.evaluated ? .green : .orange)
                )
            VStack(alignment: .trailing, spacing: 4) {
                Text(sup.name).font(.subheadline).fontWeight(.semibold)
                Text("كود: \(sup.code)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text("\(sup.emp_count)").font(.title3).fontWeight(.bold).foregroundColor(Color(hex: "#6C63FF"))
                Text("موظف").font(.caption2).foregroundColor(.secondary)
            }
            VStack(alignment: .center, spacing: 2) {
                Text("\(sup.progress)%")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(sup.progress == 100 ? .green : sup.progress > 0 ? .orange : .secondary)
                Text("إنجاز").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4)
        .padding(.horizontal, 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor Employees
// ═══════════════════════════════════════════════════

struct SiteSupEmployeesView: View {
    let supervisor: SiteSupRow
    @State private var employees: [SiteEmpRow] = []
    @State private var loading = true
    @State private var search = ""

    var filtered: [SiteEmpRow] {
        search.isEmpty ? employees : employees.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.emp_number.contains(search)
        }
    }

    var evaluated:    Int { employees.filter { $0.evaluated }.count }
    var notEvaluated: Int { employees.filter { !$0.evaluated }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SiteAttBadge(label: "تم تقييمه", count: evaluated,       color: .green)
                SiteAttBadge(label: "لم يُقيَّم", count: notEvaluated,    color: .orange)
                SiteAttBadge(label: "الإجمالي",  count: employees.count,  color: .purple)
            }
            .padding(.horizontal).padding(.vertical, 8)

            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("بحث...", text: $search)
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal).padding(.bottom, 4)

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else {
                List(filtered) { emp in
                    SiteEmpRowView(emp: emp)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .background(Color(hex: "#F0F2FF"))
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle(supervisor.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        do {
            employees = try await NetworkManager.shared.getSiteSupEmployees(supId: supervisor.id)
        } catch {
            employees = []
        }
        loading = false
    }
}

struct SiteEmpRowView: View {
    let emp: SiteEmpRow
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(emp.evaluated ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: emp.evaluated ? "checkmark" : "clock")
                        .font(.caption)
                        .foregroundColor(emp.evaluated ? .green : .orange)
                )
            VStack(alignment: .trailing, spacing: 4) {
                Text(emp.name).font(.subheadline).fontWeight(.semibold)
                Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                if !emp.department.isEmpty {
                    Text(emp.department).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if emp.evaluated, let score = emp.total_score, let band = emp.overall_band {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", score))
                        .fontWeight(.bold)
                        .foregroundColor(siteScoreColor(score))
                    Text(band).font(.caption2).foregroundColor(.secondary)
                }
            } else {
                Text("لم يُقيَّم").font(.caption2).foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4)
        .padding(.horizontal, 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Reports
// ═══════════════════════════════════════════════════

struct SiteReportsView: View {
    @State private var summary: SiteReportsSummary?
    @State private var loading = true
    @State private var weekOffset = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { weekOffset += 1; Task { await load() } } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    if let s = summary {
                        Text("\(s.week_start) — \(s.week_end)")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    Spacer()
                    Button { weekOffset -= 1; Task { await load() } } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(weekOffset == 0)
                }
                .padding(.horizontal)

                if loading {
                    ProgressView().padding(.top, 40)
                } else if let s = summary {
                    HStack(spacing: 0) {
                        SiteAttBadge(label: "الإجمالي",   count: s.total,               color: .purple)
                        SiteAttBadge(label: "تم تقييمه",  count: s.evaluated_count,     color: .green)
                        SiteAttBadge(label: "متبقي",       count: s.not_evaluated_count, color: .orange)
                    }
                    .padding(.horizontal)

                    if !s.not_evaluated.isEmpty {
                        SiteReportSection(title: "لم يُقيَّموا بعد (\(s.not_evaluated_count))", color: .orange, rows: s.not_evaluated)
                    }
                    if !s.evaluated.isEmpty {
                        SiteReportSection(title: "تم تقييمهم (\(s.evaluated_count))", color: .green, rows: s.evaluated)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("التقارير")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        let (ws, we) = weekDates(offset: weekOffset)
        do {
            summary = try await NetworkManager.shared.getSiteReportsSummary(ws: ws, we: we)
        } catch {
            summary = nil
        }
        loading = false
    }

    func weekDates(offset: Int) -> (String, String) {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysSinceSun = (weekday - 1 + 7) % 7
        let sun = cal.date(byAdding: .day, value: -daysSinceSun + (offset * 7), to: today)!
        let thu = cal.date(byAdding: .day, value: 4, to: sun)!
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: sun), fmt.string(from: thu))
    }
}

struct SiteReportSection: View {
    let title: String; let color: Color; let rows: [SiteReportEmpRow]
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                Text(title).font(.headline).foregroundColor(color)
            }
            .padding(.horizontal)

            ForEach(rows) { emp in
                HStack {
                    if let score = emp.total_score, let band = emp.overall_band {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", score))
                                .fontWeight(.bold).foregroundColor(siteScoreColor(score))
                            Text(band).font(.caption2).foregroundColor(.secondary)
                        }
                        .frame(width: 54)
                    } else {
                        Text("—").frame(width: 54).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(emp.name).font(.subheadline).fontWeight(.semibold)
                        Text(emp.supervisor).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4)
                .padding(.horizontal)
            }
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Attendance
// ═══════════════════════════════════════════════════

struct SiteAttendanceView: View {
    @State private var supervisors: [SiteAttSupRow] = []
    @State private var loading = true
    @State private var selectedDate = Date()

    var didAttend:   Int { supervisors.filter { $0.did_attend }.count }
    var notAttended: Int { supervisors.filter { !$0.did_attend }.count }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("التاريخ", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .onChange(of: selectedDate) { _ in Task { await load() } }

            HStack(spacing: 0) {
                SiteAttBadge(label: "سجّل الحضور", count: didAttend,         color: .green)
                SiteAttBadge(label: "لم يسجّل",    count: notAttended,       color: .orange)
                SiteAttBadge(label: "الإجمالي",    count: supervisors.count, color: .purple)
            }
            .padding(.horizontal)

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else {
                List(supervisors) { sup in
                    NavigationLink(destination: SiteAttDetailView(supervisor: sup, date: selectedDate)) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(sup.did_attend ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: sup.did_attend ? "checkmark.circle.fill" : "clock.fill")
                                        .foregroundColor(sup.did_attend ? .green : .orange)
                                )
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(sup.name).font(.subheadline).fontWeight(.semibold)
                                Text(sup.did_attend
                                     ? "سجّل \(sup.recorded) من \(sup.emp_count)"
                                     : "لم يسجّل بعد")
                                    .font(.caption)
                                    .foregroundColor(sup.did_attend ? .green : .orange)
                            }
                            Spacer()
                            Text("\(sup.emp_count)").fontWeight(.bold).foregroundColor(Color(hex: "#6C63FF"))
                            Text("موظف").font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("الحضور")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        let d = selectedDate.formatted(.iso8601.year().month().day())
        do {
            supervisors = try await NetworkManager.shared.getSiteAttSupervisors(date: d)
        } catch {
            supervisors = []
        }
        loading = false
    }
}

struct SiteAttDetailView: View {
    let supervisor: SiteAttSupRow
    let date: Date
    @State private var detail: SiteAttDetail?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            if loading {
                Spacer(); ProgressView(); Spacer()
            } else if let d = detail {
                HStack(spacing: 0) {
                    SiteAttBadge(label: "حاضر",  count: d.summary.present, color: .green)
                    SiteAttBadge(label: "غائب",  count: d.summary.absent,  color: .red)
                    SiteAttBadge(label: "إجازة", count: d.summary.leave,   color: .blue)
                }
                .padding(.horizontal).padding(.top, 8)

                List(d.rows) { row in
                    HStack {
                        Circle()
                            .fill(attColor(row.status).opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: attIcon(row.status))
                                    .foregroundColor(attColor(row.status))
                                    .font(.caption)
                            )
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(row.emp_name).font(.subheadline).fontWeight(.semibold)
                            Text(row.emp_number).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(attArabic(row.status))
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(attColor(row.status).opacity(0.1))
                            .foregroundColor(attColor(row.status))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            } else {
                Spacer()
                Text("لا توجد بيانات حضور").foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle(supervisor.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    func load() async {
        loading = true
        let d = date.formatted(.iso8601.year().month().day())
        do {
            detail = try await NetworkManager.shared.getSiteAttDetail(supId: supervisor.id, date: d)
        } catch {
            detail = nil
        }
        loading = false
    }

    func attColor(_ s: String) -> Color {
        switch s { case "present": return .green; case "absent": return .red; default: return .blue }
    }
    func attIcon(_ s: String) -> String {
        switch s { case "present": return "checkmark"; case "absent": return "xmark"; default: return "moon.zzz" }
    }
    func attArabic(_ s: String) -> String {
        switch s { case "present": return "حاضر"; case "absent": return "غائب"; default: return "إجازة" }
    }
}

struct SiteAttBadge: View {
    let label: String; let count: Int; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)").font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .padding(4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Requests
// ═══════════════════════════════════════════════════

struct SiteRequestsView: View {
    @State private var items:   [SiteRequestRow] = []
    @State private var loading = true
    @State private var filter  = "all"

    let filters = [("all","الكل"),("pending","معلقة"),("approved","موافق عليها"),("rejected","مرفوضة")]

    var filtered: [SiteRequestRow] {
        filter == "all" ? items : items.filter { $0.status == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.0) { key, label in
                        Button(label) { filter = key }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(filter == key ? Color(hex: "#6C63FF") : Color.white)
                            .foregroundColor(filter == key ? .white : .primary)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
            }

            if loading {
                Spacer(); ProgressView(); Spacer()
            } else if filtered.isEmpty {
                Spacer()
                Text("لا توجد طلبات").foregroundColor(.secondary)
                Spacer()
            } else {
                List(filtered) { req in
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack {
                            Text(req.statusArabic)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(req.statusColor.opacity(0.1))
                                .foregroundColor(req.statusColor)
                                .cornerRadius(8)
                            Spacer()
                            Text(req.typeArabic).fontWeight(.semibold)
                        }
                        HStack {
                            Spacer()
                            Text(req.supervisor_name).font(.caption).foregroundColor(.secondary)
                        }
                        Text(req.created_at).font(.caption).foregroundColor(.secondary)
                        if !req.notes.isEmpty {
                            Text(req.notes).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("طلبات المشرفين")
        .task { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await load() }
        }
    }

    func load() async {
        loading = true
        do {
            items = try await NetworkManager.shared.getSiteRequests()
        } catch {
            items = []
        }
        loading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Helpers
// ═══════════════════════════════════════════════════

func siteScoreColor(_ s: Double) -> Color {
    switch s {
    case 90...:   return .green
    case 75..<90: return .blue
    case 60..<75: return .orange
    default:      return .red
    }
}

// ═══════════════════════════════════════════════════
// MARK: - الموظفون غير المعيّنين (site_supervisor)
// ═══════════════════════════════════════════════════

struct SiteUnassignedView: View {
    @State private var employees: [UnassignedEmployee] = []
    @State private var supervisors: [SiteSupRow] = []
    @State private var loading = true
    @State private var search = ""
    @State private var selectedEmp: UnassignedEmployee? = nil
    @State private var showAssign = false

    var filtered: [UnassignedEmployee] {
        search.isEmpty ? employees : employees.filter {
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
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44)).foregroundColor(.green)
                    Text("لا يوجد موظفون غير معيّنين")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(filtered) { emp in
                    HStack {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(emp.name).font(.subheadline).fontWeight(.semibold)
                            Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                            if !emp.department.isEmpty {
                                Text(emp.department).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            selectedEmp = emp
                            showAssign  = true
                        } label: {
                            Label("تعيين", systemImage: "person.badge.plus")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(hex: "#6C63FF"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "#F0F2FF"))
        .navigationTitle("موظفون غير معيّنين (\(employees.count))")
        .sheet(item: $selectedEmp) { emp in
            AssignEmployeeSheet(emp: emp, supervisors: supervisors) {
                Task { await load() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        do {
            async let emps = NetworkManager.shared.getUnassignedEmployees()
            async let sups = NetworkManager.shared.getSiteSupervisors()
            employees   = try await emps
            supervisors = try await sups
        } catch {
            employees   = []
            supervisors = []
        }
        loading = false
    }
}

struct AssignEmployeeSheet: View {
    let emp: UnassignedEmployee
    let supervisors: [SiteSupRow]
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedSupId: Int? = nil
    @State private var saving = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // بيانات الموظف
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(emp.name).font(.title3).fontWeight(.bold)
                        Text(emp.emp_number).font(.caption).foregroundColor(.secondary)
                        if !emp.department.isEmpty {
                            Text(emp.department).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(14)
                .padding(.horizontal)

                Text("اختر المشرف")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)

                List(supervisors) { sup in
                    HStack {
                        if selectedSupId == sup.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#6C63FF"))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(sup.name).fontWeight(.semibold)
                            Text("\(sup.emp_count) موظف").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSupId = sup.id }
                }
                .listStyle(.plain)

                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption).padding(.horizontal)
                }

                Button {
                    Task { await assign() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Text("تعيين الموظف")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedSupId != nil ? Color(hex: "#6C63FF") : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                }
                .disabled(selectedSupId == nil || saving)
                .padding(.horizontal)
            }
            .background(Color(hex: "#F0F2FF"))
            .navigationTitle("تعيين موظف")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func assign() async {
        guard let supId = selectedSupId else { return }
        saving = true
        do {
            var req = NetworkManager.shared.makeRequest("/api/employees/\(emp.id)/assign", method: "POST",
                body: try JSONSerialization.data(withJSONObject: ["supervisor_id": supId]))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200 {
                onDone()
                dismiss()
            } else {
                errorMsg = "حدث خطأ في التعيين"
            }
        } catch {
            errorMsg = "تعذّر الاتصال بالسيرفر"
        }
        saving = false
    }
}
