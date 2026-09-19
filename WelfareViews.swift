import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════
//  MARK: - Welfare Officer Tab
// ═══════════════════════════════════════════════════
struct WelfareOfficerTabView: View {
    var body: some View {
        TabView {
            NavigationView { WelfareOfficerHomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationView { WelfareObservationsListView() }
                .tabItem { Label("Observations", systemImage: "eye.fill") }
            NavigationView { WelfareReportsListView() }
                .tabItem { Label("Reports", systemImage: "doc.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#0ea5e9"))
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Environment Officer Tab
// ═══════════════════════════════════════════════════
struct EnvOfficerTabView: View {
    var body: some View {
        TabView {
            NavigationView { WelfareOfficerHomeView(isEnv: true) }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationView { WelfareObservationsListView() }
                .tabItem { Label("Observations", systemImage: "eye.fill") }
            NavigationView { WelfareReportsListView() }
                .tabItem { Label("Reports", systemImage: "doc.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#16a34a"))
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Welfare Supervisor Tab
// ═══════════════════════════════════════════════════
struct WelfareSupervisorTabView: View {
    var body: some View {
        TabView {
            NavigationView { WelfareSupervisorDashView() }
                .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
            NavigationView { WelfareSupervisorAllView() }
                .tabItem { Label("Monitor", systemImage: "list.bullet.clipboard.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#7c3aed"))
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Officer Home
// ═══════════════════════════════════════════════════
struct WelfareOfficerHomeView: View {
    var isEnv: Bool = false
    @State private var obsCount  = 0
    @State private var rptCount  = 0
    @State private var isLoading = true

    var color: Color { isEnv ? Color(hex: "#16a34a") : Color(hex: "#0ea5e9") }
    var roleLabel: String { isEnv ? "Environment Officer" : "Welfare Officer" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WelfareHeaderCard(roleLabel: roleLabel, color: color,
                                  obsCount: obsCount, rptCount: rptCount, isLoading: isLoading)

                VStack(spacing: 12) {
                    Text("Quick Actions").font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NavigationLink(destination: WelfareNewObsView()) {
                            WelfareActionCard(title: "New Observation", icon: "plus.circle.fill", color: .orange)
                        }
                        NavigationLink(destination: WelfareObservationsListView()) {
                            WelfareActionCard(title: "My Observations", icon: "eye.fill", color: color)
                        }
                        NavigationLink(destination: WelfareUploadReportView()) {
                            WelfareActionCard(title: "Upload Report", icon: "arrow.up.doc.fill", color: .blue)
                        }
                        NavigationLink(destination: WelfareReportsListView()) {
                            WelfareActionCard(title: "My Reports", icon: "doc.fill", color: .purple)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(roleLabel)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        let page = (try? await NetworkManager.shared.welfareObservations(page: 1))
        let rpts = (try? await NetworkManager.shared.welfareReports())
        obsCount = page?.total ?? 0
        rptCount = rpts?.count ?? 0
        isLoading = false
    }
}

private struct WelfareHeaderCard: View {
    let roleLabel: String
    let color: Color
    let obsCount: Int
    let rptCount: Int
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roleLabel).font(.headline).foregroundColor(.white)
                    if let user = SessionManager.shared.currentUser {
                        Text(user.name).font(.subheadline).foregroundColor(.white.opacity(0.8))
                    }
                }
                Spacer()
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.largeTitle).foregroundColor(.white.opacity(0.7))
            }
            Divider().background(Color.white.opacity(0.3))
            HStack {
                WelfareStatPill(label: "Observations", value: isLoading ? "-" : "\(obsCount)")
                Spacer()
                WelfareStatPill(label: "Reports Uploaded", value: isLoading ? "-" : "\(rptCount)")
            }
        }
        .padding()
        .background(color)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

private struct WelfareStatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.8))
        }
    }
}

private struct WelfareActionCard: View {
    let title: String
    let icon:  String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(title).font(.subheadline.bold()).foregroundColor(.primary).lineLimit(2)
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - New Observation
// ═══════════════════════════════════════════════════
struct WelfareNewObsView: View {
    @State private var date        = Date()
    @State private var location    = ""
    @State private var obsType     = "unsafe_condition"
    @State private var category    = ""
    @State private var riskLevel   = "L"
    @State private var description = ""
    @State private var actionTaken = ""
    @State private var isBusy      = false
    @State private var errorMsg    = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var photoImg: Image? = nil
    @State private var createdObsId: Int? = nil
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private let obsTypes   = ["unsafe_condition", "unsafe_act", "near_miss", "positive_observation"]
    private let riskLevels = [("L","Low"), ("M","Medium"), ("H","High")]

    var body: some View {
        Form {
            Section("Details") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Location", text: $location)
                Picker("Type", selection: $obsType) {
                    ForEach(obsTypes, id: \.self) { t in Text(t.replacingOccurrences(of: "_", with: " ").capitalized).tag(t) }
                }
                TextField("Category (optional)", text: $category)
                Picker("Risk Level", selection: $riskLevel) {
                    ForEach(riskLevels, id: \.0) { r in Text(r.1).tag(r.0) }
                }
            }
            Section("Description") {
                TextField("Describe the observation...", text: $description, axis: .vertical)
                    .lineLimit(4...8)
            }
            Section("Action Taken") {
                TextField("What was done immediately?", text: $actionTaken, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section("Photo (optional)") {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                }
                if let img = photoImg {
                    img.resizable().scaledToFit().frame(maxHeight: 180).cornerRadius(8)
                }
            }
            if !errorMsg.isEmpty {
                Section { Text(errorMsg).foregroundColor(.red).font(.caption) }
            }
        }
        .navigationTitle("New Observation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isBusy { ProgressView() }
                else { Button("Submit") { Task { await submit() } }.disabled(description.isEmpty) }
            }
        }
        .onChange(of: photoItem) { item in
            Task {
                guard let item else { return }
                if let d = try? await item.loadTransferable(type: Data.self) {
                    photoData = d
                    if let ui = UIImage(data: d) { photoImg = Image(uiImage: ui) }
                }
            }
        }
        .alert("Submitted!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: { Text("Observation recorded successfully.") }
    }

    private func submit() async {
        isBusy = true; errorMsg = ""
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let params: [String: String] = [
            "date": df.string(from: date),
            "location": location,
            "obs_type": obsType,
            "category": category,
            "risk_level": riskLevel,
            "description": description,
            "action_taken": actionTaken,
        ]
        do {
            let res = try await NetworkManager.shared.welfareCreateObservation(params: params)
            if let id = res["id"], let pd = photoData {
                try? await NetworkManager.shared.welfareUploadObsPhoto(obsId: id, imageData: pd, ext: "jpg")
            }
            showSuccess = true
        } catch { errorMsg = error.localizedDescription }
        isBusy = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Observations List
// ═══════════════════════════════════════════════════
struct WelfareObservationsListView: View {
    @State private var items: [WelfareObsItem] = []
    @State private var isLoading = true
    @State private var page = 1
    @State private var totalPages = 1

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView("Loading...").frame(maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.largeTitle).foregroundColor(.secondary)
                    Text("No observations yet").foregroundColor(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { obs in
                        NavigationLink(destination: WelfareObsDetailView(obs: obs)) {
                            WelfareObsRow(obs: obs)
                        }
                    }
                    if page < totalPages {
                        HStack { Spacer(); Button("Load more") { Task { await loadMore() } }; Spacer() }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Observations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: WelfareNewObsView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await load() }
        .refreshable { page = 1; await load() }
    }

    private func load() async {
        isLoading = true
        if let r = try? await NetworkManager.shared.welfareObservations(page: page) {
            if page == 1 { items = r.items } else { items += r.items }
            totalPages = r.pages
        }
        isLoading = false
    }

    private func loadMore() async {
        page += 1; await load()
    }
}

private struct WelfareObsRow: View {
    let obs: WelfareObsItem
    var statusColor: Color {
        obs.status == "closed" ? .green : .orange
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(obs.date).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(obs.status.capitalized).font(.caption.bold()).foregroundColor(statusColor)
            }
            Text(obs.description).font(.subheadline).lineLimit(2)
            if !obs.location.isEmpty {
                Label(obs.location, systemImage: "mappin.circle").font(.caption).foregroundColor(.secondary)
            }
            HStack {
                WelfareRiskBadge(level: obs.risk_level)
                Text(obs.obs_type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

private struct WelfareRiskBadge: View {
    let level: String
    var color: Color {
        switch level { case "H": return .red; case "M": return .orange; default: return .green }
    }
    var body: some View {
        Text(level == "H" ? "High" : level == "M" ? "Medium" : "Low")
            .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(4)
    }
}

struct WelfareObsDetailView: View {
    let obs: WelfareObsItem
    var body: some View {
        List {
            Section("Observation") {
                WelfareLabelRow("Date", obs.date)
                WelfareLabelRow("Type", obs.obs_type.replacingOccurrences(of:"_",with:" ").capitalized)
                WelfareLabelRow("Location", obs.location)
                WelfareLabelRow("Risk Level", obs.risk_level == "H" ? "High" : obs.risk_level == "M" ? "Medium" : "Low")
                if !obs.category.isEmpty { WelfareLabelRow("Category", obs.category) }
                WelfareLabelRow("Status", obs.status.capitalized)
            }
            Section("Description") {
                Text(obs.description).font(.subheadline)
            }
            if !obs.action_taken.isEmpty {
                Section("Action Taken") {
                    Text(obs.action_taken).font(.subheadline)
                }
            }
            if !obs.photos.isEmpty {
                Section("Photos") {
                    ForEach(obs.photos, id: \.path) { p in
                        AsyncImage(url: URL(string: "\(BASE_URL)/static/hse_photos/\(p.path)")) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit().cornerRadius(8)
                            default: Color(.systemGray5).frame(height: 100).cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Observation Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WelfareLabelRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Upload PDF Report
// ═══════════════════════════════════════════════════
struct WelfareUploadReportView: View {
    @State private var reportType  = ""
    @State private var reportDate  = Date()
    @State private var notes       = ""
    @State private var pdfItem: FileItem? = nil
    @State private var isBusy      = false
    @State private var errorMsg    = ""
    @State private var showPicker  = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    struct FileItem { let url: URL; let data: Data }

    var body: some View {
        Form {
            Section("Report Info") {
                TextField("Report Type (e.g. Weekly, Monthly)", text: $reportType)
                DatePicker("Report Date", selection: $reportDate, displayedComponents: .date)
                TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            Section("PDF File") {
                if let f = pdfItem {
                    Label(f.url.lastPathComponent, systemImage: "doc.fill").foregroundColor(.blue)
                    Button("Change File") { showPicker = true }
                } else {
                    Button { showPicker = true } label: {
                        Label("Select PDF", systemImage: "arrow.up.doc.fill")
                    }
                }
            }
            if !errorMsg.isEmpty {
                Section { Text(errorMsg).foregroundColor(.red).font(.caption) }
            }
        }
        .navigationTitle("Upload Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isBusy { ProgressView() }
                else { Button("Upload") { Task { await upload() } }.disabled(pdfItem == nil) }
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                url.startAccessingSecurityScopedResource()
                if let d = try? Data(contentsOf: url) {
                    pdfItem = FileItem(url: url, data: d)
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
        .alert("Uploaded!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: { Text("Report uploaded successfully.") }
    }

    private func upload() async {
        guard let f = pdfItem else { return }
        isBusy = true; errorMsg = ""
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        do {
            _ = try await NetworkManager.shared.welfareUploadReport(
                pdfData: f.data,
                filename: f.url.lastPathComponent,
                reportType: reportType,
                reportDate: df.string(from: reportDate),
                notes: notes
            )
            showSuccess = true
        } catch { errorMsg = error.localizedDescription }
        isBusy = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Reports List
// ═══════════════════════════════════════════════════
struct WelfareReportsListView: View {
    @State private var items: [WelfareReportItem] = []
    @State private var isLoading = true
    @State private var pdfUrl: URL? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...").frame(maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc").font(.largeTitle).foregroundColor(.secondary)
                    Text("No reports uploaded yet").foregroundColor(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                List(items) { r in
                    Button { pdfUrl = NetworkManager.shared.welfareViewReport(rid: r.id) } label: {
                        WelfareReportRow(r: r)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Reports")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: WelfareUploadReportView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $pdfUrl) { url in SafariView(url: url) }
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.welfareReports()) ?? []
        isLoading = false
    }
}

private struct WelfareReportRow: View {
    let r: WelfareReportItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill").font(.title3).foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(r.report_type.isEmpty ? "Report" : r.report_type).font(.subheadline.bold())
                Text(r.report_date).font(.caption).foregroundColor(.secondary)
                if !r.notes.isEmpty { Text(r.notes).font(.caption).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor Dashboard
// ═══════════════════════════════════════════════════
struct WelfareSupervisorDashView: View {
    @State private var data: WelfareSupervisorData? = nil
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...").padding(.top, 60)
            } else if let d = data {
                VStack(spacing: 16) {
                    // KPI strip
                    HStack(spacing: 0) {
                        WelfareKpiBox(label: "Observations", value: "\(d.observations.count)", color: .blue)
                        Divider()
                        WelfareKpiBox(label: "Reports", value: "\(d.reports.count)", color: .purple)
                        Divider()
                        let open = d.observations.filter { $0.status != "closed" }.count
                        WelfareKpiBox(label: "Open", value: "\(open)", color: .orange)
                    }
                    .frame(height: 70)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                    .padding(.horizontal)

                    if !d.observations.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Observations").font(.headline).padding(.horizontal)
                            ForEach(d.observations.prefix(5)) { obs in
                                NavigationLink(destination: WelfareObsDetailView(obs: obs)) {
                                    WelfareObsRow(obs: obs).padding(.horizontal)
                                }
                                Divider().padding(.leading)
                            }
                        }
                        .background(Color(.systemBackground)).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Welfare Overview")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        data = try? await NetworkManager.shared.welfareSupervisorAll()
        isLoading = false
    }
}

private struct WelfareKpiBox: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor All View (full monitor)
// ═══════════════════════════════════════════════════
struct WelfareSupervisorAllView: View {
    @State private var data: WelfareSupervisorData? = nil
    @State private var isLoading = true
    @State private var roleFilter = ""
    @State private var tab = 0
    @State private var pdfUrl: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            // filters
            HStack {
                Picker("Role", selection: $roleFilter) {
                    Text("All").tag("")
                    Text("Welfare").tag("welfare")
                    Text("Environment").tag("environment")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal).padding(.vertical, 8)

            Picker("", selection: $tab) {
                Text("Observations").tag(0)
                Text("Reports").tag(1)
            }
            .pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 8)
            Divider()

            Group {
                if isLoading {
                    ProgressView("Loading...").frame(maxHeight: .infinity)
                } else if let d = data {
                    if tab == 0 {
                        List(d.observations) { obs in
                            NavigationLink(destination: WelfareObsDetailView(obs: obs)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(obs.officer_name).font(.caption.bold())
                                        Spacer()
                                        WelfareRiskBadge(level: obs.risk_level)
                                    }
                                    WelfareObsRow(obs: obs)
                                }
                            }
                        }
                        .listStyle(.plain)
                    } else {
                        List(d.reports) { r in
                            Button {
                                pdfUrl = NetworkManager.shared.welfareViewReport(rid: r.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(r.officer_name).font(.caption.bold())
                                        Spacer()
                                        Text(r.role_type.capitalized).font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color(.systemGray5)).cornerRadius(4)
                                    }
                                    WelfareSupervisorReportRow(r: r)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Monitor")
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: roleFilter) { _ in Task { await load() } }
        .sheet(item: $pdfUrl) { url in SafariView(url: url) }
    }

    private func load() async {
        isLoading = true
        data = try? await NetworkManager.shared.welfareSupervisorAll(role: roleFilter)
        isLoading = false
    }
}

private struct WelfareSupervisorReportRow: View {
    let r: WelfareSupervisorReport
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill").font(.title3).foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.report_type.isEmpty ? "Report" : r.report_type).font(.subheadline)
                Text(r.report_date).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
    }
}

