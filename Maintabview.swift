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
    var body: some View {
        TabView {
            SupervisorHomeView(showQuickActions: true)
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
            EmployeesListView()
                .tabItem { Label("الموظفون", systemImage: "person.2.fill") }
            AttendanceView()
                .tabItem { Label("الحضور", systemImage: "calendar.badge.checkmark") }
            HSEDashboardView()
                .tabItem { Label("HSE", systemImage: "shield.checkered") }
            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#16a34a"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ── Admin + HSE Dashboard ────────────────────────────────────────────
struct AdminHSETabView: View {
    var body: some View {
        TabView {
            AdminDashboardView()
                .tabItem { Label("الرئيسية", systemImage: "chart.bar.fill") }

            HSEDashboardView()
                .tabItem { Label("HSE", systemImage: "shield.checkered") }

            EmployeesListView()
                .tabItem { Label("الموظفون", systemImage: "person.2.fill") }

            AdminReportsView()
                .tabItem { Label("التقارير", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationView { AdminManagementView() }
                .tabItem { Label("إدارة", systemImage: "gearshape.2.fill") }
        }
        .accentColor(Color(hex: "#7b5ea7"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct AdminManagementView: View {
    var body: some View {
        List {
            Section(header: Text("الطاقم")) {
                NavigationLink(destination: SupervisorsRankingView()) {
                    Label("ترتيب المشرفين", systemImage: "person.3.fill")
                }
                NavigationLink(destination: AdminUsersView()) {
                    Label("المستخدمون", systemImage: "person.badge.key.fill")
                }
            }
            Section(header: Text("التشغيل")) {
                NavigationLink(destination: AdminAttendanceView()) {
                    Label("الحضور", systemImage: "calendar.badge.checkmark")
                }
            }
            Section(header: Text("التواصل")) {
                NavigationLink(destination: AdminNotifyView()) {
                    Label("إرسال إشعار", systemImage: "bell.badge.fill")
                }
            }
            Section {
                NavigationLink(destination: ProfileView()) {
                    Label("حسابي", systemImage: "person.circle")
                }
            }
        }
        .navigationTitle("الإدارة")
    }
}

// ── Site Supervisor + HSE Dashboard ─────────────────────────────────
struct SiteSupervisorHSETabView: View {
    var body: some View {
        TabView {
            NavigationView { SiteDashboardView() }
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
            NavigationView { SiteSupervisorsListView() }
                .tabItem { Label("مشرفوني", systemImage: "person.3.fill") }
            NavigationView { SiteAttendanceView() }
                .tabItem { Label("الحضور", systemImage: "calendar.badge.checkmark") }
            NavigationView { SiteReportsView() }
                .tabItem { Label("التقارير", systemImage: "chart.bar.fill") }
            SiteMoreView(showHSE: true)
                .tabItem { Label("المزيد", systemImage: "ellipsis.circle.fill") }
        }
        .accentColor(Color(hex: "#6C63FF"))
        .environment(\.layoutDirection, .rightToLeft)
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
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }

            EmployeesListView()
                .tabItem { Label("الموظفون", systemImage: "person.2.fill") }

            AttendanceView()
                .tabItem { Label("الحضور", systemImage: "calendar.badge.checkmark") }

            MyRequestsView()
                .tabItem { Label("طلباتي", systemImage: "doc.text.fill") }
                .badge(pendingCount)

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#4f8ef7"))
        .environment(\.layoutDirection, .rightToLeft)
        .task { await loadBadge() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRequests"))) { _ in
            Task { await loadBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadBadge() }
        }
    }

    private func loadBadge() async {
        let reqs = (try? await NetworkManager.shared.getMyRequestsCached()) ?? []
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
                .tabItem { Label("الرئيسية", systemImage: "chart.bar.fill") }

            AdminRequestsView()
                .tabItem { Label("الطلبات", systemImage: "tray.full.fill") }
                .badge(pendingCount)

            AdminReportsView()
                .tabItem { Label("التقارير", systemImage: "chart.line.uptrend.xyaxis") }

            EmployeesListView()
                .tabItem { Label("الموظفون", systemImage: "person.2.fill") }

            NavigationView { AdminManagementView() }
                .tabItem { Label("إدارة", systemImage: "gearshape.2.fill") }
        }
        .accentColor(Color(hex: "#7b5ea7"))
        .environment(\.layoutDirection, .rightToLeft)
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
                .tabItem { Label("المهام", systemImage: "tray.fill") }
                .badge(pendingCount)

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#2ecc71"))
        .environment(\.layoutDirection, .rightToLeft)
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
