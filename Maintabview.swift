import SwiftUI
import Combine

struct MainTabView: View {
    private var user: AppUser? { SessionManager.shared.currentUser }
    private var hasHseAccess: Bool { user?.hse_access == true }
    private var companyName: String? { user?.company_name }

    var body: some View {
        let role = user?.role ?? ""
        VStack(spacing: 0) {
            // Company banner — shown for non-NSH tenants (not for super_admin)
            if let name = companyName,
               !name.isEmpty,
               name != "Nasser S. Al-Hajri Corporation",
               user?.role != "super_admin" {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.caption2)
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(hex: "#2563eb"))
            }

            Group {
                if role == "super_admin" {
                    AnyView(SuperAdminTabView())
                } else if role == "admin" {
                    hasHseAccess ? AnyView(AdminHSETabView()) : AnyView(AdminTabView())
                } else if role == "hr" {
                    AnyView(HRTabView())
                } else if role == "site_supervisor" {
                    hasHseAccess ? AnyView(SiteSupervisorHSETabView()) : AnyView(SiteSupervisorTabView())
                } else if role == "safety_officer" {
                    AnyView(HSEOfficerTabView())
                } else if role == "safety_supervisor" {
                    AnyView(SafetySupervisorTabView())
                } else {
                    hasHseAccess ? AnyView(HSESupervisorTabView()) : AnyView(SupervisorTabView())
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// ── Supervisor + HSE Dashboard ───────────────────────────────────────
struct HSESupervisorTabView: View {
    @State private var pendingCount = 0

    var body: some View {
        TabView {
            SupervisorHomeView(showQuickActions: true)
                .tabItem { Label("Home", systemImage: "house.fill") }
            EmployeesListView()
                .tabItem { Label("Employees", systemImage: "person.2.fill") }
            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "doc.text.fill") }
                .badge(pendingCount)
            HSEDashboardView()
                .tabItem { Label("HSE", systemImage: "shield.checkered") }
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
        pendingCount = reqs.filter { $0.status == "pending" }.count
    }
}

// ── Admin + HSE Dashboard ────────────────────────────────────────────
struct AdminHSETabView: View {
    @State private var pendingCount = 0

    var body: some View {
        TabView {
            AdminDashboardView()
                .tabItem { Label("Home", systemImage: "chart.bar.fill") }

            AdminRequestsView()
                .tabItem { Label("Requests", systemImage: "tray.full.fill") }
                .badge(pendingCount)

            EmployeesListView()
                .tabItem { Label("Employees", systemImage: "person.2.fill") }

            HSEDashboardView()
                .tabItem { Label("HSE", systemImage: "shield.checkered") }

            NavigationView { AdminManagementView() }
                .tabItem { Label("Manage", systemImage: "gearshape.2.fill") }
        }
        .accentColor(Color(hex: "#7b5ea7"))
        .task { await loadBadge() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await loadBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadBadge() }
        }
    }

    private func loadBadge() async {
        let reqs = (try? await NetworkManager.shared.getAdminRequests(status: "pending")) ?? []
        pendingCount = reqs.count
    }
}

struct AdminManagementView: View {
    var body: some View {
        List {
            Section(header: Text("Team")) {
                NavigationLink(destination: SupervisorsRankingView()) {
                    Label("Supervisors Ranking", systemImage: "person.3.fill")
                }
                NavigationLink(destination: AdminUsersView()) {
                    Label("Users", systemImage: "person.badge.key.fill")
                }
            }
            Section(header: Text("Operations")) {
                NavigationLink(destination: AdminAttendanceView()) {
                    Label("Attendance", systemImage: "calendar.badge.checkmark")
                }
                NavigationLink(destination: AdminReportsView()) {
                    Label("Reports", systemImage: "chart.line.uptrend.xyaxis")
                }
                NavigationLink(destination: UserLocationView()) {
                    Label("Locations", systemImage: "location.fill")
                }
            }
            Section(header: Text("Communication")) {
                NavigationLink(destination: AdminNotifyView()) {
                    Label("Send Notification", systemImage: "bell.badge.fill")
                }
            }
            Section(header: Text("HSE")) {
                NavigationLink(destination: AdminHseAccessView()) {
                    Label("HSE Supervisor Access", systemImage: "shield.lefthalf.filled")
                }
            }
            Section {
                NavigationLink(destination: ProfileView()) {
                    Label("Profile", systemImage: "person.circle")
                }
            }
        }
        .navigationTitle("Management")
    }
}

// ── Site Supervisor + HSE Dashboard ─────────────────────────────────
struct SiteSupervisorHSETabView: View {
    var body: some View {
        TabView {
            NavigationView { SiteDashboardView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationView { SiteSupervisorsListView() }
                .tabItem { Label("Supervisors", systemImage: "person.3.fill") }
            NavigationView { SiteAttendanceView() }
                .tabItem { Label("Attendance", systemImage: "calendar.badge.checkmark") }
            NavigationView { SiteReportsView() }
                .tabItem { Label("Reports", systemImage: "chart.bar.fill") }
            SiteMoreView(showHSE: true)
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .accentColor(Color(hex: "#6C63FF"))
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - السوبرفايزر
// ═══════════════════════════════════════════════════
struct SupervisorTabView: View {
    @State private var pendingCount = 0

    var body: some View {
        TabView {
            SupervisorHomeView(showQuickActions: false)
                .tabItem { Label("Home", systemImage: "house.fill") }

            EmployeesListView()
                .tabItem { Label("Employees", systemImage: "person.2.fill") }

            AttendanceView()
                .tabItem { Label("Attendance", systemImage: "calendar.badge.checkmark") }

            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "doc.text.fill") }
                .badge(pendingCount)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#4f8ef7"))
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
        pendingCount = reqs.filter { $0.status == "pending" }.count
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - الأدمن
// ═══════════════════════════════════════════════════
struct AdminTabView: View {
    @State private var pendingCount = 0

    var body: some View {
        TabView {
            AdminDashboardView()
                .tabItem { Label("Home", systemImage: "chart.bar.fill") }

            AdminRequestsView()
                .tabItem { Label("Requests", systemImage: "tray.full.fill") }
                .badge(pendingCount)

            EmployeesListView()
                .tabItem { Label("Employees", systemImage: "person.2.fill") }

            AdminReportsView()
                .tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationView { AdminManagementView() }
                .tabItem { Label("Manage", systemImage: "gearshape.2.fill") }
        }
        .accentColor(Color(hex: "#7b5ea7"))
        .task { await loadBadge() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await loadBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadBadge() }
        }
    }

    private func loadBadge() async {
        let reqs = (try? await NetworkManager.shared.getAdminRequests(status: "pending")) ?? []
        pendingCount = reqs.count
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - HR
// ═══════════════════════════════════════════════════
struct HRTabView: View {
    @State private var pendingCount = 0

    var body: some View {
        TabView {
            HRInboxView()
                .tabItem { Label("Tasks", systemImage: "tray.fill") }
                .badge(pendingCount)

            EmployeesListView()
                .tabItem { Label("Employees", systemImage: "person.2.fill") }

            AdminReportsView()
                .tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#2ecc71"))
        .task { await loadBadge() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await loadBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadBadge() }
        }
    }

    private func loadBadge() async {
        let tasks = (try? await NetworkManager.shared.getHRTasks()) ?? []
        pendingCount = tasks.filter { $0.status == "pending" }.count
    }
}

// ✅ ملاحظة: SiteSupervisorTabView معرّف في SiteSupervisorViews.swift
// ✅ ملاحظة: SuperAdminTabView معرّف في SuperAdminViews.swift
// ✅ ملاحظة: SACompany معرّفة في SuperAdminViews.swift
