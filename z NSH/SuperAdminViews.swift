import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - Models
// ═══════════════════════════════════════════════════

struct SACompany: Codable, Identifiable {
    let id:          Int
    let name:        String
    let slug:        String
    let plan:        String
    let is_active:   Bool
    let owner_email: String?
    let user_count:  Int?
    let created_at:  String?
    let max_users:   Int?
    let users:       [SAUser]?
}

struct SAUser: Codable, Identifiable {
    let id:              Int
    let name:            String
    let role:            String
    let email:           String?
    let supervisor_code: String?
    let is_active:       Bool
}

struct SADashboard: Codable {
    let total_companies:  Int
    let active_companies: Int
    let pending_companies: Int
    let total_users:      Int
    let recent:           [SACompany]
    let pending:          [SACompany]
}

// ═══════════════════════════════════════════════════
//  MARK: - Network
// ═══════════════════════════════════════════════════

extension NetworkManager {
    func getSADashboard() async throws -> SADashboard {
        let (data, _) = try await session.data(for: makeRequest("/api/sa/dashboard"))
        return try JSONDecoder().decode(SADashboard.self, from: data)
    }
    func getSACompanies(q: String = "") async throws -> [SACompany] {
        let path = q.isEmpty ? "/api/sa/companies" : "/api/sa/companies?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        let (data, _) = try await session.data(for: makeRequest(path))
        return try JSONDecoder().decode([SACompany].self, from: data)
    }
    func getSACompany(_ id: Int) async throws -> SACompany {
        let (data, _) = try await session.data(for: makeRequest("/api/sa/companies/\(id)"))
        return try JSONDecoder().decode(SACompany.self, from: data)
    }
    func saActivate(_ id: Int) async throws {
        _ = try await session.data(for: makeRequest("/api/sa/companies/\(id)/activate", method: "POST"))
    }
    func saDeactivate(_ id: Int) async throws {
        _ = try await session.data(for: makeRequest("/api/sa/companies/\(id)/deactivate", method: "POST"))
    }
    func saCreateCompany(name: String, email: String, plan: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "name": name, "email": email, "plan": plan, "password": password
        ])
        let (_, resp) = try await session.data(for: makeRequest("/api/sa/companies/create", method: "POST", body: body))
        guard (resp as? HTTPURLResponse)?.statusCode == 201 else {
            throw NSError(domain: "SA", code: 0, userInfo: [NSLocalizedDescriptionKey: "فشل إنشاء الشركة"])
        }
    }
    func saDeleteCompany(_ id: Int) async throws {
        _ = try await session.data(for: makeRequest("/api/sa/companies/\(id)", method: "DELETE"))
    }

    // Public registration (no auth required)
    func saCreateCompanyPublic(name: String, email: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "name": name, "email": email, "password": password
        ])
        var req = URLRequest(url: URL(string: BASE_URL + "/api/register")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 201 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "فشل التسجيل"
            throw NSError(domain: msg, code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Tab Root
// ═══════════════════════════════════════════════════

struct SuperAdminTabView: View {
    var body: some View {
        TabView {
            NavigationView { SADashboardView() }
                .tabItem { Label("لوحة التحكم", systemImage: "gauge.with.dots.needle.50percent") }

            NavigationView { SACompaniesView() }
                .tabItem { Label("الشركات", systemImage: "building.2.fill") }

            NavigationView { SANewCompanyView() }
                .tabItem { Label("شركة جديدة", systemImage: "plus.square.fill") }

            NavigationView { SAProfileView() }
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#7c3aed"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Dashboard
// ═══════════════════════════════════════════════════

struct SADashboardView: View {
    @State private var dash: SADashboard?
    @State private var loading = true
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if loading {
                    ProgressView("جاري التحميل...")
                        .padding(.top, 60)
                } else if !error.isEmpty {
                    Text(error).foregroundColor(.red).padding()
                } else if let d = dash {
                    // KPI Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SAKpiCard(title: "إجمالي الشركات", value: "\(d.total_companies)", icon: "building.2.fill", color: .purple)
                        SAKpiCard(title: "نشطة", value: "\(d.active_companies)", icon: "checkmark.seal.fill", color: .green)
                        SAKpiCard(title: "بانتظار الموافقة", value: "\(d.pending_companies)", icon: "clock.fill", color: .orange)
                        SAKpiCard(title: "إجمالي المستخدمين", value: "\(d.total_users)", icon: "person.3.fill", color: .blue)
                    }
                    .padding(.horizontal)

                    // Pending approvals
                    if !d.pending.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("بانتظار الموافقة (\(d.pending.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(d.pending) { co in
                                NavigationLink(destination: SACompanyDetailView(companyId: co.id)) {
                                    SAPendingRow(co: co)
                                }
                            }
                        }
                    }

                    // Recent
                    if !d.recent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("أحدث الشركات")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(d.recent) { co in
                                NavigationLink(destination: SACompanyDetailView(companyId: co.id)) {
                                    SACompanyRow(co: co)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Super Admin")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true; error = ""
        do { dash = try await NetworkManager.shared.getSADashboard() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct SAKpiCard: View {
    let title: String
    let value: String
    let icon:  String
    let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.system(size: 28, weight: .bold))
            Text(title).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

struct SAPendingRow: View {
    let co: SACompany
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(co.name).font(.subheadline).fontWeight(.semibold)
                Text(co.owner_email ?? "—").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Label("معلّق", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            Image(systemName: "chevron.left").foregroundColor(.secondary).font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
        .padding(.horizontal)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Companies List
// ═══════════════════════════════════════════════════

struct SACompaniesView: View {
    @State private var companies: [SACompany] = []
    @State private var search = ""
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("بحث باسم الشركة...", text: $search)
                    .autocapitalization(.none)
                    .onChange(of: search) { _ in
                        Task { await load() }
                    }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding()

            if loading {
                ProgressView().padding(.top, 40)
                Spacer()
            } else if companies.isEmpty {
                VStack {
                    Image(systemName: "building.2").font(.system(size: 50)).foregroundColor(.secondary)
                    Text("لا توجد شركات").foregroundColor(.secondary)
                }
                .padding(.top, 60)
                Spacer()
            } else {
                List(companies) { co in
                    NavigationLink(destination: SACompanyDetailView(companyId: co.id)) {
                        SACompanyRow(co: co)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("الشركات (\(companies.count))")
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        loading = true
        companies = (try? await NetworkManager.shared.getSACompanies(q: search)) ?? []
        loading = false
    }
}

struct SACompanyRow: View {
    let co: SACompany
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(co.is_active ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(co.name.prefix(1)))
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(co.is_active ? .green : .orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(co.name).font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Text(co.plan.uppercased())
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                    if let cnt = co.user_count {
                        Text("\(cnt) مستخدم").font(.caption).foregroundColor(.secondary)
                    }
                    if let d = co.created_at {
                        Text(d).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(co.is_active ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Company Detail
// ═══════════════════════════════════════════════════

struct SACompanyDetailView: View {
    let companyId: Int
    @State private var co: SACompany?
    @State private var loading = true
    @State private var busy = false
    @State private var toast = ""
    @State private var showDeleteConfirm = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 60)
            } else if let co = co {
                VStack(spacing: 16) {
                    // Header card
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(co.is_active ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Text(String(co.name.prefix(1)))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(co.is_active ? .green : .orange)
                        }
                        Text(co.name).font(.title2).fontWeight(.bold)
                        HStack(spacing: 8) {
                            StatusBadge(active: co.is_active)
                            PlanBadge(plan: co.plan)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8)
                    .padding(.horizontal)

                    // Info
                    VStack(spacing: 0) {
                        SAInfoRow(label: "البريد الإلكتروني", value: co.owner_email ?? "—")
                        Divider().padding(.leading)
                        SAInfoRow(label: "Slug", value: co.slug)
                        Divider().padding(.leading)
                        SAInfoRow(label: "الخطة", value: co.plan.uppercased())
                        Divider().padding(.leading)
                        SAInfoRow(label: "المستخدمون", value: "\(co.users?.count ?? 0) / \(co.max_users ?? 50)")
                        Divider().padding(.leading)
                        SAInfoRow(label: "تاريخ التسجيل", value: co.created_at ?? "—")
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.05), radius: 6)
                    .padding(.horizontal)

                    // Activate / Deactivate
                    if co.is_active {
                        Button {
                            Task { await toggleActive(activate: false) }
                        } label: {
                            Label("تعطيل الشركة", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .disabled(busy)
                    } else {
                        Button {
                            Task { await toggleActive(activate: true) }
                        } label: {
                            Label("تفعيل الشركة", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .disabled(busy)
                    }

                    // Users list
                    if let users = co.users, !users.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("المستخدمون (\(users.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(users) { u in
                                SAUserRow(u: u)
                            }
                        }
                    }

                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("حذف الشركة", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.08))
                            .foregroundColor(.red)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .disabled(busy)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(co?.name ?? "الشركة")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay(alignment: .top) {
            if !toast.isEmpty {
                Text(toast)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .confirmationDialog("حذف \(co?.name ?? "الشركة")؟", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                Task {
                    try? await NetworkManager.shared.saDeleteCompany(companyId)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    func load() async {
        loading = true
        co = try? await NetworkManager.shared.getSACompany(companyId)
        loading = false
    }

    func toggleActive(activate: Bool) async {
        busy = true
        do {
            if activate { try await NetworkManager.shared.saActivate(companyId) }
            else        { try await NetworkManager.shared.saDeactivate(companyId) }
            await load()
            showToast(activate ? "تم تفعيل الشركة" : "تم تعطيل الشركة")
        } catch {
            showToast("فشل: \(error.localizedDescription)")
        }
        busy = false
    }

    func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }
}

struct SAInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium)
        }
        .padding(.horizontal).padding(.vertical, 12)
    }
}

struct SAUserRow: View {
    let u: SAUser
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(roleColor.opacity(0.15)).frame(width: 38, height: 38)
                Text(String(u.name.prefix(1))).fontWeight(.bold).foregroundColor(roleColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(.subheadline).fontWeight(.medium)
                Text(roleArabic).font(.caption).foregroundColor(roleColor)
                if let email = u.email { Text(email).font(.caption2).foregroundColor(.secondary) }
            }
            Spacer()
            if !u.is_active {
                Text("معطّل").font(.caption2).foregroundColor(.red)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.red.opacity(0.1)).cornerRadius(6)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4)
        .padding(.horizontal)
    }

    var roleArabic: String {
        switch u.role {
        case "admin":            return "أدمن"
        case "hr":               return "HR"
        case "supervisor":       return "مشرف"
        case "site_supervisor":  return "مشرف موقع"
        case "safety_officer":   return "مسؤول HSE"
        default:                 return u.role
        }
    }
    var roleColor: Color {
        switch u.role {
        case "admin":           return .purple
        case "hr":              return .green
        case "safety_officer":  return .blue
        default:                return .orange
        }
    }
}

struct StatusBadge: View {
    let active: Bool
    var body: some View {
        Label(active ? "نشط" : "معلّق", systemImage: active ? "checkmark.circle.fill" : "clock.fill")
            .font(.caption).fontWeight(.semibold)
            .foregroundColor(active ? .green : .orange)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((active ? Color.green : Color.orange).opacity(0.12))
            .cornerRadius(20)
    }
}

struct PlanBadge: View {
    let plan: String
    var body: some View {
        Text(plan.uppercased())
            .font(.caption2).fontWeight(.bold)
            .foregroundColor(.purple)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.purple.opacity(0.12))
            .cornerRadius(20)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - New Company
// ═══════════════════════════════════════════════════

struct SANewCompanyView: View {
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var plan     = "free"
    @State private var loading  = false
    @State private var success  = false
    @State private var error    = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    SAFormField(title: "اسم الشركة", placeholder: "مثال: شركة الأمان", text: $name)
                    SAFormField(title: "البريد الإلكتروني للأدمن", placeholder: "admin@company.com", text: $email, keyboard: .emailAddress)
                    SAFormField(title: "كلمة مرور الأدمن", placeholder: "كلمة المرور", text: $password, secure: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("الخطة").font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
                        Picker("الخطة", selection: $plan) {
                            Text("Free").tag("free")
                            Text("Pro").tag("pro")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 8)
                .padding(.horizontal)

                if !error.isEmpty {
                    Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                }
                if success {
                    Label("تم إنشاء الشركة بنجاح", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.subheadline)
                }

                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        else { Label("إنشاء الشركة", systemImage: "plus.circle.fill") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || loading)
            }
            .padding(.vertical)
        }
        .navigationTitle("شركة جديدة")
    }

    func create() async {
        loading = true; error = ""; success = false
        do {
            try await NetworkManager.shared.saCreateCompany(
                name: name, email: email, plan: plan, password: password)
            success = true
            name = ""; email = ""; password = ""
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct SAFormField: View {
    let title:       String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure   = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Profile
// ═══════════════════════════════════════════════════

struct SAProfileView: View {
    @EnvironmentObject var session: SessionManager
    private var user: AppUser? { session.currentUser }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 34)).foregroundColor(.purple)
                }
                Text(user?.name ?? "Super Admin").font(.title2).fontWeight(.bold)
                Text("Super Admin").font(.caption).foregroundColor(.purple)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.purple.opacity(0.12)).cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8)
            .padding(.horizontal)

            VStack(spacing: 0) {
                SAInfoRow(label: "الكود", value: user?.code ?? "—")
                Divider().padding(.leading)
                SAInfoRow(label: "الدور", value: "Super Admin")
            }
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6)
            .padding(.horizontal)

            Spacer()

            Button(role: .destructive) {
                Task {
                    try? await NetworkManager.shared.logout()
                    await MainActor.run { session.logout() }
                }
            } label: {
                Label("تسجيل الخروج", systemImage: "arrow.right.square.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 30)
        .navigationTitle("حسابي")
    }
}
