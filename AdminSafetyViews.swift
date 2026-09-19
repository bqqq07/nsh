import SwiftUI

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Admin Safety Manager Dashboard
// ══════════════════════════════════════════════════════════════════════════════

struct AdminSafetyManagerDashboardView: View {
    @State private var dashboard: AdminSafetyManagerDashboard? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""
    @State private var period     = "week"
    @State private var weekOffset = 0
    @State private var expandInactive = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    if isLoading {
                        ProgressView("جاري التحميل...").padding(.top, 80)
                    } else if let d = dashboard {
                        VStack(spacing: 16) {
                            periodPicker(d)
                            kpiSection(d)
                            officerRankingTable(d)
                            if !d.welfare_rows.isEmpty { welfareSection(d) }
                            if !d.overdue_cas.isEmpty { overdueCasSection(d) }
                            if !d.inactive_officers.isEmpty { inactiveSection(d) }
                            if !d.high_risk_open.isEmpty { highRiskSection(d) }
                            scoreTrendSection(d)
                            Spacer(minLength: 24)
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48)).foregroundColor(.orange)
                            Text(errorMsg.isEmpty ? "تعذّر تحميل البيانات" : errorMsg)
                                .multilineTextAlignment(.center).foregroundColor(.secondary)
                            Button("إعادة المحاولة") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                        }.padding(40)
                    }
                }
                .refreshable { await load() }
            }
            .navigationTitle("لوحة السيفتي")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HSEReportsView()) {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                }
            }
            .task { await load() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // ── Period Picker ────────────────────────────────────────────────────
    @ViewBuilder
    private func periodPicker(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(spacing: 8) {
            Picker("", selection: $period) {
                Text("الأسبوع").tag("week")
                Text("الشهر").tag("month")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: period) { _ in weekOffset = 0; Task { await load() } }

            if period == "week" {
                HStack(spacing: 12) {
                    Button {
                        weekOffset -= 1
                        Task { await load() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline).foregroundColor(Color(hex: "#7b5ea7"))
                    }
                    Spacer()
                    Text(d.period_lbl).font(.subheadline.bold())
                    Spacer()
                    Button {
                        if weekOffset < 0 { weekOffset += 1; Task { await load() } }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(weekOffset < 0 ? Color(hex: "#7b5ea7") : .gray)
                    }
                    .disabled(weekOffset >= 0)
                }
                .padding(.horizontal)
            } else {
                Text(d.period_lbl).font(.subheadline.bold()).padding(.horizontal)
            }
        }
    }

    // ── KPI Grid (6 tiles) ───────────────────────────────────────────────
    @ViewBuilder
    private func kpiSection(_ d: AdminSafetyManagerDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            SMKpiCard(value: "\(d.active_officers)/\(d.total_officers)",
                      sub: "\(d.compliance_pct)% الالتزام",
                      label: "الأوفيسرز النشطون",
                      icon: "person.fill.checkmark", color: d.compliance_pct >= 80 ? .green : .orange)
            SMKpiCard(value: "\(d.total_obs)",
                      sub: "UA:\(d.total_ua) UC:\(d.total_uc) +:\(d.total_pos)",
                      label: "إجمالي الملاحظات",
                      icon: "eye.fill", color: .blue)
            SMKpiCard(value: String(format: "%.1f", d.avg_score),
                      sub: "متوسط الدرجات",
                      label: "أداء الفريق",
                      icon: "chart.bar.fill", color: .purple)
            SMKpiCard(value: "\(d.high_risk_open.count)",
                      sub: "مفتوحة",
                      label: "خطورة عالية",
                      icon: "exclamationmark.triangle.fill",
                      color: d.high_risk_open.isEmpty ? .green : .red)
            SMKpiCard(value: "\(d.overdue_cas.count)",
                      sub: "متأخرة",
                      label: "إجراءات تصحيحية",
                      icon: "clock.badge.exclamationmark",
                      color: d.overdue_cas.isEmpty ? .green : .orange)
            SMKpiCard(value: "\(d.inactive_officers.count)",
                      sub: "بدون نشاط",
                      label: "أوفيسرز غير نشطين",
                      icon: "person.fill.xmark",
                      color: d.inactive_officers.isEmpty ? .green : .red)
        }
        .padding(.horizontal)
    }

    // ── Officer Ranking Table ────────────────────────────────────────────
    @ViewBuilder
    private func officerRankingTable(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ترتيب الأوفيسرز — \(d.period_lbl)")
                .font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#").frame(width: 28, alignment: .center)
                            .font(.caption).bold().foregroundColor(.secondary)
                        Text("الاسم").frame(width: 110, alignment: .leading)
                            .font(.caption).bold().foregroundColor(.secondary)
                        ForEach(["CI","OBS","TBT","NM","BBS","Score","Δ"], id: \.self) { col in
                            Text(col).frame(width: col == "Score" ? 52 : 38, alignment: .center)
                                .font(.caption).bold().foregroundColor(.secondary)
                        }
                        Text("CAs").frame(width: 36, alignment: .center)
                            .font(.caption).bold().foregroundColor(.secondary)
                    }
                    .padding(.vertical, 7).padding(.horizontal, 10)
                    .background(Color(.systemGray6))
                    Divider()
                    ForEach(Array(d.officers.enumerated()), id: \.element.id) { idx, o in
                        let rank = idx + 1
                        HStack(spacing: 0) {
                            rankBadge(rank)
                                .frame(width: 28, alignment: .center)
                            Text(o.officer_name.components(separatedBy: " ").first ?? "")
                                .frame(width: 110, alignment: .leading)
                                .font(.caption).lineLimit(1)
                            rankCell(o.checkin_days, hi: .teal)
                            rankCell(o.obs_total, hi: .blue)
                            rankCell(o.tbt, hi: .purple)
                            rankCell(o.nm, hi: .red)
                            rankCell(o.bbs, hi: .green)
                            Text(String(format: "%.0f", o.score))
                                .frame(width: 52, alignment: .center)
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                            trendCell(o.trend)
                            rankCell(o.ca_open, hi: .orange)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(o.checkin_days == 0 ? Color.red.opacity(0.04) : Color.clear)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        if rank == 1 {
            Image(systemName: "medal.fill").foregroundColor(.yellow).font(.caption)
        } else if rank == 2 {
            Image(systemName: "medal.fill").foregroundColor(.gray).font(.caption)
        } else if rank == 3 {
            Image(systemName: "medal.fill").foregroundColor(.brown).font(.caption)
        } else {
            Text("\(rank)").font(.caption2).foregroundColor(.secondary)
        }
    }

    private func rankCell(_ n: Int, hi: Color) -> some View {
        Text(n == 0 ? "—" : "\(n)")
            .frame(width: 38, alignment: .center)
            .font(.caption)
            .foregroundColor(n > 0 ? hi : Color.secondary.opacity(0.4))
    }

    @ViewBuilder
    private func trendCell(_ trend: Double) -> some View {
        let absVal = abs(trend)
        let text   = absVal == 0 ? "—" : (trend > 0 ? "+\(Int(absVal))" : "-\(Int(absVal))")
        let color: Color = trend > 0 ? .green : (trend < 0 ? .red : .secondary)
        Text(text)
            .frame(width: 38, alignment: .center)
            .font(.caption.bold())
            .foregroundColor(color)
    }

    // ── Welfare Officers Summary ─────────────────────────────────────────
    @ViewBuilder
    private func welfareSection(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ملخص أوفيسرز الرفاه — \(d.period_lbl)")
                .font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("الاسم").frame(width: 110, alignment: .leading).font(.caption).bold().foregroundColor(.secondary)
                        ForEach(["جولات","متوسط","مغلقة","مفتوحة","شكاوى"], id: \.self) { col in
                            Text(col).frame(width: 58, alignment: .center).font(.caption).bold().foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 7).padding(.horizontal, 10)
                    .background(Color(.systemGray6))
                    Divider()
                    ForEach(d.welfare_rows) { r in
                        HStack(spacing: 0) {
                            Text(r.officer_name.components(separatedBy: " ").prefix(2).joined(separator: " "))
                                .frame(width: 110, alignment: .leading).font(.caption).lineLimit(1)
                            wlfCell(r.rounds, hi: .blue)
                            Text(r.avg_score.map { String(format: "%.1f", $0) } ?? "—")
                                .frame(width: 58, alignment: .center).font(.caption).foregroundColor(.purple)
                            wlfCell(r.finds_closed, hi: .green)
                            wlfCell(r.finds_open, hi: r.finds_open > 0 ? .red : .secondary)
                            wlfCell(r.complaints, hi: r.complaints > 0 ? .orange : .secondary)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(r.rounds == 0 ? Color.red.opacity(0.04) : Color.clear)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private func wlfCell(_ n: Int, hi: Color) -> some View {
        Text(n == 0 ? "—" : "\(n)")
            .frame(width: 58, alignment: .center)
            .font(.caption)
            .foregroundColor(n > 0 ? hi : Color.secondary.opacity(0.4))
    }

    // ── Overdue CAs Panel ────────────────────────────────────────────────
    @ViewBuilder
    private func overdueCasSection(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("إجراءات تصحيحية متأخرة (\(d.overdue_cas.count))",
                  systemImage: "clock.badge.exclamationmark")
                .font(.headline).foregroundColor(.orange).padding(.horizontal)
            ForEach(d.overdue_cas) { ca in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ca.action_required.isEmpty ? "—" : ca.action_required)
                            .font(.subheadline).lineLimit(2)
                        if let due = ca.due_date {
                            Text("استحقاق: \(due)")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    Spacer()
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.06))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2)))
                .padding(.horizontal)
            }
        }
    }

    // ── Inactive Officers ────────────────────────────────────────────────
    @ViewBuilder
    private func inactiveSection(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expandInactive.toggle() }
            } label: {
                HStack {
                    Label("بدون نشاط هذه الفترة (\(d.inactive_officers.count))",
                          systemImage: "person.fill.xmark")
                        .font(.headline).foregroundColor(.red)
                    Spacer()
                    Image(systemName: expandInactive ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            if expandInactive {
                FlowLayout(spacing: 8) {
                    ForEach(d.inactive_officers) { o in
                        Text(o.name).font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // ── High Risk Section ────────────────────────────────────────────────
    @ViewBuilder
    private func highRiskSection(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("خطورة عالية مفتوحة (\(d.high_risk_open.count))",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundColor(.red).padding(.horizontal)
            ForEach(d.high_risk_open) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.date).font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    if !item.category.isEmpty { Text(item.category).font(.subheadline).bold() }
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "mappin").font(.caption).foregroundColor(.secondary)
                    }
                    if !item.description.isEmpty {
                        Text(item.description).font(.caption).lineLimit(2)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.04))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2)))
                .padding(.horizontal)
            }
        }
    }

    // ── 6-week Score Trend ───────────────────────────────────────────────
    @ViewBuilder
    private func scoreTrendSection(_ d: AdminSafetyManagerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("اتجاه الدرجة — 6 أسابيع")
                .font(.headline).padding(.horizontal)
            VStack(alignment: .leading, spacing: 4) {
                SMScoreTrendChart(labels: d.weekly_labels, values: d.weekly_avg)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do {
            dashboard = try await NetworkManager.shared.adminSafetyManagerDashboard(
                period: period, weekOffset: weekOffset)
        } catch {
            errorMsg = "تعذّر تحميل البيانات"
        }
        isLoading = false
    }
}

private struct SMKpiCard: View {
    let value: String
    let sub:   String
    let label: String
    let icon:  String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Spacer()
            }
            Text(value).font(.title2).bold().foregroundColor(color)
            Text(sub).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
            Text(label).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2)))
    }
}

private struct SMScoreTrendChart: View {
    let labels: [String]
    let values: [Double]
    private var maxVal: Double { max(values.max() ?? 1, 1) }
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<labels.count, id: \.self) { i in
                    let val = i < values.count ? values[i] : 0
                    let h = max(4, geo.size.height * 0.75 * CGFloat(val) / CGFloat(maxVal))
                    VStack(spacing: 3) {
                        Text(String(format: "%.0f", val)).font(.system(size: 9)).foregroundColor(.purple)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.purple.opacity(0.8), .purple.opacity(0.3)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: h)
                        Text(labels[i]).font(.system(size: 8)).foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 90)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Admin Safety Menu
// ══════════════════════════════════════════════════════════════════════════════

struct AdminSafetyMenuView: View {
    var body: some View {
        List {
            Section(header: Text("إدارة الفرق")) {
                NavigationLink(destination: AdminSafetyTeamsView()) {
                    Label("فرق السيفتي", systemImage: "person.3.fill")
                }
                NavigationLink(destination: AdminSupAssignView()) {
                    Label("تعيين الأوفيسرز للمشرفين", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
            }
            Section(header: Text("التقارير")) {
                NavigationLink(destination: TraineeWeeklyReportView()) {
                    Label("Trainee Weekly Report", systemImage: "doc.richtext.fill")
                }
            }
            Section(header: Text("الصلاحيات")) {
                NavigationLink(destination: AdminHseAccessView()) {
                    Label("صلاحية HSE", systemImage: "lock.shield.fill")
                }
            }
        }
        .navigationTitle("إدارة السيفتي")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Admin Safety Teams
// ══════════════════════════════════════════════════════════════════════════════

struct AdminSafetyTeamsView: View {
    @State private var response: AdminSafetyTeamsResponse? = nil
    @State private var isLoading = true
    @State private var errorMsg  = ""
    @State private var assigningSup: AdminTeamSupervisor? = nil
    @State private var toast = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isLoading {
                    ProgressView("جاري التحميل...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let r = response {
                    List {
                        if !r.unassigned.isEmpty {
                            Section(header: Text("غير معيَّنين (\(r.unassigned.count))").foregroundColor(.orange)) {
                                ForEach(r.unassigned) { o in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(o.name).font(.subheadline).bold()
                                            Text(o.role_label).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        ForEach(r.supervisors) { sup in
                            Section(header: HStack {
                                Text(sup.name)
                                Spacer()
                                Text("\(sup.officers.count) officer(s)").font(.caption).foregroundColor(.secondary)
                            }) {
                                ForEach(sup.officers) { o in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(o.name).font(.subheadline)
                                            Text(o.role_label).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await removeTeamMember(teamId: o.team_id) }
                                        } label: {
                                            Label("إزالة", systemImage: "minus.circle")
                                        }
                                    }
                                }
                                Button {
                                    assigningSup = sup
                                } label: {
                                    Label("تعيين أوفيسر", systemImage: "plus.circle.fill")
                                        .foregroundColor(Color(hex: "#7b5ea7"))
                                }
                            }
                        }
                    }
                } else {
                    Text(errorMsg.isEmpty ? "لا توجد بيانات" : errorMsg)
                        .foregroundColor(.secondary).padding()
                }
            }
            if !toast.isEmpty {
                Text(toast).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.systemGray2).opacity(0.9)).cornerRadius(10)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("فرق السيفتي")
        .sheet(item: $assigningSup) { sup in
            AssignOfficerSheet(supervisor: sup,
                               allOfficers: response?.all_officers ?? []) { offId in
                Task { await assignOfficer(supId: sup.sup_id, offId: offId) }
                assigningSup = nil
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true; errorMsg = ""
        do { response = try await NetworkManager.shared.adminSafetyTeams() }
        catch { errorMsg = "تعذّر تحميل البيانات" }
        isLoading = false
    }

    private func assignOfficer(supId: Int, offId: Int) async {
        do {
            try await NetworkManager.shared.adminSafetyTeamAssign(supId: supId, offId: offId)
            showToast("تم التعيين ✓")
            await loadData()
        } catch { showToast("خطأ في التعيين") }
    }

    private func removeTeamMember(teamId: Int) async {
        do {
            try await NetworkManager.shared.adminSafetyTeamRemove(teamId: teamId)
            showToast("تمت الإزالة ✓")
            await loadData()
        } catch { showToast("خطأ في الإزالة") }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }
}

private struct AssignOfficerSheet: View {
    let supervisor: AdminTeamSupervisor
    let allOfficers: [AdminTeamsAllOfficer]
    let onAssign: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private var available: [AdminTeamsAllOfficer] {
        let assigned = Set(supervisor.officers.map { $0.officer_id })
        return allOfficers.filter { !assigned.contains($0.officer_id) }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("اختر أوفيسر لتعيينه لـ \(supervisor.name)")) {
                    if available.isEmpty {
                        Text("لا يوجد أوفيسرز متاحون").foregroundColor(.secondary)
                    } else {
                        ForEach(available) { o in
                            Button {
                                onAssign(o.officer_id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(o.name).foregroundColor(.primary).font(.subheadline).bold()
                                        Text(o.role_label).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("تعيين أوفيسر")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Trainee Weekly Report Generator
// ══════════════════════════════════════════════════════════════════════════════

struct TraineeWeeklyReportView: View {
    @State private var allOfficers: [AdminOfficersReportOfficer] = []
    @State private var loadingOfficers = true
    @State private var selectedIds: Set<Int> = []
    @State private var roleFilter  = "all"
    @State private var isGenerating = false
    @State private var errorMsg     = ""
    @State private var shareItem: ShareableFile? = nil

    private let roles = [("all", "الكل"), ("safety_officer", "Safety"), ("safety_welfare", "Welfare"), ("environment_officer", "Environment")]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Week label
                let (ws, we) = currentWeekRange()
                HStack(spacing: 8) {
                    Image(systemName: "calendar").foregroundColor(.secondary)
                    Text("الأسبوع الحالي: \(ws) – \(we)")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemGray6)).cornerRadius(10)
                .padding(.horizontal)

                // Role filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(roles, id: \.0) { key, label in
                            Button {
                                roleFilter = key
                                applyRoleFilter()
                            } label: {
                                Text(label)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(roleFilter == key ? Color(hex: "#7b5ea7") : Color(.systemGray5))
                                    .foregroundColor(roleFilter == key ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Officers list
                if loadingOfficers {
                    ProgressView("تحميل الأوفيسرز...").padding()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("اختر الأوفيسرز").font(.headline)
                            Spacer()
                            Button("الكل") { selectedIds = Set(allOfficers.map { $0.officer_id }) }
                                .font(.caption).foregroundColor(.blue)
                            Button("لا شيء") { selectedIds.removeAll() }
                                .font(.caption).foregroundColor(.red)
                        }
                        .padding(.horizontal)

                        ForEach(groupedOfficers, id: \.0) { role, officers in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(officers.first?.role_label ?? role)
                                    .font(.caption).bold().foregroundColor(.secondary)
                                    .padding(.horizontal).textCase(.uppercase)
                                ForEach(officers) { o in
                                    Button {
                                        if selectedIds.contains(o.officer_id) { selectedIds.remove(o.officer_id) }
                                        else { selectedIds.insert(o.officer_id) }
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedIds.contains(o.officer_id) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(selectedIds.contains(o.officer_id) ? Color(hex: "#7b5ea7") : .secondary)
                                            Text(o.name).font(.subheadline).foregroundColor(.primary)
                                            Spacer()
                                            Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal).padding(.vertical, 7)
                                    }
                                    Divider().padding(.leading)
                                }
                            }
                        }
                    }
                }

                // Generate button
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: 10) {
                        if isGenerating {
                            ProgressView().tint(.white)
                            Text("جاري التوليد...").bold()
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("توليد التقرير PPTX").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((isGenerating || selectedIds.isEmpty) ? Color.gray : Color(hex: "#7b5ea7"))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .disabled(isGenerating || selectedIds.isEmpty)

                if !errorMsg.isEmpty {
                    Text(errorMsg).font(.subheadline).foregroundColor(.red)
                        .padding().background(Color.red.opacity(0.08)).cornerRadius(10).padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Trainee Weekly Report")
        .task { await loadOfficers() }
        .sheet(item: $shareItem) { f in ActivityView(items: [f.url]) }
    }

    private var groupedOfficers: [(String, [AdminOfficersReportOfficer])] {
        var dict: [String: [AdminOfficersReportOfficer]] = [:]
        for o in allOfficers { dict[o.role, default: []].append(o) }
        return dict.sorted { $0.key < $1.key }
    }

    private func applyRoleFilter() {
        if roleFilter == "all" {
            selectedIds = Set(allOfficers.map { $0.officer_id })
        } else {
            selectedIds = Set(allOfficers.filter { $0.role == roleFilter }.map { $0.officer_id })
        }
    }

    private func loadOfficers() async {
        loadingOfficers = true
        do {
            let res = try await NetworkManager.shared.adminOfficersReport(
                dateFrom: formatDateISO(Date()), dateTo: formatDateISO(Date()), officerIds: [])
            allOfficers = res.all_officers
            selectedIds = Set(allOfficers.map { $0.officer_id })
        } catch {}
        loadingOfficers = false
    }

    private func generate() async {
        isGenerating = true; errorMsg = ""
        do {
            let data = try await NetworkManager.shared.adminTraineeReport(traineeIds: Array(selectedIds))
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Trainee_Weekly_Report_\(weekTag()).pptx")
            try data.write(to: tmpURL)
            await MainActor.run { shareItem = ShareableFile(url: tmpURL) }
        } catch {
            await MainActor.run { errorMsg = "فشل توليد التقرير — تأكد من وجود القالب على الخادم" }
        }
        isGenerating = false
    }

    private func currentWeekRange() -> (String, String) {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let ws = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let we = cal.date(byAdding: .day, value: 6, to: ws) ?? now
        let df = DateFormatter(); df.dateFormat = "dd MMM"
        return (df.string(from: ws), df.string(from: we))
    }

    private func weekTag() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        return df.string(from: Date())
    }
}

private struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Admin Supervisor Assign
// ══════════════════════════════════════════════════════════════════════════════

struct AdminSupAssignView: View {
    @State private var response: AdminSupAssignResponse? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""
    @State private var toast      = ""
    @State private var assigningSup: AdminSupAssignSupervisor? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isLoading {
                    ProgressView("جاري التحميل...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let r = response {
                    List {
                        if !r.unassigned.isEmpty {
                            Section(header: Text("غير معيَّنين (\(r.unassigned.count))").foregroundColor(.orange)) {
                                ForEach(r.unassigned) { o in
                                    HStack {
                                        Text(o.name).font(.subheadline)
                                        Spacer()
                                        Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        ForEach(r.supervisors) { sup in
                            Section(header: HStack {
                                Text(sup.name)
                                Spacer()
                                Text("\(sup.assigned_officers.count) officer(s)").font(.caption).foregroundColor(.secondary)
                            }) {
                                ForEach(sup.assigned_officers) { o in
                                    HStack {
                                        Text(o.name).font(.subheadline)
                                        Spacer()
                                        Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await doAssign(supId: sup.sup_id, officerId: o.officer_id, action: "remove") }
                                        } label: {
                                            Label("إزالة", systemImage: "minus.circle")
                                        }
                                    }
                                }
                                Button {
                                    assigningSup = sup
                                } label: {
                                    Label("إضافة أوفيسر", systemImage: "plus.circle.fill")
                                        .foregroundColor(Color(hex: "#7b5ea7"))
                                }
                            }
                        }
                    }
                } else {
                    Text(errorMsg.isEmpty ? "لا توجد بيانات" : errorMsg)
                        .foregroundColor(.secondary).padding()
                }
            }
            if !toast.isEmpty {
                Text(toast).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.systemGray2).opacity(0.9)).cornerRadius(10)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("تعيين الأوفيسرز")
        .sheet(item: $assigningSup) { sup in
            let allOffs = response?.all_officers ?? []
            let assignedIds = Set(sup.assigned_officers.map { $0.officer_id })
            let available = allOffs.filter { !assignedIds.contains($0.officer_id) }
            PickOfficerSheet(supervisorName: sup.name, officers: available) { offId in
                Task { await doAssign(supId: sup.sup_id, officerId: offId, action: "add") }
                assigningSup = nil
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true; errorMsg = ""
        do { response = try await NetworkManager.shared.adminSupAssignList() }
        catch { errorMsg = "تعذّر تحميل البيانات" }
        isLoading = false
    }

    private func doAssign(supId: Int, officerId: Int, action: String) async {
        do {
            try await NetworkManager.shared.adminSupAssign(supId: supId, officerId: officerId, action: action)
            showToast(action == "add" ? "تم التعيين ✓" : "تمت الإزالة ✓")
            await loadData()
        } catch { showToast("حدث خطأ") }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }
}

private struct PickOfficerSheet: View {
    let supervisorName: String
    let officers: [AdminSupAssignOfficer]
    let onPick: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("إضافة إلى: \(supervisorName)")) {
                    if officers.isEmpty {
                        Text("لا يوجد أوفيسرز متاحون").foregroundColor(.secondary)
                    } else {
                        ForEach(officers) { o in
                            Button {
                                onPick(o.officer_id)
                            } label: {
                                HStack {
                                    Text(o.name).foregroundColor(.primary).font(.subheadline).bold()
                                    Spacer()
                                    Text(o.code).font(.caption2.monospaced()).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("اختر أوفيسر")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Admin HSE Access Management
// ══════════════════════════════════════════════════════════════════════════════

struct AdminHseAccessView: View {
    @State private var accessList: [AdminHseAccessUser] = []
    @State private var isLoading   = true
    @State private var errorMsg    = ""
    @State private var newCode     = ""
    @State private var isGranting  = false
    @State private var grantError  = ""
    @State private var toast       = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                // Grant Access section
                Section(header: Text("منح الصلاحية")) {
                    HStack(spacing: 8) {
                        TextField("كود المشرف (مثل 12345)", text: $newCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.characters)
                        Button {
                            Task { await grantAccess() }
                        } label: {
                            if isGranting {
                                ProgressView().tint(.white)
                            } else {
                                Text("منح").bold()
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(newCode.count >= 4 ? Color(hex: "#0f172a") : Color.gray)
                        .foregroundColor(.white).cornerRadius(8)
                        .disabled(newCode.count < 4 || isGranting)
                    }
                    if !grantError.isEmpty {
                        Text(grantError).font(.caption).foregroundColor(.red)
                    }
                }

                // Current access list
                Section(header: Text("المستخدمون الحاليون (\(accessList.count))")) {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if accessList.isEmpty {
                        Text("لا يوجد مستخدمون بصلاحية HSE").foregroundColor(.secondary)
                    } else {
                        ForEach(accessList) { u in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(u.name).font(.subheadline).bold()
                                        if u.is_primary {
                                            Text("Primary").font(.caption)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue).cornerRadius(4)
                                        }
                                    }
                                    Text("\(u.code) • \(u.role)").font(.caption).foregroundColor(.secondary)
                                    if let g = u.granted {
                                        Text("منح: \(formatDisplayDate(g))").font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                if !u.is_primary {
                                    Button(role: .destructive) {
                                        Task { await removeAccess(userId: u.user_id) }
                                    } label: {
                                        Label("إزالة", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if !toast.isEmpty {
                Text(toast).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.systemGray2).opacity(0.9)).cornerRadius(10)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("صلاحية HSE")
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true; errorMsg = ""
        do { accessList = (try await NetworkManager.shared.adminHseAccessList()).access_list }
        catch { errorMsg = "تعذّر تحميل البيانات" }
        isLoading = false
    }

    private func grantAccess() async {
        isGranting = true; grantError = ""
        do {
            _ = try await NetworkManager.shared.adminHseAccessGrant(code: newCode.uppercased())
            newCode = ""
            showToast("تم منح الصلاحية ✓")
            await loadData()
        } catch {
            grantError = "لم يُعثر على مستخدم أو حدث خطأ"
        }
        isGranting = false
    }

    private func removeAccess(userId: Int) async {
        do {
            try await NetworkManager.shared.adminHseAccessRemove(userId: userId)
            showToast("تمت الإزالة ✓")
            await loadData()
        } catch { showToast("حدث خطأ") }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }

    private func formatDisplayDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: iso) {
            let df = DateFormatter(); df.dateStyle = .medium; df.locale = Locale(identifier: "ar")
            return df.string(from: d)
        }
        return String(iso.prefix(10))
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MARK: - Helpers
// ══════════════════════════════════════════════════════════════════════════════

private func formatDateISO(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            rowHeight = max(rowHeight, s.height); x += s.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            rowHeight = max(rowHeight, s.height); x += s.width + spacing
        }
    }
}
