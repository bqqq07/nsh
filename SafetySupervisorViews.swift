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

            HSEDashboardView()
                .tabItem { Label("HSE", systemImage: "shield.checkered") }

            NavigationView { SafetySupMonitorView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.clipboard.fill") }

            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "tray.fill") }
                .badge(pendingRequests)

            UserLocationView()
                .tabItem { Label("Location", systemImage: "location.fill") }
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
                    Label("Check-in Today", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
                NavigationLink(destination: HSEObservationsView()) {
                    Label("Observations", systemImage: "eye.fill")
                }
                NavigationLink(destination: HSETbtView()) {
                    Label("TBT", systemImage: "person.2.badge.gearshape")
                }
            }
            Section {
                NavigationLink(destination: ProfileView()) {
                    Label("Profile", systemImage: "person.circle")
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
                            Text("\(checkedIn.count)").font(.title).fontWeight(.bold).foregroundColor(.green)
                            Text("In").font(.caption).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(notIn.count)").font(.title).fontWeight(.bold).foregroundColor(.red)
                            Text("Out").font(.caption).foregroundColor(.secondary)
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
                    Section(header: Text("Checked In (\(checkedIn.count))")) {
                        ForEach(checkedIn) { o in
                            checkinRow(o, isIn: true)
                        }
                    }
                }
                if !notIn.isEmpty {
                    Section(header: Text("Not In (\(notIn.count))")) {
                        ForEach(notIn) { o in
                            checkinRow(o, isIn: false)
                        }
                    }
                }
            }
        }
        .navigationTitle("Check-in Today")
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
            Text(isIn ? "✓ In" : "✗ Out")
                .font(.caption).fontWeight(.bold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isIn ? Color.green.opacity(0.15) : Color.red.opacity(0.1))
                .foregroundColor(isIn ? .green : .red)
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
    @State private var officers: [SafetyOfficerStat] = []
    @State private var isLoading = true
    @State private var errorMsg = ""

    private var checkedIn: Int { officers.filter { $0.checkedIn }.count }

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
                        // Summary header
                        Section {
                            HStack(spacing: 16) {
                                statCard(title: "Checked In", value: "\(checkedIn)/\(officers.count)",
                                         color: checkedIn == officers.count ? .green : .orange,
                                         icon: "checkmark.seal.fill")
                                statCard(title: "Officers", value: "\(officers.count)",
                                         color: .blue, icon: "person.3.fill")
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

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
            officers = try await NetworkManager.shared.getSafetyOfficers()
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

            HStack(spacing: 8) {
                pill("Obs", officer.obsWeek, color: .blue)
                pill("TBT", officer.tbtWeek, color: .purple)
                pill("NM", officer.nmWeek, color: .red)
                pill("Total", officer.totalWeek, color: officer.totalWeek > 0 ? .green : .gray)
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
