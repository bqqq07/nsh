import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - Tab View
// ═══════════════════════════════════════════════════
struct SafetySupervisorTabView: View {
    @State private var pendingRequests = 0

    var body: some View {
        TabView {
            SafetySupervisorHomeView()
                .tabItem { Label("Officers", systemImage: "person.3.fill") }

            NavigationView { SafetySupMonitorView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.clipboard.fill") }

            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "tray.fill") }
                .badge(pendingRequests)

            NavigationView { UserLocationView() }
                .tabItem { Label("Location", systemImage: "location.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#16a34a"))
        .task { await loadBadge() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await loadBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadBadge() }
        }
    }

    private func loadBadge() async {
        let reqs = (try? await NetworkManager.shared.getMyRequests()) ?? []
        pendingRequests = reqs.filter { $0.status == "pending" }.count
    }
}

// ── Monitor tab: Observations, TBT, Check-in lists (all officers) ──
struct SafetySupMonitorView: View {
    var body: some View {
        List {
            Section(header: Text("Officers Activity")) {
                NavigationLink(destination: SafetySupCheckinView()) {
                    Label("Locations Today", systemImage: "location.fill")
                        .foregroundColor(.orange)
                }
                NavigationLink(destination: HSEObservationsView()) {
                    Label("Observations", systemImage: "eye.fill")
                }
                NavigationLink(destination: HSETbtView()) {
                    Label("TBT", systemImage: "person.2.badge.gearshape")
                }
                NavigationLink(destination: HSENearMissView()) {
                    Label("Near Miss", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            Section(header: Text("Reports")) {
                NavigationLink(destination: SafetySupWeeklyReportView()) {
                    Label("Weekly Report", systemImage: "doc.text.fill")
                }
            }
        }
        .navigationTitle("Activity")
    }
}

// ── Check-in today view for supervisor (shows all officers) ──────────
struct SafetySupCheckinView: View {
    @State private var officers: [SafetyOfficerStat] = []
    @State private var isLoading = true

    private var checkedIn: [SafetyOfficerStat] { officers.filter { $0.checkedIn } }
    private var notIn:     [SafetyOfficerStat] { officers.filter { !$0.checkedIn } }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else {
                Section(header: Text("Summary")) {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(checkedIn.count)").font(.title).fontWeight(.bold).foregroundColor(.orange)
                            Text("Present").font(.caption).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(notIn.count)").font(.title).fontWeight(.bold).foregroundColor(.secondary)
                            Text("No Location").font(.caption).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(officers.count)").font(.title).fontWeight(.bold)
                            Text("Total").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                if !checkedIn.isEmpty {
                    Section(header: Text("Present (\(checkedIn.count))")) {
                        ForEach(checkedIn) { o in
                            checkinRow(o, isIn: true)
                        }
                    }
                }
                if !notIn.isEmpty {
                    Section(header: Text("No Location (\(notIn.count))")) {
                        ForEach(notIn) { o in
                            checkinRow(o, isIn: false)
                        }
                    }
                }
            }
        }
        .navigationTitle("Locations Today")
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private func checkinRow(_ o: SafetyOfficerStat, isIn: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(o.name.isEmpty ? o.code : o.name).font(.headline)
                if let loc = o.checkinLocation, !loc.isEmpty {
                    Text("📍 \(loc)").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(isIn ? "✓ Present" : "✗ —")
                .font(.caption).fontWeight(.bold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isIn ? Color.orange.opacity(0.15) : Color.gray.opacity(0.08))
                .foregroundColor(isIn ? .orange : .secondary)
                .cornerRadius(8)
        }
    }

    private func load() async {
        isLoading = true
        officers = (try? await NetworkManager.shared.getSafetyOfficers()) ?? []
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Home: Officers Overview
// ═══════════════════════════════════════════════════
struct SafetySupervisorHomeView: View {
    @State private var officers:     [SafetyOfficerStat] = []
    @State private var highRisk:     [HseHighRiskItem]   = []
    @State private var isLoading     = true
    @State private var errorMsg      = ""

    private var checkedIn: Int  { officers.filter { $0.checkedIn }.count }
    private var totalObs: Int   { officers.reduce(0) { $0 + $1.obsWeek } }
    private var totalTbt: Int   { officers.reduce(0) { $0 + $1.tbtWeek } }
    private var totalNm: Int    { officers.reduce(0) { $0 + $1.nmWeek } }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading officers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !errorMsg.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle).foregroundColor(.orange)
                        Text(errorMsg).font(.caption).foregroundColor(.secondary)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Summary KPI cards
                        Section {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                statCard(title: "Checked In", value: "\(checkedIn)/\(officers.count)",
                                         color: checkedIn == officers.count ? .green : .orange,
                                         icon: "checkmark.seal.fill")
                                statCard(title: "Officers", value: "\(officers.count)",
                                         color: .blue, icon: "person.3.fill")
                                statCard(title: "Obs (week)", value: "\(totalObs)",
                                         color: .blue, icon: "eye.fill")
                                statCard(title: "TBT (week)", value: "\(totalTbt)",
                                         color: .purple, icon: "person.2.badge.gearshape")
                                statCard(title: "Near Miss", value: "\(totalNm)",
                                         color: totalNm > 0 ? .red : .secondary, icon: "exclamationmark.triangle.fill")
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                        // High-risk open observations alert panel
                        if !highRisk.isEmpty {
                            Section(header: Label("High Risk Open (\(highRisk.count))",
                                                  systemImage: "exclamationmark.shield.fill")
                                .foregroundColor(.red)) {
                                ForEach(highRisk) { item in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(item.officer).font(.subheadline).fontWeight(.semibold)
                                            Spacer()
                                            Text(item.date).font(.caption2).foregroundColor(.secondary)
                                        }
                                        if !item.category.isEmpty {
                                            Text(item.category).font(.caption).foregroundColor(.orange)
                                        }
                                        if !item.description.isEmpty {
                                            Text(item.description)
                                                .font(.caption).foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }

                        // Officers list
                        Section(header: Text("Today's Status")) {
                            if officers.isEmpty {
                                Text("No officers assigned.")
                                    .foregroundColor(.secondary)
                                    .font(.callout)
                            } else {
                                ForEach(officers) { officer in
                                    OfficerStatRow(officer: officer)
                                }
                            }
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("My Officers")
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMsg = ""
        do {
            async let officersTask = NetworkManager.shared.getSafetyOfficers()
            async let dashTask     = NetworkManager.shared.getHseDashboard()
            officers  = try await officersTask
            highRisk  = (try? await dashTask)?.high_risk_open ?? []
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func statCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).font(.caption)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Officer Row
// ═══════════════════════════════════════════════════
struct OfficerStatRow: View {
    let officer: SafetyOfficerStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(officer.name.isEmpty ? officer.code : officer.name)
                        .font(.headline)
                    Text(officer.code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                checkinBadge
            }

            if let loc = officer.checkinLocation, !loc.isEmpty {
                Label(loc, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let pkg = officer.locationPkg, let unit = officer.locationUnit {
                Label("PKG \(pkg) · Unit \(unit)", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                pill("Obs", officer.obsWeek, color: .blue)
                pill("TBT", officer.tbtWeek, color: .purple)
                pill("NM", officer.nmWeek, color: .red)
                pill("JSO", officer.jsoWeek, color: .teal)
                pill("Insp", officer.inspWeek, color: .indigo)
            }
            HStack(spacing: 6) {
                pill("BBS", officer.bbsWeek, color: .orange)
                pill("PTW", officer.ptwWeek, color: .mint)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                    Text(String(format: "%.1f", officer.score))
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(officer.score > 0 ? .green : .secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private var checkinBadge: some View {
        Text(officer.checkedIn ? "✓ In" : "✗ Out")
            .font(.caption).fontWeight(.bold)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(officer.checkedIn ? Color.green.opacity(0.15) : Color.red.opacity(0.12))
            .foregroundColor(officer.checkedIn ? .green : .red)
            .cornerRadius(8)
    }

    @ViewBuilder
    private func pill(_ label: String, _ value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(value)").font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(6)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Weekly Report View
// ═══════════════════════════════════════════════════
struct SafetySupWeeklyReportView: View {
    @State private var report:    HseWeeklyReportResponse? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading report…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !errorMsg.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
                    Text(errorMsg).font(.caption).foregroundColor(.secondary)
                    Button("Retry") { Task { await load() } }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let rep = report {
                List {
                    Section(header: Text("Week: \(rep.week_start) → \(rep.week_end)")) {
                        EmptyView()
                    }
                    if rep.rows.isEmpty {
                        Section { Text("No data for this week.").foregroundColor(.secondary) }
                    } else {
                        let prevMap = Dictionary(uniqueKeysWithValues: rep.prev_rows.map { ($0.officer_id, $0) })
                        ForEach(rep.rows.sorted { $0.score > $1.score }) { row in
                            let prev = prevMap[row.officer_id]
                            weeklyRow(row, prev: prev)
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Weekly Report")
        .task { await load() }
    }

    @ViewBuilder
    private func weeklyRow(_ row: HseWeeklyRow, prev: HseWeeklyRow?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.officer_name).font(.headline)
                Spacer()
                // Score with trend arrow
                HStack(spacing: 4) {
                    if let p = prev {
                        Image(systemName: row.score >= p.score ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundColor(row.score >= p.score ? .green : .red)
                    }
                    Text(String(format: "%.1f", row.score))
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(scoreColor(row.score))
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(scoreColor(row.score).opacity(0.1))
                .cornerRadius(6)
            }

            // Attendance
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.checkmark").font(.caption2).foregroundColor(.teal)
                Text("Check-in: \(row.checkin_days)/5 days").font(.caption).foregroundColor(.secondary)
            }

            // Activity metrics row 1
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    weekPill("Obs",  row.obs_total,   prev?.obs_total,   color: .blue)
                    weekPill("TBT",  row.tbt,         prev?.tbt,         color: .purple)
                    weekPill("NM",   row.nm,          prev?.nm,          color: .red)
                    weekPill("JSO",  row.jso,         prev?.jso,         color: .teal)
                    weekPill("BBS",  row.bbs,         prev?.bbs,         color: .orange)
                    weekPill("PTW",  row.ptw,         prev?.ptw,         color: .mint)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func weekPill(_ label: String, _ val: Int, _ prev: Int?, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(val)").font(.caption).fontWeight(.semibold).foregroundColor(color)
            if let p = prev, val != p {
                Image(systemName: val > p ? "arrow.up" : "arrow.down")
                    .font(.system(size: 7))
                    .foregroundColor(val > p ? .green : .red)
            }
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(6)
    }

    private func scoreColor(_ s: Double) -> Color {
        s >= 20 ? .green : s >= 10 ? .orange : .red
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { report = try await NetworkManager.shared.getHseWeeklyReport() }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}
