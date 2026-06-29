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
                .tabItem { Label("Monitor", systemImage: "list.bullet.clipboard.fill") }

            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "tray.fill") }
                .badge(pendingRequests)

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
                NavigationLink(destination: HSEObservationsView(allowEditing: false)) {
                    Label("Observations", systemImage: "eye.fill")
                }
                NavigationLink(destination: HSETbtView(allowEditing: false)) {
                    Label("TBT", systemImage: "person.2.badge.gearshape")
                }
                NavigationLink(destination: HSENearMissView(allowEditing: false)) {
                    Label("Near Miss", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                NavigationLink(destination: SafetySupJsoView()) {
                    Label("JSO Closures", systemImage: "doc.badge.plus")
                        .foregroundColor(.teal)
                }
                NavigationLink(destination: SafetySupBbsView()) {
                    Label("BBS Cards", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.orange)
                }
                NavigationLink(destination: SafetySupPtwView()) {
                    Label("PTW", systemImage: "key.fill")
                        .foregroundColor(.mint)
                }
                NavigationLink(destination: SafetySupManpowerView()) {
                    Label("Manpower", systemImage: "person.3.sequence.fill")
                        .foregroundColor(.blue)
                }
                NavigationLink(destination: SafetySupInspectionView()) {
                    Label("Inspections", systemImage: "checklist")
                        .foregroundColor(.indigo)
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
    @State private var highRisk:     [HseHighRiskItem] = []
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
                                    NavigationLink(destination: OfficerDetailView(officerId: officer.id,
                                                                                   officerName: officer.name.isEmpty ? officer.code : officer.name)) {
                                        OfficerStatRow(officer: officer)
                                    }
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
    @State private var report: HseWeeklyReport? = nil
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
                        let prevMap: [Int: HseReportRow] = rep.prev_rows.map {
                            Dictionary(uniqueKeysWithValues: $0.map { ($0.officer_id, $0) })
                        } ?? [:]
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
    private func weeklyRow(_ row: HseReportRow, prev: HseReportRow?) -> some View {
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

// ═══════════════════════════════════════════════════
//  MARK: - Officer Detail View
// ═══════════════════════════════════════════════════
struct OfficerDetailView: View {
    let officerId:   Int
    let officerName: String

    @State private var detail:    HseOfficerDetailResponse? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""
    @State private var days       = 30

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !errorMsg.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle).foregroundColor(.orange)
                    Text(errorMsg).font(.caption).foregroundColor(.secondary)
                    Button("Retry") { Task { await load() } }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = detail {
                List {
                    // Today's status
                    Section(header: Text("Today")) {
                        if let ci = d.checkin_today {
                            Label("Checked in · \(ci.location ?? "—")",
                                  systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("No location today", systemImage: "xmark.circle")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Summary counters
                    Section(header: Text("Last \(days) Days")) {
                        summaryGrid(d)
                    }

                    // Observations
                    if !d.observations.isEmpty {
                        Section(header: Label("Observations (\(d.observations.count))",
                                              systemImage: "eye.fill")) {
                            ForEach(d.observations.prefix(10)) { obs in
                                obsRow(obs)
                            }
                        }
                    }

                    // TBTs
                    if !d.tbts.isEmpty {
                        Section(header: Label("TBT (\(d.tbts.count))",
                                              systemImage: "person.2.badge.gearshape")) {
                            ForEach(d.tbts.prefix(10)) { t in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.topic).font(.subheadline).fontWeight(.medium)
                                    HStack(spacing: 10) {
                                        Text(t.date).font(.caption2).foregroundColor(.secondary)
                                        Text("\(t.attendee_count) attendees")
                                            .font(.caption2).foregroundColor(.purple)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Near Misses
                    if !d.near_misses.isEmpty {
                        Section(header: Label("Near Miss (\(d.near_misses.count))",
                                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)) {
                            ForEach(d.near_misses.prefix(5)) { nm in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nm.description).font(.subheadline)
                                        .lineLimit(2)
                                    Text(nm.date).font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // JSO
                    if !d.jso_closures.isEmpty {
                        Section(header: Label("JSO Closures (\(d.jso_closures.count))",
                                              systemImage: "doc.badge.plus")) {
                            ForEach(d.jso_closures.prefix(10)) { j in
                                HStack {
                                    Text(j.jso_number).font(.subheadline).fontWeight(.medium)
                                    Spacer()
                                    Text(j.date).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Period picker
                    Section {
                        Picker("Period", selection: $days) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: days) { _ in Task { await load() } }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(officerName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func summaryGrid(_ d: HseOfficerDetailResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            miniStat("Obs",  d.observations.count,  .blue)
            miniStat("TBT",  d.tbts.count,          .purple)
            miniStat("NM",   d.near_misses.count,   d.near_misses.isEmpty ? .secondary : .red)
            miniStat("JSO",  d.jso_closures.count,  .teal)
            miniStat("BBS",  d.bbs.reduce(0) { $0 + $1.card_count }, .orange)
            miniStat("Days", d.checkin_history.count, .green)
        }
    }

    @ViewBuilder
    private func miniStat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.07))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func obsRow(_ obs: HseObservationItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(obs.risk_level == "H" ? Color.red :
                      obs.risk_level == "M" ? Color.orange : Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(obs.description).font(.subheadline).lineLimit(2)
                HStack(spacing: 8) {
                    Text(obs.date).font(.caption2).foregroundColor(.secondary)
                    Text(obs.obs_type.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2).foregroundColor(.secondary)
                    Text(obs.status == "open" ? "Open" : "Closed")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(obs.status == "open" ? .orange : .green)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { detail = try await NetworkManager.shared.hseOfficerDetail(officerId: officerId, days: days) }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor JSO List
// ═══════════════════════════════════════════════════
struct SafetySupJsoView: View {
    @State private var items: [HseJsoItem] = []
    @State private var page  = 1
    @State private var pages = 1
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading && items.isEmpty {
                Section { ProgressView() }
            } else if items.isEmpty {
                Section { Text("No JSO records.").foregroundColor(.secondary) }
            } else {
                ForEach(items) { j in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("JSO #\(j.jso_number)").font(.headline)
                            Spacer()
                            Text(j.date).font(.caption2).foregroundColor(.secondary)
                        }
                        if let off = j.officer_name, !off.isEmpty {
                            Text(off).font(.caption).foregroundColor(.teal)
                        }
                        if !j.location.isEmpty {
                            Text("📍 \(j.location)").font(.caption).foregroundColor(.secondary)
                        }
                        if !j.action_taken.isEmpty {
                            Text(j.action_taken).font(.caption).foregroundColor(.secondary).lineLimit(2)
                        }
                    }
                    .padding(.vertical, 3)
                }
                if page < pages {
                    Button("Load more") { Task { await loadMore() } }
                        .font(.caption).frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("JSO Closures")
        .refreshable { await reset() }
        .task { await reset() }
    }

    private func reset() async {
        page = 1; items = []
        await load()
    }
    private func loadMore() async {
        page += 1; await load()
    }
    private func load() async {
        isLoading = true
        if let resp = try? await NetworkManager.shared.hseJsoList(page: page) {
            items += resp.items; pages = resp.pages
        }
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor BBS List
// ═══════════════════════════════════════════════════
struct SafetySupBbsView: View {
    @State private var items: [HseBbsItem] = []
    @State private var isLoading = true

    private var total: Int { items.reduce(0) { $0 + $1.card_count } }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else {
                Section(header: Text("Total cards: \(total)")) {
                    EmptyView()
                }
                .listRowBackground(Color.clear)

                if items.isEmpty {
                    Section { Text("No BBS records.").foregroundColor(.secondary) }
                } else {
                    ForEach(items) { b in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let off = b.officer_name, !off.isEmpty {
                                    Text(off).font(.subheadline).fontWeight(.medium)
                                }
                                Text(b.date).font(.caption).foregroundColor(.secondary)
                                if !b.notes.isEmpty {
                                    Text(b.notes).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(b.card_count)").font(.title3).fontWeight(.bold).foregroundColor(.orange)
                                Text("cards").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("BBS Cards")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.hseBbsList()) ?? []
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor PTW List
// ═══════════════════════════════════════════════════
struct SafetySupPtwView: View {
    @State private var items: [HsePtwItem] = []
    @State private var isLoading = true

    private var active: [HsePtwItem] { items.filter { !$0.expired } }
    private var expired: [HsePtwItem] { items.filter { $0.expired } }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else if items.isEmpty {
                Section { Text("No PTW records.").foregroundColor(.secondary) }
            } else {
                if !active.isEmpty {
                    Section(header: Text("Active (\(active.count))")) {
                        ForEach(active) { ptwRow($0) }
                    }
                }
                if !expired.isEmpty {
                    Section(header: Text("Expired (\(expired.count))")) {
                        ForEach(expired) { ptwRow($0) }
                    }
                }
            }
        }
        .navigationTitle("PTW")
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private func ptwRow(_ p: HsePtwItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(p.permit_number).font(.headline)
                Spacer()
                Text(p.status.uppercased())
                    .font(.caption2).fontWeight(.bold)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(p.status == "active" ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .foregroundColor(p.status == "active" ? .green : .secondary)
                    .cornerRadius(5)
            }
            if let off = p.officer_name, !off.isEmpty {
                Text(off).font(.caption).foregroundColor(.mint)
            }
            HStack(spacing: 8) {
                Text(p.permit_type).font(.caption).foregroundColor(.secondary)
                Text("\(p.week_start) → \(p.week_end)").font(.caption2).foregroundColor(.secondary)
            }
            if !p.location.isEmpty {
                Text("📍 \(p.location)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.hsePtwList()) ?? []
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor Manpower List
// ═══════════════════════════════════════════════════
struct SafetySupManpowerView: View {
    @State private var items: [HseManpowerItem] = []
    @State private var isLoading = true

    private var totalToday: Int {
        let today = Date().iso
        return items.filter { $0.date == today }.reduce(0) { $0 + $1.total_count }
    }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else {
                if totalToday > 0 {
                    Section(header: Text("Today: \(totalToday) workers")) {
                        EmptyView()
                    }
                    .listRowBackground(Color.clear)
                }
                if items.isEmpty {
                    Section { Text("No manpower records.").foregroundColor(.secondary) }
                } else {
                    ForEach(items) { m in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let off = m.officer_name, !off.isEmpty {
                                        Text(off).font(.subheadline).fontWeight(.medium)
                                    }
                                    Text(m.date).font(.caption).foregroundColor(.secondary)
                                    if !m.location.isEmpty {
                                        Text("📍 \(m.location)").font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(m.total_count)").font(.title3).fontWeight(.bold).foregroundColor(.blue)
                                    Text("workers").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            if let bd = m.breakdown, !bd.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(bd.sorted { $0.key < $1.key }, id: \.key) { k, v in
                                            Text("\(k): \(v)")
                                                .font(.caption2)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.08))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Manpower")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.hseManpowerHistory()) ?? []
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor Inspection List
// ═══════════════════════════════════════════════════
struct SafetySupInspectionView: View {
    @State private var items: [HseInspectionHistoryItem] = []
    @State private var isLoading = true

    private var avgScore: Double {
        let scored = items.compactMap { $0.overall_score }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0, +) / Double(scored.count)
    }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else {
                if !items.isEmpty {
                    Section(header: Text(String(format: "Avg score: %.1f%%", avgScore))) {
                        EmptyView()
                    }
                    .listRowBackground(Color.clear)
                }
                if items.isEmpty {
                    Section { Text("No inspection records.").foregroundColor(.secondary) }
                } else {
                    ForEach(items) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let off = r.officer_name, !off.isEmpty {
                                    Text(off).font(.subheadline).fontWeight(.medium)
                                }
                                Text(r.date).font(.caption).foregroundColor(.secondary)
                                if !r.location.isEmpty {
                                    Text("📍 \(r.location)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let score = r.overall_score {
                                VStack(alignment: .trailing) {
                                    Text(String(format: "%.0f%%", score))
                                        .font(.title3).fontWeight(.bold)
                                        .foregroundColor(score >= 80 ? .green : score >= 60 ? .orange : .red)
                                    Text("score").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Inspections")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.hseInspectionHistory()) ?? []
        isLoading = false
    }
}
