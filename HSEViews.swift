import SwiftUI
import PhotosUI

// ═══════════════════════════════════════════════════
//  MARK: - HSE Officer Tab (safety_officer role)
// ═══════════════════════════════════════════════════
struct HSEOfficerTabView: View {
    var body: some View {
        TabView {
            HSEOfficerHomeView()
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }

            HSEObservationsView()
                .tabItem { Label("الملاحظات", systemImage: "eye.fill") }

            HSEPtwView()
                .tabItem { Label("PTW", systemImage: "doc.badge.checkmark") }

            HSEManpowerView()
                .tabItem { Label("Man Power", systemImage: "person.3.fill") }

            HSEInspectionView()
                .tabItem { Label("Inspection", systemImage: "checklist") }

            HSEMoreView()
                .tabItem { Label("المزيد", systemImage: "ellipsis.circle.fill") }

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.circle") }
        }
        .accentColor(Color(hex: "#16a34a"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ── More screen groups JSO / TBT / Near Miss / BBS / My CA ──────────
struct HSEMoreView: View {
    @State private var openCaCount = 0

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: HSEMyCaView()) {
                    HStack {
                        Label("إجراءاتي التصحيحية", systemImage: "list.clipboard.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        if openCaCount > 0 {
                            Text("\(openCaCount)")
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(10)
                        }
                    }
                }
                NavigationLink(destination: HSEJsoView()) {
                    Label("JSO Closure", systemImage: "doc.badge.plus")
                }
                NavigationLink(destination: HSETbtView()) {
                    Label("TBT", systemImage: "person.2.badge.gearshape")
                }
                NavigationLink(destination: HSENearMissView()) {
                    Label("Near Miss", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                NavigationLink(destination: HSEBbsView()) {
                    Label("BBS Daily Count", systemImage: "checkmark.circle.fill")
                }
            }
            .navigationTitle("المزيد")
            .task { await loadCaCount() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func loadCaCount() async {
        if let items = try? await NetworkManager.shared.hseMyCa() {
            openCaCount = items.filter { $0.status != "completed" }.count
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - My Corrective Actions View
// ═══════════════════════════════════════════════════
struct HSEMyCaView: View {
    @State private var items:     [HseCaItem] = []
    @State private var isLoading  = true
    @State private var errorMsg   = ""

    var open:     [HseCaItem] { items.filter { $0.status != "completed" } }
    var overdue:  [HseCaItem] { open.filter  { $0.overdue } }
    var pending:  [HseCaItem] { open.filter  { !$0.overdue } }
    var closed:   [HseCaItem] { items.filter { $0.status == "completed" } }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            } else if !errorMsg.isEmpty {
                Section { Text(errorMsg).foregroundColor(.red).font(.caption) }
            } else {
                if overdue.isEmpty && pending.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle).foregroundColor(.green)
                            Text("لا توجد إجراءات مفتوحة").foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding()
                    }
                }

                if !overdue.isEmpty {
                    Section(header: Label("متأخرة (\(overdue.count))",
                                         systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)) {
                        ForEach(overdue) { ca in caRow(ca, color: .red) }
                    }
                }

                if !pending.isEmpty {
                    Section(header: Text("مفتوحة (\(pending.count))")) {
                        ForEach(pending) { ca in caRow(ca, color: .orange) }
                    }
                }

                if !closed.isEmpty {
                    Section(header: Text("مكتملة (\(closed.count))").foregroundColor(.green)) {
                        ForEach(closed) { ca in caRow(ca, color: .green) }
                    }
                }
            }
        }
        .navigationTitle("إجراءاتي التصحيحية")
        .task { await load() }
        .refreshable { await load() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private func caRow(_ ca: HseCaItem, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
                Text(ca.action_required)
                    .font(.subheadline).fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Label(formatDate(ca.due_date), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(ca.overdue ? .red : .secondary)
                if !ca.assigned_to.isEmpty {
                    Label(ca.assigned_to, systemImage: "person")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.leading, 18)
            if ca.status == "completed", let done = ca.completed_at {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("أُنجز \(formatDate(done))").font(.caption2).foregroundColor(.green)
                    if !ca.completion_notes.isEmpty {
                        Text("· \(ca.completion_notes)").font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { items = try await NetworkManager.shared.hseMyCa() }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Shared Helpers
// ═══════════════════════════════════════════════════

private func todayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

private func formatDate(_ iso: String) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: iso) else { return iso }
    let out = DateFormatter(); out.dateFormat = "dd MMM yyyy"
    return out.string(from: d)
}

struct HSELocationField: View {
    let label: String
    @Binding var value: String
    let suggestions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField("اكتب الموقع...", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if !value.isEmpty {
                let filtered = suggestions.filter { $0.localizedCaseInsensitiveContains(value) }.prefix(5)
                if !filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filtered), id: \.self) { loc in
                            Button(loc) { value = loc }
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                            Divider()
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 1. Check-in View
// ═══════════════════════════════════════════════════
struct HSECheckinView: View {
    @State private var checkin: HseCheckinItem? = nil
    @State private var location   = ""
    @State private var locations: [String] = []
    @State private var isLoading  = true
    @State private var saving     = false
    @State private var message    = ""
    @State private var showAlert  = false

    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section { ProgressView() }
                } else {
                    if let ci = checkin {
                        Section(header: Text("تسجيل اليوم")) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("تم تسجيل الحضور").font(.headline)
                                    Text(ci.location).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        Section(header: Text("تعديل الموقع")) {
                            locationSection
                        }
                    } else {
                        Section(header: Text("تسجيل حضور اليوم")) {
                            locationSection
                        }
                    }
                    Section {
                        Button(action: save) {
                            if saving { ProgressView() }
                            else { Text(checkin == nil ? "تسجيل الحضور" : "تحديث الموقع")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white) }
                        }
                        .listRowBackground(Color.green)
                        .disabled(location.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                    }
                }
            }
            .navigationTitle("تسجيل الحضور")
            .task { await load() }
            .alert("", isPresented: $showAlert) { Button("حسناً") {} } message: { Text(message) }
        }
    }

    @ViewBuilder private var locationSection: some View {
        TextField("الموقع (مثال: Area 321 - Gate 5)", text: $location)
            .autocapitalization(.words)
        if !location.isEmpty {
            let filtered = locations.filter { $0.localizedCaseInsensitiveContains(location) }.prefix(5)
            ForEach(Array(filtered), id: \.self) { loc in
                Button(loc) { location = loc }
                    .foregroundColor(.primary)
            }
        }
    }

    private func load() async {
        isLoading = true
        async let ci = try? NetworkManager.shared.hseCheckinToday()
        async let locs = try? NetworkManager.shared.hseLocations()
        let (c, l) = await (ci, locs)
        checkin = c
        locations = l ?? []
        if let c = c { location = c.location }
        isLoading = false
    }

    private func save() {
        let loc = location.trimmingCharacters(in: .whitespaces)
        guard !loc.isEmpty else { return }
        saving = true
        Task {
            do {
                try await NetworkManager.shared.hseCheckin(location: loc)
                await load()
                message = "تم حفظ موقعك بنجاح ✓"
            } catch {
                message = "فشل: \(error.localizedDescription)"
            }
            saving = false
            showAlert = true
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 2. Observations View
// ═══════════════════════════════════════════════════
struct HSEObservationsView: View {
    @State private var items:    [HseObservationItem] = []
    @State private var page      = 1
    @State private var pages     = 1
    @State private var isLoading = true
    @State private var statusFilter = ""
    @State private var showNew   = false
    @State private var editObs: HseObservationItem? = nil
    @State private var showEdit  = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView()
                } else {
                    List {
                        Picker("الحالة", selection: $statusFilter) {
                            Text("الكل").tag("")
                            Text("مفتوحة").tag("open")
                            Text("مغلقة").tag("closed")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .onChange(of: statusFilter) { _ in Task { page = 1; await load() } }

                        ForEach(items) { obs in
                            NavigationLink(destination: HSEObservationDetailView(obs: obs, onUpdate: { Task { await load() } })) {
                                ObsRow(obs: obs)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editObs = obs; showEdit = true } label: {
                                    Label("تعديل", systemImage: "pencil")
                                }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { await delete(id: obs.id) } } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }

                        if page < pages {
                            Button("تحميل المزيد...") { Task { page += 1; await loadMore() } }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { page = 1; await load() }
                }
            }
            .navigationTitle("الملاحظات")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNew) {
                HSENewObservationView { Task { page = 1; await load() } }
            }
            .sheet(isPresented: $showEdit) {
                if let o = editObs {
                    HSEEditObservationView(obs: o) { Task { page = 1; await load() } }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        if let res = try? await NetworkManager.shared.hseObservations(page: 1, status: statusFilter) {
            items = res.items; page = res.page; pages = res.pages
        }
        isLoading = false
    }

    private func loadMore() async {
        if let res = try? await NetworkManager.shared.hseObservations(page: page, status: statusFilter) {
            items += res.items; pages = res.pages
        }
    }

    private func delete(id: Int) async {
        try? await NetworkManager.shared.hseObservationDelete(id: id)
        items.removeAll { $0.id == id }
    }
}

struct ObsRow: View {
    let obs: HseObservationItem
    var riskColor: Color {
        switch obs.risk_level {
        case "H": return .red
        case "M": return .orange
        default:  return .blue
        }
    }
    var typeLabel: String {
        switch obs.obs_type {
        case "unsafe_act":       return "Unsafe Act"
        case "unsafe_condition": return "Unsafe Cond."
        default:                 return "Positive"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(obs.date)).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(obs.risk_level).font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(riskColor.opacity(0.15)).foregroundColor(riskColor)
                    .cornerRadius(8)
                Circle().fill(obs.status == "open" ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
            }
            Text(typeLabel + (obs.category.isEmpty ? "" : " — " + obs.category))
                .font(.subheadline).bold()
            if !obs.location.isEmpty {
                Text("📍 " + obs.location).font(.caption).foregroundColor(.secondary)
            }
            if !obs.description.isEmpty {
                Text(obs.description).font(.caption).lineLimit(2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HSEObservationDetailView: View {
    let obs:      HseObservationItem
    let onUpdate: () -> Void
    @State private var showClose     = false
    @State private var showAddCA     = false
    @State private var closureText   = ""
    @State private var closurePhoto: PhotosPickerItem? = nil
    @State private var closureImageData: Data? = nil
    @State private var saving        = false
    @State private var message       = ""
    @State private var showAlert     = false
    @Environment(\.dismiss) var dismiss
    private var isSupervisor: Bool {
        let role = NetworkManager.shared.currentUser?.role ?? ""
        return role == "admin" || role == "site_supervisor" || role == "supervisor"
    }

    var body: some View {
        Form {
            Section(header: Text("التفاصيل")) {
                LabeledContent("التاريخ",  value: formatDate(obs.date))
                LabeledContent("النوع",    value: obs.obs_type.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("الفئة",    value: obs.category.isEmpty ? "—" : obs.category)
                LabeledContent("الخطورة",  value: obs.risk_level.isEmpty ? "—" : obs.risk_level)
                LabeledContent("الموقع",   value: obs.location.isEmpty ? "—" : obs.location)
                LabeledContent("الحالة",   value: obs.status == "open" ? "مفتوح" : "مغلق")
            }
            Section(header: Text("الوصف")) {
                Text(obs.description.isEmpty ? "—" : obs.description)
            }
            Section(header: Text("الإجراء الفوري")) {
                Text(obs.action_taken.isEmpty ? "—" : obs.action_taken)
            }
            if obs.status == "closed" {
                Section(header: Text("إجراء الإغلاق")) {
                    if let d = obs.closed_at { Text("تاريخ الإغلاق: " + formatDate(d)).font(.caption).foregroundColor(.secondary) }
                    Text(obs.closure_action.isEmpty ? "—" : obs.closure_action)
                }
            }
            if obs.status == "open" {
                Section {
                    Button("إغلاق الملاحظة") { showClose = true }
                        .foregroundColor(.green)
                    if isSupervisor {
                        Button("إضافة إجراء تصحيحي") { showAddCA = true }
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("تفاصيل الملاحظة")
        .sheet(isPresented: $showAddCA) {
            HSENewCorrectiveActionView(observationId: obs.id, onSaved: { onUpdate(); dismiss() })
        }
        .sheet(isPresented: $showClose) {
            NavigationView {
                Form {
                    Section(header: Text("إجراء الإغلاق *")) {
                        TextEditor(text: $closureText).frame(minHeight: 80)
                    }
                    Section(header: Text("صورة الإغلاق (اختياري)")) {
                        PhotosPicker(selection: $closurePhoto, matching: .images) {
                            HStack {
                                Image(systemName: closureImageData != nil ? "checkmark.circle.fill" : "camera.fill")
                                    .foregroundColor(closureImageData != nil ? .green : .secondary)
                                Text(closureImageData != nil ? "تم اختيار صورة" : "إضافة صورة إغلاق")
                                    .foregroundColor(closureImageData != nil ? .green : .primary)
                            }
                        }
                        .onChange(of: closurePhoto) { item in
                            Task {
                                closureImageData = try? await item?.loadTransferable(type: Data.self)
                            }
                        }
                        if let data = closureImageData, let img = UIImage(data: data) {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(maxHeight: 160).cornerRadius(8)
                        }
                    }
                    Section {
                        Button(action: {
                            guard !closureText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            saving = true
                            Task {
                                do {
                                    try await NetworkManager.shared.hseObservationClose(id: obs.id, closureAction: closureText)
                                    if let imgData = closureImageData {
                                        try? await NetworkManager.shared.hseObservationUploadClosurePhoto(obsId: obs.id, imageData: imgData)
                                    }
                                    onUpdate()
                                    showClose = false
                                    dismiss()
                                } catch {
                                    message = "فشل: \(error.localizedDescription)"
                                    showAlert = true
                                }
                                saving = false
                            }
                        }) {
                            if saving { ProgressView().frame(maxWidth: .infinity) }
                            else { Text("حفظ الإغلاق").frame(maxWidth: .infinity, alignment: .center).foregroundColor(.white) }
                        }
                        .listRowBackground(Color.green)
                        .disabled(closureText.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                    }
                }
                .navigationTitle("إغلاق الملاحظة")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { showClose = false } } }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
        .alert("", isPresented: $showAlert) { Button("حسناً") {} } message: { Text(message) }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - New Corrective Action (Supervisor)
// ═══════════════════════════════════════════════════
struct HSENewCorrectiveActionView: View {
    let observationId: Int
    let onSaved: () -> Void

    @State private var assignedTo      = ""
    @State private var dueDate         = Date().addingTimeInterval(7 * 86400)
    @State private var actionRequired  = ""
    @State private var saving          = false
    @State private var errorMsg        = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("تفاصيل الإجراء")) {
                    TextField("مُسند إلى (اختياري)", text: $assignedTo)
                        .textInputAutocapitalization(.never)
                    DatePicker("تاريخ الاستحقاق", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ar_SA"))
                }
                Section(header: Text("الإجراء المطلوب *")) {
                    TextEditor(text: $actionRequired)
                        .frame(minHeight: 100)
                }
                if !errorMsg.isEmpty {
                    Section { Text(errorMsg).foregroundColor(.red).font(.caption) }
                }
                Section {
                    Button(action: save) {
                        if saving { ProgressView().frame(maxWidth: .infinity) }
                        else { Text("إضافة الإجراء").frame(maxWidth: .infinity).foregroundColor(.white) }
                    }
                    .listRowBackground(Color.blue)
                    .disabled(actionRequired.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
            .navigationTitle("إجراء تصحيحي جديد")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func save() {
        saving = true; errorMsg = ""
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let dueDateStr = fmt.string(from: dueDate)
        Task {
            do {
                _ = try await NetworkManager.shared.hseCorrectiveActionAdd(
                    observationId: observationId,
                    assignedTo: assignedTo.trimmingCharacters(in: .whitespaces),
                    dueDate: dueDateStr,
                    actionRequired: actionRequired.trimmingCharacters(in: .whitespaces)
                )
                onSaved()
                dismiss()
            } catch {
                errorMsg = "فشل: \(error.localizedDescription)"
            }
            saving = false
        }
    }
}

struct HSENewObservationView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var date        = todayString()
    @State private var location    = ""
    @State private var obsType     = "unsafe_act"
    @State private var category    = "PPE"
    @State private var riskLevel   = "L"
    @State private var description = ""
    @State private var actionTaken = ""
    @State private var locations: [String] = []
    @State private var saving      = false
    @State private var errorMsg    = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    let obsTypes = [("unsafe_act", "Unsafe Act"), ("unsafe_condition", "Unsafe Condition"), ("positive", "Positive")]
    let categories = ["PPE", "Excavation", "Housekeeping", "Barrier Management",
                      "Vehicle & Equipment", "Work at Height", "Lifting Operations",
                      "Line of Fire", "Control of Chemicals", "High Risk Situation", "Other"]
    let riskLevels = [("L", "Low"), ("M", "Medium"), ("H", "High")]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("معلومات أساسية")) {
                    DatePicker("التاريخ", selection: Binding(
                        get: { ISO8601DateFormatter().date(from: date + "T00:00:00Z") ?? Date() },
                        set: { date = DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd" }.string(from: $0) }
                    ), displayedComponents: .date)
                    TextField("الموقع", text: $location)
                }
                Section(header: Text("نوع الملاحظة")) {
                    Picker("النوع", selection: $obsType) {
                        ForEach(obsTypes, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("الفئة", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("مستوى الخطورة", selection: $riskLevel) {
                        ForEach(riskLevels, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section(header: Text("الوصف *")) {
                    TextEditor(text: $description).frame(minHeight: 80)
                }
                Section(header: Text("الإجراء الفوري *")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 60)
                }
                Section(header: Text("صورة (اختياري)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        HStack {
                            Image(systemName: photoData != nil ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoData != nil ? .green : .secondary)
                            Text(photoData != nil ? "تم اختيار الصورة" : "إضافة صورة")
                                .foregroundColor(photoData != nil ? .green : .primary)
                        }
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self) {
                                photoData = data
                            } else {
                                photoData = nil
                            }
                        }
                    }
                }
                if !errorMsg.isEmpty {
                    Section { Text(errorMsg).foregroundColor(.red) }
                }
                Section {
                    Button("حفظ الملاحظة") { Task { await save() } }
                        .disabled(saving || description.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("ملاحظة جديدة")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
            .task { locations = (try? await NetworkManager.shared.hseLocations()) ?? [] }
        }
    }

    private func save() async {
        let desc = description.trimmingCharacters(in: .whitespaces)
        let act  = actionTaken.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty else { errorMsg = "الوصف مطلوب"; return }
        saving = true; errorMsg = ""
        do {
            let newId = try await NetworkManager.shared.hseObservationCreate(
                date: date, location: location, obsType: obsType, category: category,
                riskLevel: riskLevel, description: desc, actionTaken: act)
            if newId > 0, let img = photoData,
               let compressed = UIImage(data: img)?.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseObservationUploadPhoto(obsId: newId, imageData: compressed)
            }
            onSaved(); dismiss()
        } catch {
            errorMsg = "فشل: \(error.localizedDescription)"
        }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 3. JSO Closure View
// ═══════════════════════════════════════════════════
struct HSEJsoView: View {
    @State private var items:    [HseJsoItem] = []
    @State private var page      = 1
    @State private var pages     = 1
    @State private var isLoading = true
    @State private var showNew   = false
    @State private var editJso: HseJsoItem? = nil
    @State private var showEdit  = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && items.isEmpty { ProgressView() }
                else {
                    List {
                        ForEach(items) { j in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("JSO #\(j.jso_number)").font(.headline)
                                    Spacer()
                                    Text(formatDate(j.date)).font(.caption).foregroundColor(.secondary)
                                }
                                if !j.location.isEmpty {
                                    Text("📍 " + j.location).font(.caption).foregroundColor(.secondary)
                                }
                                if !j.action_taken.isEmpty {
                                    Text(j.action_taken).font(.caption).lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .leading) {
                                Button { editJso = j; showEdit = true } label: {
                                    Label("تعديل", systemImage: "pencil")
                                }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { await delete(id: j.id) } } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                        if page < pages {
                            Button("تحميل المزيد...") { Task { page += 1; await loadMore() } }
                                .foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { page = 1; await load() }
                }
            }
            .navigationTitle("إغلاق JSO")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }}
            .sheet(isPresented: $showNew) { HSENewJsoView { Task { page = 1; await load() } } }
            .sheet(isPresented: $showEdit) {
                if let j = editJso { HSEEditJsoView(jso: j) { Task { page = 1; await load() } } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        if let res = try? await NetworkManager.shared.hseJsoList(page: 1) {
            items = res.items; page = res.page; pages = res.pages
        }
        isLoading = false
    }
    private func loadMore() async {
        if let res = try? await NetworkManager.shared.hseJsoList(page: page) {
            items += res.items; pages = res.pages
        }
    }
    private func delete(id: Int) async {
        try? await NetworkManager.shared.hseJsoDelete(id: id)
        items.removeAll { $0.id == id }
    }
}

struct HSENewJsoView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var date        = todayString()
    @State private var jsoNumber   = ""
    @State private var location    = ""
    @State private var actionTaken = ""
    @State private var saving      = false
    @State private var errorMsg    = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات JSO")) {
                    DatePicker("التاريخ", selection: Binding(
                        get: { ISO8601DateFormatter().date(from: date + "T00:00:00Z") ?? Date() },
                        set: { date = DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd" }.string(from: $0) }
                    ), displayedComponents: .date)
                    TextField("رقم JSO *", text: $jsoNumber).keyboardType(.asciiCapable)
                    TextField("الموقع", text: $location)
                }
                Section(header: Text("الإجراء المتخذ *")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 80)
                }
                Section(header: Text("صورة الإثبات (اختياري)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        HStack {
                            Image(systemName: photoData != nil ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoData != nil ? .green : .secondary)
                            Text(photoData != nil ? "تم اختيار الصورة" : "إضافة صورة")
                                .foregroundColor(photoData != nil ? .green : .primary)
                        }
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self) {
                                photoData = data
                            } else {
                                photoData = nil
                            }
                        }
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ") { Task { await save() } }
                        .disabled(saving || jsoNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("JSO جديد")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
        }
    }

    private func save() async {
        let jso = jsoNumber.trimmingCharacters(in: .whitespaces)
        guard !jso.isEmpty else { errorMsg = "رقم JSO مطلوب"; return }
        saving = true; errorMsg = ""
        do {
            let newId = try await NetworkManager.shared.hseJsoCreate(date: date, jsoNumber: jso,
                                                                      location: location, actionTaken: actionTaken)
            if newId > 0, let img = photoData,
               let compressed = UIImage(data: img)?.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseJsoUploadPhoto(jsoId: newId, imageData: compressed)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 4. TBT View
// ═══════════════════════════════════════════════════
struct HSETbtView: View {
    @State private var items:    [HseTbtItem] = []
    @State private var page      = 1
    @State private var pages     = 1
    @State private var isLoading = true
    @State private var showNew   = false
    @State private var editItem: HseTbtItem? = nil

    var body: some View {
        NavigationView {
            Group {
                if isLoading && items.isEmpty { ProgressView() }
                else {
                    List {
                        ForEach(items) { t in
                            NavigationLink(destination: HSETbtDetailView(tbt: t)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(t.topic).font(.headline).lineLimit(1)
                                        Spacer()
                                        Text(formatDate(t.date)).font(.caption).foregroundColor(.secondary)
                                    }
                                    HStack {
                                        if !t.location.isEmpty {
                                            Text("📍 " + t.location).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(t.attendee_count) حضور")
                                            .font(.caption).bold()
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue).cornerRadius(8)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editItem = t } label: { Label("تعديل", systemImage: "pencil") }
                                    .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { await delete(id: t.id) } } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                        if page < pages {
                            Button("تحميل المزيد...") { Task { page += 1; await loadMore() } }
                                .foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { page = 1; await load() }
                }
            }
            .navigationTitle("Toolbox Talk")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }}
            .sheet(isPresented: $showNew) { HSENewTbtView { Task { page = 1; await load() } } }
            .sheet(item: $editItem) { t in
                HSEEditTbtView(tbt: t) { Task { page = 1; await load() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        if let res = try? await NetworkManager.shared.hseTbtList(page: 1) {
            items = res.items; page = res.page; pages = res.pages
        }
        isLoading = false
    }
    private func loadMore() async {
        if let res = try? await NetworkManager.shared.hseTbtList(page: page) {
            items += res.items; pages = res.pages
        }
    }
    private func delete(id: Int) async {
        try? await NetworkManager.shared.hseTbtDelete(id: id)
        items.removeAll { $0.id == id }
    }
}

struct HSETbtDetailView: View {
    let tbt: HseTbtItem
    @State private var pdfBusy    = false
    @State private var pdfShareUrl: URL? = nil

    var body: some View {
        Form {
            Section(header: Text("معلومات")) {
                LabeledContent("التاريخ",  value: formatDate(tbt.date))
                LabeledContent("الموضوع",  value: tbt.topic)
                LabeledContent("الموقع",   value: tbt.location.isEmpty ? "—" : tbt.location)
                if let sup = tbt.supervisor_name, !sup.isEmpty {
                    LabeledContent("المشرف", value: sup)
                }
                LabeledContent("عدد الحضور", value: "\(tbt.attendee_count)")
            }
            let supName = tbt.supervisor_name ?? ""
            if !tbt.attendees.isEmpty || !supName.isEmpty {
                Section(header: Text("قائمة الحضور")) {
                    if !supName.isEmpty {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .foregroundColor(.blue)
                            Text(supName).font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Text("مشرف").font(.caption).foregroundColor(.blue)
                        }
                    }
                    ForEach(tbt.attendees, id: \.emp_number) { att in
                        HStack {
                            Text(att.emp_name).font(.subheadline)
                            Spacer()
                            Text(att.emp_number).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("TBT Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if pdfBusy {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button { Task { await exportPdf() } } label: {
                        Image(systemName: "printer.fill")
                    }
                }
            }
        }
        .sheet(item: $pdfShareUrl) { HSEShareSheet(url: $0) }
    }

    @MainActor private func exportPdf() async {
        pdfBusy = true
        pdfShareUrl = await makeTbtPdf(
            topic:          tbt.topic,
            date:           tbt.date,
            location:       tbt.location,
            supervisorName: tbt.supervisor_name ?? "",
            attendees:      tbt.attendees.map { ($0.emp_name, $0.emp_number) }
        )
        pdfBusy = false
    }
}

struct HSENewTbtView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var date           = todayString()
    @State private var topic          = ""
    @State private var location       = ""
    @State private var supCode        = ""
    @State private var supName        = ""
    @State private var supLookupMsg   = ""
    @State private var isLookingSuper = false
    @State private var attendees: [(emp_number: String, emp_name: String)] = []
    @State private var lookupInput    = ""
    @State private var lookupMsg      = ""
    @State private var isLooking      = false
    @State private var saving         = false
    @State private var errorMsg       = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات TBT")) {
                    DatePicker("التاريخ", selection: Binding(
                        get: { ISO8601DateFormatter().date(from: date + "T00:00:00Z") ?? Date() },
                        set: { date = DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd" }.string(from: $0) }
                    ), displayedComponents: .date)
                    TextField("الموضوع *", text: $topic)
                    TextField("الموقع", text: $location)
                }
                Section(header: Text("المشرف (اختياري)")) {
                    HStack {
                        TextField("كود المشرف", text: $supCode)
                            .autocapitalization(.allCharacters)
                            .keyboardType(.asciiCapable)
                        if isLookingSuper {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button("بحث") { Task { await lookupSupervisor() } }
                                .disabled(supCode.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    if !supName.isEmpty {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark.fill").foregroundColor(.blue)
                            Text(supName).foregroundColor(.blue).font(.subheadline)
                        }
                    }
                    if !supLookupMsg.isEmpty {
                        Text(supLookupMsg).font(.caption)
                            .foregroundColor(supLookupMsg.contains("✓") ? .green : .red)
                    }
                }
                Section(header: Text("صورة ورقة الحضور (اختياري)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        HStack {
                            Image(systemName: photoData != nil ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoData != nil ? .green : .secondary)
                            Text(photoData != nil ? "تم اختيار الصورة" : "إضافة صورة")
                                .foregroundColor(photoData != nil ? .green : .primary)
                        }
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self) {
                                photoData = data
                            } else {
                                photoData = nil
                            }
                        }
                    }
                }
                Section(header: Text("إضافة موظف")) {
                    HStack {
                        TextField("رقم الموظف", text: $lookupInput)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.allCharacters)
                        Button("بحث") { Task { await lookup() } }
                            .disabled(lookupInput.trimmingCharacters(in: .whitespaces).isEmpty || isLooking)
                    }
                    if !lookupMsg.isEmpty {
                        Text(lookupMsg).font(.caption)
                            .foregroundColor(lookupMsg.contains("✓") ? .green : .red)
                    }
                }
                if !attendees.isEmpty {
                    Section(header: Text("الحضور (\(attendees.count))")) {
                        ForEach(attendees, id: \.emp_number) { att in
                            HStack {
                                Text(att.emp_name)
                                Spacer()
                                Text(att.emp_number).foregroundColor(.secondary).font(.caption)
                            }
                        }
                        .onDelete { idx in attendees.remove(atOffsets: idx) }
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ TBT") { Task { await save() } }
                        .disabled(saving || topic.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("TBT جديد")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
        }
    }

    private func lookup() async {
        let num = lookupInput.trimmingCharacters(in: .whitespaces)
        guard !num.isEmpty else { return }
        isLooking = true; lookupMsg = ""
        do {
            let res = try await NetworkManager.shared.hseEmployeeLookup(empNumber: num)
            if res.found, let name = res.name, let empNum = res.emp_number {
                if !attendees.contains(where: { $0.emp_number == empNum }) {
                    attendees.append((emp_number: empNum, emp_name: name))
                }
                lookupMsg = "✓ \(name)"; lookupInput = ""
            } else {
                lookupMsg = "الموظف غير موجود أو غير نشط"
            }
        } catch { lookupMsg = "خطأ في البحث" }
        isLooking = false
    }

    private func lookupSupervisor() async {
        let code = supCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isLookingSuper = true; supLookupMsg = ""; supName = ""
        do {
            let res = try await NetworkManager.shared.hseSupervisorLookup(code: code)
            if res.found, let name = res.name {
                supName = name
                supLookupMsg = "✓ \(name)"
            } else {
                supLookupMsg = "المشرف غير موجود"
                supCode = ""
            }
        } catch { supLookupMsg = "خطأ في البحث" }
        isLookingSuper = false
    }

    private func save() async {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { errorMsg = "الموضوع مطلوب"; return }
        saving = true; errorMsg = ""
        do {
            let atts = attendees.map { ["emp_number": $0.emp_number, "emp_name": $0.emp_name] }
            let code = supCode.trimmingCharacters(in: .whitespaces)
            let newId = try await NetworkManager.shared.hseTbtCreate(
                date: date, topic: t, location: location,
                supervisorCode: code.isEmpty ? nil : code,
                attendees: atts)
            if newId > 0, let img = photoData,
               let compressed = UIImage(data: img)?.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseTbtUploadPhoto(tbtId: newId, imageData: compressed)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 5. Near Miss View
// ═══════════════════════════════════════════════════
struct HSENearMissView: View {
    @State private var items:    [HseNearMissItem] = []
    @State private var page      = 1
    @State private var pages     = 1
    @State private var isLoading = true
    @State private var showNew   = false
    @State private var editNm: HseNearMissItem? = nil
    @State private var showEdit  = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && items.isEmpty { ProgressView() }
                else {
                    List {
                        ForEach(items) { nm in
                            NavigationLink(destination: HSENearMissDetailView(nm: nm)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                        Text(formatDate(nm.date)).font(.subheadline).bold()
                                        Spacer()
                                        if !nm.location.isEmpty {
                                            Text("📍 " + nm.location).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Text(nm.description).font(.caption).lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editNm = nm; showEdit = true } label: {
                                    Label("تعديل", systemImage: "pencil")
                                }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { Task { await delete(id: nm.id) } } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                        if page < pages {
                            Button("تحميل المزيد...") { Task { page += 1; await loadMore() } }
                                .foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { page = 1; await load() }
                }
            }
            .navigationTitle("Near Miss")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }}
            .sheet(isPresented: $showNew) { HSENewNearMissView { Task { page = 1; await load() } } }
            .sheet(isPresented: $showEdit) {
                if let nm = editNm { HSEEditNearMissView(nm: nm) { Task { page = 1; await load() } } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        if let res = try? await NetworkManager.shared.hseNearMissList(page: 1) {
            items = res.items; page = res.page; pages = res.pages
        }
        isLoading = false
    }
    private func loadMore() async {
        if let res = try? await NetworkManager.shared.hseNearMissList(page: page) {
            items += res.items; pages = res.pages
        }
    }
    private func delete(id: Int) async {
        try? await NetworkManager.shared.hseNearMissDelete(id: id)
        items.removeAll { $0.id == id }
    }
}

struct HSENearMissDetailView: View {
    let nm: HseNearMissItem
    var body: some View {
        Form {
            Section(header: Text("معلومات الحادث")) {
                LabeledContent("التاريخ",  value: formatDate(nm.date))
                LabeledContent("الموقع",   value: nm.location.isEmpty ? "—" : nm.location)
                LabeledContent("أُبلغ إلى", value: nm.reported_to.isEmpty ? "—" : nm.reported_to)
            }
            Section(header: Text("الوصف")) { Text(nm.description.isEmpty ? "—" : nm.description) }
            Section(header: Text("السبب المباشر")) { Text(nm.immediate_cause.isEmpty ? "—" : nm.immediate_cause) }
            Section(header: Text("الإجراء المتخذ")) { Text(nm.action_taken.isEmpty ? "—" : nm.action_taken) }
        }
        .navigationTitle("Near Miss")
    }
}

struct HSENewNearMissView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var date           = todayString()
    @State private var location       = ""
    @State private var description    = ""
    @State private var immediateCause = ""
    @State private var actionTaken    = ""
    @State private var reportedTo     = ""
    @State private var saving         = false
    @State private var errorMsg       = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات الحادث")) {
                    DatePicker("التاريخ", selection: Binding(
                        get: { ISO8601DateFormatter().date(from: date + "T00:00:00Z") ?? Date() },
                        set: { date = DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd" }.string(from: $0) }
                    ), displayedComponents: .date)
                    TextField("الموقع", text: $location)
                    TextField("أُبلغ إلى *", text: $reportedTo)
                }
                Section(header: Text("وصف الحادث *")) {
                    TextEditor(text: $description).frame(minHeight: 80)
                }
                Section(header: Text("السبب المباشر *")) {
                    TextEditor(text: $immediateCause).frame(minHeight: 60)
                }
                Section(header: Text("الإجراء المتخذ *")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 60)
                }
                Section(header: Text("صورة (اختياري)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        HStack {
                            Image(systemName: photoData != nil ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoData != nil ? .green : .secondary)
                            Text(photoData != nil ? "تم اختيار الصورة" : "إضافة صورة")
                                .foregroundColor(photoData != nil ? .green : .primary)
                        }
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self) {
                                photoData = data
                            } else {
                                photoData = nil
                            }
                        }
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ التقرير") { Task { await save() } }
                        .disabled(saving).frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Near Miss جديد")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
        }
    }

    private func save() async {
        let desc = description.trimmingCharacters(in: .whitespaces)
        let cause = immediateCause.trimmingCharacters(in: .whitespaces)
        let act  = actionTaken.trimmingCharacters(in: .whitespaces)
        let rpt  = reportedTo.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty && !cause.isEmpty && !act.isEmpty && !rpt.isEmpty else {
            errorMsg = "جميع الحقول المطلوبة يجب ملؤها"; return
        }
        saving = true; errorMsg = ""
        do {
            let newId = try await NetworkManager.shared.hseNearMissCreate(date: date, location: location,
                description: desc, immediateCause: cause, actionTaken: act, reportedTo: rpt)
            if newId > 0, let img = photoData,
               let compressed = UIImage(data: img)?.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseNearMissUploadPhoto(nmId: newId, imageData: compressed)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 6. BBS View
// ═══════════════════════════════════════════════════
struct HSEBbsView: View {
    @State private var todayRecord: HseBbsItem? = nil
    @State private var history:     [HseBbsItem] = []
    @State private var cardCount    = ""
    @State private var notes        = ""
    @State private var isLoading    = true
    @State private var saving       = false
    @State private var message      = ""
    @State private var showAlert    = false

    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section { ProgressView() }
                } else {
                    Section(header: Text("سجل BBS اليوم")) {
                        if let rec = todayRecord {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("تم التسجيل اليوم").font(.caption).foregroundColor(.secondary)
                                    Text("\(rec.card_count) بطاقة BBS").font(.headline)
                                    if !rec.notes.isEmpty {
                                        Text(rec.notes).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        TextField("عدد البطاقات *", text: $cardCount).keyboardType(.numberPad)
                        TextField("ملاحظات (اختياري)", text: $notes)
                        Button(todayRecord == nil ? "حفظ" : "تحديث") { Task { await save() } }
                            .disabled(saving || cardCount.trimmingCharacters(in: .whitespaces).isEmpty)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if !history.isEmpty {
                        Section(header: Text("السجل الأخير")) {
                            ForEach(history) { rec in
                                HStack {
                                    Text(formatDate(rec.date)).font(.subheadline)
                                    Spacer()
                                    Text("\(rec.card_count) بطاقة").font(.subheadline).bold()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("BBS اليومي")
            .task { await load() }
            .alert("", isPresented: $showAlert) { Button("حسناً") {} } message: { Text(message) }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        async let todayR = try? NetworkManager.shared.hseBbsToday()
        async let histR  = try? NetworkManager.shared.hseBbsList()
        let (t, h) = await (todayR, histR)
        todayRecord = t
        history = h ?? []
        if let t = t { cardCount = "\(t.card_count)"; notes = t.notes }
        isLoading = false
    }

    private func save() async {
        guard let count = Int(cardCount.trimmingCharacters(in: .whitespaces)) else {
            message = "أدخل رقماً صحيحاً"; showAlert = true; return
        }
        saving = true
        do {
            try await NetworkManager.shared.hseBbsSave(cardCount: count, notes: notes)
            await load()
            message = "تم الحفظ ✓"
        } catch {
            message = "فشل: \(error.localizedDescription)"
        }
        saving = false; showAlert = true
    }
}

// ── Edit TBT ────────────────────────────────────
struct HSEEditTbtView: View {
    let tbt: HseTbtItem
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var topic       = ""
    @State private var location    = ""
    @State private var attendees: [(emp_number: String, emp_name: String)] = []
    @State private var lookupInput = ""
    @State private var lookupMsg   = ""
    @State private var isLooking   = false
    @State private var saving      = false
    @State private var errorMsg    = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات TBT")) {
                    TextField("الموضوع *", text: $topic)
                    TextField("الموقع", text: $location)
                }
                Section(header: Text("صورة ورقة الحضور")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        HStack {
                            Image(systemName: photoData != nil ? "checkmark.circle.fill" : "camera")
                                .foregroundColor(photoData != nil ? .green : .secondary)
                            Text(photoData != nil ? "تم اختيار الصورة" : "اختيار صورة (اختياري)")
                                .foregroundColor(photoData != nil ? .green : .primary)
                        }
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self) {
                                photoData = data
                            } else {
                                photoData = nil
                            }
                        }
                    }
                }
                Section(header: Text("إضافة موظف")) {
                    HStack {
                        TextField("رقم الموظف", text: $lookupInput)
                            .keyboardType(.asciiCapable).autocapitalization(.allCharacters)
                        Button("بحث") { Task { await lookup() } }
                            .disabled(lookupInput.trimmingCharacters(in: .whitespaces).isEmpty || isLooking)
                    }
                    if !lookupMsg.isEmpty {
                        Text(lookupMsg).font(.caption)
                            .foregroundColor(lookupMsg.contains("✓") ? .green : .red)
                    }
                }
                if !attendees.isEmpty {
                    Section(header: Text("الحضور (\(attendees.count))")) {
                        ForEach(attendees, id: \.emp_number) { att in
                            HStack {
                                Text(att.emp_name)
                                Spacer()
                                Text(att.emp_number).foregroundColor(.secondary).font(.caption)
                            }
                        }
                        .onDelete { idx in attendees.remove(atOffsets: idx) }
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ التعديلات") { Task { await save() } }
                        .disabled(saving || topic.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("تعديل TBT")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
            .onAppear {
                topic    = tbt.topic
                location = tbt.location
                attendees = tbt.attendees.map { (emp_number: $0.emp_number, emp_name: $0.emp_name) }
            }
        }
    }

    private func lookup() async {
        let num = lookupInput.trimmingCharacters(in: .whitespaces)
        guard !num.isEmpty else { return }
        isLooking = true; lookupMsg = ""
        do {
            let res = try await NetworkManager.shared.hseEmployeeLookup(empNumber: num)
            if res.found, let name = res.name, let empNum = res.emp_number {
                if !attendees.contains(where: { $0.emp_number == empNum }) {
                    attendees.append((emp_number: empNum, emp_name: name))
                }
                lookupMsg = "✓ \(name)"; lookupInput = ""
            } else { lookupMsg = "الموظف غير موجود أو غير نشط" }
        } catch { lookupMsg = "خطأ في البحث" }
        isLooking = false
    }

    private func save() async {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { errorMsg = "الموضوع مطلوب"; return }
        saving = true; errorMsg = ""
        do {
            let atts = attendees.map { ["emp_number": $0.emp_number, "emp_name": $0.emp_name] }
            try await NetworkManager.shared.hseTbtUpdate(id: tbt.id, topic: t,
                                                         location: location, attendees: atts)
            if let img = photoData,
               let compressed = UIImage(data: img)?.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseTbtUploadPhoto(tbtId: tbt.id, imageData: compressed)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 7. HSE Supervisor Dashboard (hse_access users)
// ═══════════════════════════════════════════════════
struct HSEDashboardView: View {
    @State private var dashboard: HseDashboard? = nil
    @State private var charts:    HseChartsData? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    if isLoading {
                        ProgressView("جاري التحميل...").padding(.top, 80)
                    } else if let d = dashboard {
                        VStack(spacing: 16) {
                            kpiGrid(d)
                            officersSection(d)
                            weeklyTable(d)
                            if let c = charts { chartsSection(c) }
                            if !d.high_risk_open.isEmpty { highRiskSection(d) }
                            Spacer(minLength: 24)
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48)).foregroundColor(.orange)
                            Text(errorMsg.isEmpty ? "تعذّر تحميل البيانات" : errorMsg)
                                .multilineTextAlignment(.center).foregroundColor(.secondary)
                            Button("إعادة المحاولة") { Task { await loadAll() } }
                                .buttonStyle(.borderedProminent).tint(Color(hex: "#7b5ea7"))
                        }
                        .padding(40)
                    }
                }
                .refreshable { await loadAll() }
            }
            .navigationTitle("HSE Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HSEReportsView()) {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await loadAll() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await loadAll() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // ── KPI 2×2 grid ─────────────────────────────────
    @ViewBuilder
    private func kpiGrid(_ d: HseDashboard) -> some View {
        let checkedIn = d.officers.filter { $0.checked_in }.count
        let totalObs  = d.officers.reduce(0) { $0 + $1.obs_week }
        let totalTbt  = d.officers.reduce(0) { $0 + $1.tbt_week }
        let inactive  = d.officers.filter  { $0.total_week == 0 }.count

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HSEAdminKpiCard(value: "\(checkedIn)/\(d.officers.count)",
                            label: "Check-in اليوم",
                            icon: "location.fill",
                            color: checkedIn == d.officers.count ? .green : .orange)
            HSEAdminKpiCard(value: "\(totalObs)",
                            label: "ملاحظات الأسبوع",
                            icon: "eye.fill", color: .blue)
            HSEAdminKpiCard(value: "\(d.high_risk_open.count)",
                            label: "خطورة عالية مفتوحة",
                            icon: "exclamationmark.triangle.fill",
                            color: d.high_risk_open.isEmpty ? .green : .red)
            HSEAdminKpiCard(value: inactive > 0 ? "\(inactive)" : "\(totalTbt)",
                            label: inactive > 0 ? "بدون نشاط هذا الأسبوع" : "TBT الأسبوع",
                            icon: inactive > 0 ? "person.fill.xmark" : "megaphone.fill",
                            color: inactive > 0 ? .red : .purple)
        }
        .padding(.horizontal)
    }

    // ── Officers 2-column grid ────────────────────────
    @ViewBuilder
    private func officersSection(_ d: HseDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الأوفيسرز اليوم")
                .font(.headline).padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(d.officers) { o in
                    NavigationLink(destination: HSEOfficerDetailView(officer: o)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(o.checked_in ? Color.green : Color.red)
                                    .frame(width: 9, height: 9)
                                Text(o.name.components(separatedBy: " ").prefix(2).joined(separator: " "))
                                    .font(.subheadline).bold().foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            if let loc = o.location, !loc.isEmpty {
                                Label(loc, systemImage: "mappin")
                                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            } else {
                                Text(o.checked_in ? "—" : "لم يسجّل دخول")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                if o.obs_week > 0 { HSEActivityPill(n: o.obs_week, label: "OBS", color: .blue) }
                                if o.tbt_week > 0 { HSEActivityPill(n: o.tbt_week, label: "TBT", color: .purple) }
                                if o.jso_week > 0 { HSEActivityPill(n: o.jso_week, label: "JSO", color: .indigo) }
                                if o.nm_week  > 0 { HSEActivityPill(n: o.nm_week,  label: "NM",  color: .red) }
                                if o.total_week == 0 {
                                    Text("لا نشاط").font(.caption2).foregroundColor(.red)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(o.total_week == 0
                                    ? Color.red.opacity(0.04)
                                    : Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(o.checked_in
                                    ? Color.green.opacity(0.35)
                                    : Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // ── Weekly summary table ──────────────────────────
    @ViewBuilder
    private func weeklyTable(_ d: HseDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ملخص الأسبوع").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("الاسم").frame(width: 110, alignment: .leading)
                            .font(.caption).bold().foregroundColor(.secondary)
                        ForEach(["OBS","JSO","TBT","NM","BBS"], id: \.self) { col in
                            Text(col).frame(width: 44, alignment: .center)
                                .font(.caption).bold().foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 7).padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    Divider()
                    ForEach(d.officers) { o in
                        HStack(spacing: 0) {
                            Text(o.name.components(separatedBy: " ").first ?? "")
                                .frame(width: 110, alignment: .leading)
                                .font(.caption).lineLimit(1)
                            wkCell(o.obs_week, hi: .blue)
                            wkCell(o.jso_week, hi: .indigo)
                            wkCell(o.tbt_week, hi: .purple)
                            wkCell(o.nm_week,  hi: .red)
                            wkCell(o.bbs_week, hi: .green)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(o.total_week == 0 ? Color.red.opacity(0.04) : Color.clear)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private func wkCell(_ n: Int, hi: Color) -> some View {
        Text(n == 0 ? "—" : "\(n)")
            .frame(width: 44, alignment: .center)
            .font(.caption)
            .foregroundColor(n > 0 ? hi : Color.secondary.opacity(0.4))
    }

    // ── Charts section ────────────────────────────────
    @ViewBuilder
    private func chartsSection(_ c: HseChartsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الرسوم البيانية").font(.headline).padding(.horizontal)

            // Observation trend
            VStack(alignment: .leading, spacing: 6) {
                Text("اتجاه الملاحظات (4 أسابيع)")
                    .font(.subheadline).bold().foregroundColor(.secondary)
                HSEObsTrendChart(trend: c.obs_trend)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            // Officer scores
            if !c.officer_scores.labels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("نشاط الأوفيسرز هذا الأسبوع")
                        .font(.subheadline).bold().foregroundColor(.secondary)
                    HSEOfficerScoreChart(data: c.officer_scores)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Manpower trend
            if !c.mp_data.labels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("القوى العاملة (آخر 7 أيام)")
                        .font(.subheadline).bold().foregroundColor(.secondary)
                    HSEMpTrendChart(mp: c.mp_data)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Category breakdown
            if !c.cat_data.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("توزيع الفئات")
                        .font(.subheadline).bold().foregroundColor(.secondary)
                    HSECategoryBarsView(data: c.cat_data)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // ── High-risk section ─────────────────────────────
    @ViewBuilder
    private func highRiskSection(_ d: HseDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("خطورة عالية مفتوحة (\(d.high_risk_open.count))",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundColor(.red).padding(.horizontal)
            ForEach(d.high_risk_open) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(formatDate(item.date)).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(item.officer).font(.caption).bold().foregroundColor(.secondary)
                    }
                    if !item.category.isEmpty {
                        Text(item.category).font(.subheadline).bold()
                    }
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "mappin")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if !item.description.isEmpty {
                        Text(item.description).font(.caption).lineLimit(2)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.04))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1))
                .padding(.horizontal)
            }
        }
    }

    private func loadAll() async {
        isLoading = true; errorMsg = ""
        async let d = NetworkManager.shared.hseDashboard()
        async let cRaw = NetworkManager.shared.hseCharts()
        do { dashboard = try await d }
        catch let e as NSError {
            let code = (e.userInfo["statusCode"] as? Int) ?? 0
            errorMsg = code == 403 ? "لا تملك صلاحية HSE — سجّل خروج ودخول مجدداً"
                     : code == 404 ? "السيرفر لم يُحدَّث بعد"
                     : "تعذّر تحميل البيانات"
        }
        charts = try? await cRaw
        isLoading = false
    }
}

// ── Helper structs for HSE Dashboard ─────────────────

private struct HSEAdminKpiCard: View {
    let value: String
    let label: String
    let icon:  String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Spacer()
            }
            Text(value).font(.title2).bold().foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

private struct HSEActivityPill: View {
    let n: Int; let label: String; let color: Color
    var body: some View {
        Text("\(n) \(label)").font(.system(size: 9)).bold()
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.12)).foregroundColor(color).cornerRadius(6)
    }
}

private struct HSEObsTrendChart: View {
    let trend: HseObsTrend

    private func total(at i: Int) -> Int {
        let ua  = i < trend.unsafe_act.count  ? trend.unsafe_act[i]  : 0
        let uc  = i < trend.unsafe_cond.count ? trend.unsafe_cond[i] : 0
        let pos = i < trend.positive.count    ? trend.positive[i]    : 0
        return ua + uc + pos
    }

    private var totals: [Int] {
        (0..<trend.labels.count).map { total(at: $0) }
    }

    private var maxVal: Double { Double(max(totals.max() ?? 1, 1)) }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<trend.labels.count, id: \.self) { i in
                    let t = total(at: i)
                    let h = max(4, geo.size.height * 0.75 * CGFloat(t) / CGFloat(maxVal))
                    let grad = LinearGradient(colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.4)],
                                             startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 3) {
                        Text("\(t)").font(.system(size: 10)).foregroundColor(.blue)
                        RoundedRectangle(cornerRadius: 4).fill(grad).frame(height: h)
                        Text(trend.labels[i]).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 90)
    }
}

private struct HSEOfficerScoreChart: View {
    let data: HseOfficerScores
    private var maxScore: Double { max(data.scores.max() ?? 1, 1) }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<data.labels.count, id: \.self) { i in
                    let score = i < data.scores.count ? data.scores[i] : 0
                    let name  = data.labels[i].components(separatedBy: " ").first ?? ""
                    let h = max(4, 80 * CGFloat(score) / CGFloat(maxScore))
                    VStack(spacing: 3) {
                        Text(String(format: "%.0f", score))
                            .font(.system(size: 10)).foregroundColor(.purple)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.3)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 32, height: h)
                        Text(name).font(.system(size: 9)).foregroundColor(.secondary)
                            .lineLimit(1).frame(width: 40)
                    }
                }
            }
            .frame(height: 100)
            .padding(.horizontal, 4)
        }
    }
}

private struct HSEMpTrendChart: View {
    let mp: HseMpTrend
    private var maxCount: Int { max(mp.counts.max() ?? 1, 1) }
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<mp.labels.count, id: \.self) { i in
                    let count = i < mp.counts.count ? mp.counts[i] : 0
                    let h = max(4, geo.size.height * 0.75 * CGFloat(count) / CGFloat(maxCount))
                    let dayLabel = mp.labels[i].components(separatedBy: " ").last ?? ""
                    VStack(spacing: 2) {
                        if count > 0 {
                            Text("\(count)").font(.system(size: 8)).foregroundColor(.teal)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color.teal.opacity(0.8), Color.teal.opacity(0.3)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: h)
                        Text(dayLabel).font(.system(size: 8)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 80)
    }
}

private struct HSECategoryBarsView: View {
    let data: [String: Int]
    private var sorted: [(String, Int)] {
        data.sorted { $0.value > $1.value }
    }
    private var maxVal: Int { sorted.first?.1 ?? 1 }
    var body: some View {
        VStack(spacing: 6) {
            ForEach(sorted.prefix(6), id: \.0) { cat, count in
                HStack(spacing: 8) {
                    Text(cat).font(.caption2).foregroundColor(.secondary)
                        .frame(width: 90, alignment: .trailing)
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxVal))
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 14)
                    Text("\(count)").font(.caption2).bold().foregroundColor(.orange)
                        .frame(width: 24, alignment: .leading)
                }
            }
        }
    }
}

// ── URL Identifiable for .sheet(item:) ───────────────
extension URL: @retroactive Identifiable { public var id: String { absoluteString } }


// ═══════════════════════════════════════════════════
//  MARK: - HSE Reports (Native)
// ═══════════════════════════════════════════════════

struct HSEReportsView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("أسبوعي").tag(0)
                Text("شهري").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 8)
            Divider()
            if tab == 0 { HSEWeeklyReportContent() }
            else         { HSEMonthlyReportContent() }
        }
        .navigationTitle("التقارير")
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// ── Weekly ────────────────────────────────────────────────────────────

private struct HSEWeeklyReportContent: View {
    @State private var weekOffset  = 0
    @State private var report:     HseWeeklyReport? = nil
    @State private var isLoading   = true
    @State private var errorMsg    = ""
    @State private var pdfBusy     = false
    @State private var pdfShareUrl: URL? = nil

    private var weekStartDate: Date {
        let cal     = Calendar(identifier: .gregorian)
        let today   = Date()
        let weekday = cal.component(.weekday, from: today) - 1   // 0=Sun
        let thisSun = cal.date(byAdding: .day, value: -weekday, to: today)!
        return cal.date(byAdding: .day, value: weekOffset * 7, to: thisSun)!
    }

    private var weekLabel: String {
        let cal = Calendar(identifier: .gregorian)
        let end = cal.date(byAdding: .day, value: 6, to: weekStartDate)!
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "en")
        return "\(f.string(from: weekStartDate)) — \(f.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { weekOffset -= 1; Task { await load() } } label: {
                    Image(systemName: "chevron.right").font(.title3).padding(10)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("الأسبوع").font(.caption).foregroundColor(.secondary)
                    Text(weekLabel).font(.subheadline).bold()
                }
                Spacer()
                Button { weekOffset += 1; Task { await load() } } label: {
                    Image(systemName: "chevron.left").font(.title3).padding(10)
                }
                .disabled(weekOffset >= 0).opacity(weekOffset >= 0 ? 0.3 : 1)
            }
            .padding(.horizontal, 4)
            .background(Color(.systemGray6))
            Divider()
            reportBody
        }
        .task { await load() }
    }

    @ViewBuilder
    private var reportBody: some View {
        if isLoading {
            ProgressView("جاري التحميل...").frame(maxWidth:.infinity).padding(.top, 60)
            Spacer()
        } else if let r = report, !r.rows.isEmpty {
            ScrollView {
                VStack(spacing: 14) {
                    HSEReportKpiStrip(rows: r.rows, prevRows: r.prev_rows ?? [])
                    HSEReportTable(rows: r.rows, prevRows: r.prev_rows ?? [])
                }
                .padding(.vertical, 10)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await exportWeeklyPdf(r) }
                } label: {
                    if pdfBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(12)
                            .background(Color.blue).cornerRadius(12)
                    } else {
                        Label("تصدير PDF", systemImage: "printer.fill")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                .disabled(pdfBusy)
            }
            .sheet(item: $pdfShareUrl) { HSEShareSheet(url: $0) }
        } else if report != nil {
            VStack {
                Text("لا يوجد بيانات لهذا الأسبوع").foregroundColor(.secondary).padding(.top, 60)
                Spacer()
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundColor(.orange)
                Text(errorMsg).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button("إعادة المحاولة") { Task { await load() } }.buttonStyle(.borderedProminent)
            }.padding(.top, 40)
            Spacer()
        }
    }

    @MainActor private func exportWeeklyPdf(_ r: HseWeeklyReport) async {
        pdfBusy = true
        pdfShareUrl = await makeReportPdf(
            title: "التقرير الأسبوعي",
            period: weekLabel,
            rows: r.rows,
            prevRows: r.prev_rows ?? []
        )
        pdfBusy = false
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { report = try await NetworkManager.shared.hseWeeklyReport(weekStart: weekStartDate.iso) }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

// ── Monthly ───────────────────────────────────────────────────────────

private struct HSEMonthlyReportContent: View {
    @State private var year:   Int
    @State private var month:  Int
    @State private var report: HseMonthlyReport? = nil
    @State private var isLoading  = true
    @State private var errorMsg   = ""
    @State private var pdfBusy    = false
    @State private var pdfShareUrl: URL? = nil

    init() {
        let c = Calendar.current
        _year  = State(initialValue: c.component(.year,  from: Date()))
        _month = State(initialValue: c.component(.month, from: Date()))
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "en")
        let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        return f.string(from: d)
    }

    private func shift(_ delta: Int) {
        var m = month + delta; var y = year
        if m < 1  { m = 12; y -= 1 }
        if m > 12 { m = 1;  y += 1 }
        month = m; year = y
        Task { await load() }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.right").font(.title3).padding(10) }
                Spacer()
                VStack(spacing: 2) {
                    Text("الشهر").font(.caption).foregroundColor(.secondary)
                    Text(monthLabel).font(.subheadline).bold()
                }
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.left").font(.title3).padding(10) }
                .disabled(isCurrentOrFutureMonth).opacity(isCurrentOrFutureMonth ? 0.3 : 1)
            }
            .padding(.horizontal, 4).background(Color(.systemGray6))
            Divider()
            reportBody
        }
        .task { await load() }
    }

    private var isCurrentOrFutureMonth: Bool {
        let c = Calendar.current
        let cy = c.component(.year, from: Date()); let cm = c.component(.month, from: Date())
        return (year > cy) || (year == cy && month >= cm)
    }

    @ViewBuilder
    private var reportBody: some View {
        if isLoading {
            ProgressView("جاري التحميل...").frame(maxWidth:.infinity).padding(.top, 60)
            Spacer()
        } else if let r = report, !r.rows.isEmpty {
            ScrollView {
                VStack(spacing: 14) {
                    HSEReportKpiStrip(rows: r.rows, prevRows: r.prev_rows ?? [])
                    HSEReportTable(rows: r.rows, prevRows: r.prev_rows ?? [])
                }
                .padding(.vertical, 10)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await exportMonthlyPdf(r) }
                } label: {
                    if pdfBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(12)
                            .background(Color.blue).cornerRadius(12)
                    } else {
                        Label("تصدير PDF", systemImage: "printer.fill")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                .disabled(pdfBusy)
            }
            .sheet(item: $pdfShareUrl) { HSEShareSheet(url: $0) }
        } else if report != nil {
            VStack { Text("لا يوجد بيانات لهذا الشهر").foregroundColor(.secondary).padding(.top, 60); Spacer() }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundColor(.orange)
                Text(errorMsg).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button("إعادة المحاولة") { Task { await load() } }.buttonStyle(.borderedProminent)
            }.padding(.top, 40)
            Spacer()
        }
    }

    @MainActor private func exportMonthlyPdf(_ r: HseMonthlyReport) async {
        pdfBusy = true
        pdfShareUrl = await makeReportPdf(
            title: "التقرير الشهري",
            period: monthLabel,
            rows: r.rows,
            prevRows: r.prev_rows ?? []
        )
        pdfBusy = false
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { report = try await NetworkManager.shared.hseMonthlyReport(year: year, month: month) }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

// ── Trend helper ──────────────────────────────────────────────────────
private func trendInfo(cur: Int, prev: Int) -> (symbol: String, color: Color, pct: String) {
    if prev == 0 && cur == 0 { return ("—", .secondary, "") }
    if prev == 0 { return ("▲", .green, "") }
    let diff = cur - prev
    let pct  = Int(round(Double(abs(diff)) / Double(prev) * 100))
    if diff > 0 { return ("▲", .green,  "+\(pct)%") }
    if diff < 0 { return ("▼", .red,    "-\(pct)%") }
    return ("─", .secondary, "0%")
}

// ── Shared: KPI Strip ─────────────────────────────────────────────────

private struct HSEReportKpiStrip: View {
    let rows:     [HseReportRow]
    let prevRows: [HseReportRow]

    var body: some View {
        let totalObs  = rows.reduce(0) { $0 + $1.obs_total }
        let totalTbt  = rows.reduce(0) { $0 + $1.tbt }
        let totalBbs  = rows.reduce(0) { $0 + $1.bbs }
        let highRisk  = rows.reduce(0) { $0 + $1.obs_high }
        let nm        = rows.reduce(0) { $0 + $1.nm }
        let inactive  = rows.filter { $0.total_activity == 0 }.count

        let pObs     = prevRows.reduce(0) { $0 + $1.obs_total }
        let pTbt     = prevRows.reduce(0) { $0 + $1.tbt }
        let pBbs     = prevRows.reduce(0) { $0 + $1.bbs }
        let pHigh    = prevRows.reduce(0) { $0 + $1.obs_high }
        let pNm      = prevRows.reduce(0) { $0 + $1.nm }
        let pInact   = prevRows.filter { $0.total_activity == 0 }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            HSETrendKpiCard(value: "\(totalObs)",  label: "ملاحظات",    icon: "eye.fill",                                      color: .blue,   trend: trendInfo(cur: totalObs, prev: pObs))
            HSETrendKpiCard(value: "\(totalTbt)",  label: "TBT",         icon: "person.3.fill",                                 color: .purple, trend: trendInfo(cur: totalTbt, prev: pTbt))
            HSETrendKpiCard(value: "\(totalBbs)",  label: "BBS بطاقات",  icon: "checkmark.circle.fill",                         color: .teal,   trend: trendInfo(cur: totalBbs, prev: pBbs))
            HSETrendKpiCard(value: "\(highRisk)",  label: "خطورة عالية", icon: "exclamationmark.triangle.fill",                  color: highRisk == 0 ? .green : .red, trend: trendInfo(cur: highRisk, prev: pHigh))
            HSETrendKpiCard(value: "\(nm)",        label: "Near Miss",   icon: "bolt.trianglebadge.exclamationmark.fill",        color: nm == 0 ? .green : .red,       trend: trendInfo(cur: nm,       prev: pNm))
            HSETrendKpiCard(value: "\(inactive)",  label: "بلا نشاط",   icon: "person.fill.xmark",                             color: inactive == 0 ? .green : .red,  trend: trendInfo(cur: inactive, prev: pInact))
        }
        .padding(.horizontal)
    }
}

private struct HSETrendKpiCard: View {
    let value: String
    let label: String
    let icon:  String
    let color: Color
    let trend: (symbol: String, color: Color, pct: String)

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.title3.bold()).foregroundColor(color)
            if !trend.pct.isEmpty {
                HStack(spacing: 2) {
                    Text(trend.symbol).font(.caption2.bold()).foregroundColor(trend.color)
                    Text(trend.pct).font(.caption2).foregroundColor(trend.color)
                }
            } else {
                Text(trend.symbol).font(.caption2).foregroundColor(trend.color)
            }
            Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// ── Shared: Report Table ──────────────────────────────────────────────

private struct HSEReportTable: View {
    let rows:     [HseReportRow]
    let prevRows: [HseReportRow]

    private var prevByOfficer: [Int: HseReportRow] {
        Dictionary(uniqueKeysWithValues: prevRows.map { ($0.officer_id, $0) })
    }

    var body: some View {
        let prev = prevByOfficer
        VStack(alignment: .leading, spacing: 6) {
            Text("تفاصيل الأوفيسرز").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        rth("الاسم",  120)
                        rth("CI",      36)
                        rth("OBS",     38)
                        rth("UA",      32)
                        rth("UC",      32)
                        rth("POS",     36)
                        rth("H",       28)
                        rth("JSO",     36)
                        rth("TBT",     36)
                        rth("TBT👥",   40)
                        rth("NM",      32)
                        rth("BBS",     38)
                        rth("Score",   50)
                        rth("▲▼",      34)
                    }
                    .padding(.vertical, 8)
                    .background(Color(hex: "#0F172A"))
                    Divider()
                    ForEach(rows) { row in
                        let p = prev[row.officer_id]
                        let t = trendInfo(cur: row.total_activity, prev: p?.total_activity ?? 0)
                        HStack(spacing: 0) {
                            Text(row.officer_name.components(separatedBy: " ").prefix(2).joined(separator: " "))
                                .frame(width: 120, alignment: .leading).font(.caption).lineLimit(1).padding(.leading, 6)
                            nc(row.checkin_days,      36, row.checkin_days      > 0 ? .teal    : .secondary)
                            nc(row.obs_total,         38, row.obs_total         > 0 ? .blue    : .secondary)
                            nc(row.obs_unsafe_act,    32, row.obs_unsafe_act    > 0 ? .red     : .secondary)
                            nc(row.obs_unsafe_cond,   32, row.obs_unsafe_cond   > 0 ? .orange  : .secondary)
                            nc(row.obs_positive,      36, row.obs_positive      > 0 ? .green   : .secondary)
                            nc(row.obs_high,          28, row.obs_high          > 0 ? .red     : .secondary)
                            nc(row.jso,               36, row.jso               > 0 ? .indigo  : .secondary)
                            nc(row.tbt,               36, row.tbt               > 0 ? .purple  : .secondary)
                            nc(row.tbt_attendees,     40, row.tbt_attendees     > 0 ? Color.purple.opacity(0.7) : .secondary)
                            nc(row.nm,                32, row.nm                > 0 ? .red     : .secondary)
                            nc(row.bbs,               38, row.bbs               > 0 ? .teal    : .secondary)
                            scoreCell(row.score, 50)
                            Text(t.symbol).frame(width: 34, alignment: .center)
                                .font(.caption.bold()).foregroundColor(t.color)
                        }
                        .padding(.vertical, 7)
                        .background(row.total_activity == 0 ? Color.red.opacity(0.05) : Color.clear)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal)
        }
    }

    private func rth(_ text: String, _ w: CGFloat) -> some View {
        Text(text).frame(width: w, alignment: .center)
            .font(.caption.bold()).foregroundColor(.white)
    }

    private func nc(_ n: Int, _ w: CGFloat, _ color: Color) -> some View {
        Text(n == 0 ? "—" : "\(n)").frame(width: w, alignment: .center)
            .font(.caption).foregroundColor(n > 0 ? color : .secondary.opacity(0.35))
    }

    private func scoreCell(_ score: Double, _ w: CGFloat) -> some View {
        let color: Color = score >= 15 ? .green : score >= 8 ? .orange : .red
        return Text(String(format: "%.1f", score)).frame(width: w, alignment: .center)
            .font(.caption.bold()).foregroundColor(color)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - HSE Photo Loader (Bearer token)
// ═══════════════════════════════════════════════════

struct HSEPhotoView: View {
    let path: String
    var height: CGFloat = 220
    @State private var image: UIImage? = nil
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: height)
                    .background(Color(.systemGray6)).cornerRadius(10)
            } else if let img = image {
                Image(uiImage: img).resizable().scaledToFit()
                    .cornerRadius(10)
            } else {
                Label("تعذّر تحميل الصورة", systemImage: "photo.slash")
                    .foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard !path.isEmpty,
              let url = URL(string: BASE_URL + "/api/hse/photo/\(path)") else {
            loading = false; return
        }
        var req = URLRequest(url: url)
        if let token = SessionManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let img = UIImage(data: data) { image = img }
        loading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Record Detail Sheets
// ═══════════════════════════════════════════════════

struct HSEObsDetailSheet: View {
    let obs: HseObservationItem
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("معلومات أساسية")) {
                    LabeledContent("التاريخ",   value: formatDate(obs.date))
                    LabeledContent("الموقع",    value: obs.location.isEmpty ? "—" : obs.location)
                    LabeledContent("النوع",     value: obsTypeLbl(obs.obs_type))
                    LabeledContent("الفئة",     value: obs.category.isEmpty ? "—" : obs.category)
                    HStack {
                        Text("الخطورة")
                        Spacer()
                        riskChip(obs.risk_level)
                    }
                    HStack {
                        Text("الحالة")
                        Spacer()
                        Text(obs.status == "closed" ? "مغلق ✅" : "مفتوح 🔴")
                            .foregroundColor(obs.status == "closed" ? .green : .red)
                    }
                }
                if !obs.description.isEmpty {
                    Section(header: Text("الوصف")) { Text(obs.description) }
                }
                if !obs.action_taken.isEmpty {
                    Section(header: Text("الإجراء الفوري")) { Text(obs.action_taken) }
                }
                if obs.status == "closed" {
                    if let dat = obs.closed_at {
                        Section(header: Text("بيانات الإغلاق")) {
                            LabeledContent("تاريخ الإغلاق", value: formatDate(dat))
                            if !obs.closure_action.isEmpty {
                                Text(obs.closure_action)
                            }
                        }
                    }
                }
                let photos = obs.photos ?? []
                if !photos.isEmpty {
                    Section(header: Text("الصور (\(photos.count))")) {
                        ForEach(photos, id: \.path) { p in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.photo_type == "after" ? "بعد" : "قبل")
                                    .font(.caption).foregroundColor(.secondary)
                                HSEPhotoView(path: p.path)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("تفاصيل الملاحظة")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("إغلاق") { dismiss() }
            }}
        }
    }
    @ViewBuilder private func riskChip(_ r: String) -> some View {
        let (lbl, c): (String, Color) = r == "H" ? ("عالي", .red) : r == "M" ? ("متوسط", .orange) : ("منخفض", .green)
        Text(lbl).font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 3)
            .background(c.opacity(0.15)).foregroundColor(c).cornerRadius(5)
    }
    private func obsTypeLbl(_ t: String) -> String {
        switch t { case "unsafe_act": return "فعل خطر"
                   case "unsafe_condition": return "حالة خطرة"
                   case "positive": return "إيجابي"
                   default: return t }
    }
}

struct HSETbtDetailSheet: View {
    let tbt: HseTbtDetailItem
    @Environment(\.dismiss) var dismiss
    @State private var pdfBusy    = false
    @State private var pdfShareUrl: URL? = nil

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("معلومات TBT")) {
                    LabeledContent("التاريخ",  value: formatDate(tbt.date))
                    LabeledContent("الموضوع",  value: tbt.topic.isEmpty ? "—" : tbt.topic)
                    LabeledContent("الموقع",   value: tbt.location.isEmpty ? "—" : tbt.location)
                    if let sup = tbt.supervisor_name, !sup.isEmpty {
                        LabeledContent("المشرف", value: sup)
                    }
                    LabeledContent("عدد الحضور", value: "\(tbt.attendee_count) شخص")
                }
                let list = tbt.attendees ?? []
                let supName = tbt.supervisor_name ?? ""
                if !list.isEmpty || !supName.isEmpty {
                    Section(header: Text("قائمة الحضور")) {
                        if !supName.isEmpty {
                            HStack {
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .foregroundColor(.blue).frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(supName).font(.subheadline).fontWeight(.semibold)
                                    Text("المشرف").font(.caption).foregroundColor(.blue)
                                }
                            }
                        }
                        ForEach(Array(list.enumerated()), id: \.offset) { i, a in
                            HStack {
                                Text("\(i+1)").font(.caption).foregroundColor(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.emp_name.isEmpty ? "—" : a.emp_name).font(.subheadline)
                                    Text(a.emp_number).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                if let sp = tbt.sign_photo_path, !sp.isEmpty {
                    Section(header: Text("صورة ورقة الحضور")) {
                        HSEPhotoView(path: sp)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("تفاصيل TBT")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if pdfBusy {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button { Task { await exportPdf() } } label: {
                            Image(systemName: "printer.fill")
                        }
                    }
                }
            }
            .sheet(item: $pdfShareUrl) { HSEShareSheet(url: $0) }
        }
    }

    @MainActor private func exportPdf() async {
        pdfBusy = true
        let list = tbt.attendees ?? []
        pdfShareUrl = await makeTbtPdf(
            topic:          tbt.topic,
            date:           tbt.date,
            location:       tbt.location,
            supervisorName: tbt.supervisor_name ?? "",
            attendees:      list.map { ($0.emp_name, $0.emp_number) }
        )
        pdfBusy = false
    }
}

struct HSEJsoDetailSheet: View {
    let jso: HseJsoItem
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("معلومات JSO")) {
                    LabeledContent("التاريخ",  value: formatDate(jso.date))
                    LabeledContent("رقم JSO",  value: jso.jso_number)
                    LabeledContent("الموقع",   value: jso.location.isEmpty ? "—" : jso.location)
                }
                if !jso.action_taken.isEmpty {
                    Section(header: Text("الإجراء المتخذ")) { Text(jso.action_taken) }
                }
                if let p = jso.photo_path, !p.isEmpty {
                    Section(header: Text("صورة الإثبات")) { HSEPhotoView(path: p) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("تفاصيل JSO")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("إغلاق") { dismiss() }
            }}
        }
    }
}

struct HSENearMissDetailSheet: View {
    let nm: HseNearMissItem
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("معلومات الحادث")) {
                    LabeledContent("التاريخ",    value: formatDate(nm.date))
                    LabeledContent("الموقع",     value: nm.location.isEmpty ? "—" : nm.location)
                    LabeledContent("أُبلغ إلى",  value: nm.reported_to.isEmpty ? "—" : nm.reported_to)
                }
                if !nm.description.isEmpty {
                    Section(header: Text("وصف الحادث")) { Text(nm.description) }
                }
                if !nm.immediate_cause.isEmpty {
                    Section(header: Text("السبب المباشر")) { Text(nm.immediate_cause) }
                }
                if !nm.action_taken.isEmpty {
                    Section(header: Text("الإجراء المتخذ")) { Text(nm.action_taken) }
                }
                if let p = nm.photo_path, !p.isEmpty {
                    Section(header: Text("الصورة")) { HSEPhotoView(path: p) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("تفاصيل Near Miss")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("إغلاق") { dismiss() }
            }}
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Officer Detail View (Supervisor)
// ═══════════════════════════════════════════════════

struct HSEOfficerDetailView: View {
    let officer: HseDashboardOfficer
    @State private var detail: HseOfficerDetailResponse? = nil
    @State private var isLoading    = true
    @State private var errorMsg     = ""
    @State private var days         = 30
    @State private var selObs:  HseObservationItem? = nil
    @State private var selTbt:  HseTbtDetailItem?   = nil
    @State private var selJso:  HseJsoItem?         = nil
    @State private var selNm:   HseNearMissItem?    = nil
    @State private var pdfURL:  URL?                = nil
    @State private var makingPDF = false

    private let periodOptions = [(7, "7 أيام"), (30, "شهر"), (90, "3 أشهر")]

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = detail {
                List {
                    // ── Period picker ──────────────────────
                    Section {
                        Picker("الفترة", selection: $days) {
                            ForEach(periodOptions, id: \.0) { opt in
                                Text(opt.1).tag(opt.0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: days) { _ in Task { await load() } }
                    }

                    // ── Status today ───────────────────────
                    Section {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(officer.checked_in ? Color.green : Color.red.opacity(0.6))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(officer.checked_in ? "مسجل دخول اليوم" : "لم يسجل دخول اليوم")
                                    .font(.subheadline).bold()
                                    .foregroundColor(officer.checked_in ? .green : .red)
                                if let loc = officer.location, !loc.isEmpty {
                                    Text("📍 \(loc)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                let total = d.observations.count + d.tbts.count + d.jso_closures.count + d.near_misses.count
                                Text("\(total)").font(.title2).bold().foregroundColor(.blue)
                                Text("نشاط/\(days)ي").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // ── KPI Cards ──────────────────────────
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                let ciDays   = d.checkin_history.count
                                let ciRate   = d.period_days > 0 ? Int(round(Double(ciDays) / Double(d.period_days) * 100)) : 0
                                let highRisk = d.observations.filter { $0.risk_level == "H" }.count
                                let openObs  = d.observations.filter { $0.status == "open" }.count
                                let bbsTotal = d.bbs.reduce(0) { $0 + $1.card_count }
                                officerKpi("\(ciRate)%",             "Check-in",      ciRate >= 80 ? .green : ciRate >= 50 ? .orange : .red)
                                officerKpi("\(d.observations.count)", "ملاحظات",      .blue)
                                officerKpi("\(highRisk)",            "خطورة عالية",   highRisk == 0 ? .green : .red)
                                officerKpi("\(openObs)",             "مفتوحة",        openObs == 0 ? .green : .orange)
                                officerKpi("\(d.tbts.count)",        "TBT",           .purple)
                                officerKpi("\(d.near_misses.count)", "Near Miss",     d.near_misses.count == 0 ? .green : .red)
                                officerKpi("\(bbsTotal)",            "BBS بطاقات",   .teal)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                    }

                    // ── Check-in History ───────────────────
                    if !d.checkin_history.isEmpty {
                        Section(header: Label("سجل الحضور (\(d.checkin_history.count) يوم)", systemImage: "location.fill")
                            .foregroundColor(.teal)) {
                            ForEach(d.checkin_history, id: \.id) { ci in
                                HStack {
                                    Text(formatDate(ci.date)).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text("📍 \(ci.location)").font(.caption)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // ── Observations ───────────────────────
                    if !d.observations.isEmpty {
                        Section(header: Label("الملاحظات (\(d.observations.count))", systemImage: "eye.fill")
                            .foregroundColor(.blue)) {
                            ForEach(d.observations) { obs in
                                Button { selObs = obs } label: {
                                    obsRow(obs)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── TBTs ───────────────────────────────
                    if !d.tbts.isEmpty {
                        Section(header: Label("TBT (\(d.tbts.count))", systemImage: "person.3.fill")
                            .foregroundColor(.purple)) {
                            ForEach(d.tbts) { t in
                                Button { selTbt = t } label: {
                                    tbtRow(t).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── JSO Closures ───────────────────────
                    if !d.jso_closures.isEmpty {
                        Section(header: Label("JSO (\(d.jso_closures.count))", systemImage: "doc.badge.plus")
                            .foregroundColor(.orange)) {
                            ForEach(d.jso_closures) { j in
                                Button { selJso = j } label: {
                                    jsoRow(j).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── Near Misses ────────────────────────
                    if !d.near_misses.isEmpty {
                        Section(header: Label("Near Miss (\(d.near_misses.count))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)) {
                            ForEach(d.near_misses) { n in
                                Button { selNm = n } label: {
                                    nearMissRow(n).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── BBS ────────────────────────────────
                    if !d.bbs.isEmpty {
                        let totalCards = d.bbs.reduce(0) { $0 + $1.card_count }
                        Section(header: Label("BBS — \(totalCards) بطاقة", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)) {
                            ForEach(d.bbs) { b in bbsRow(b) }
                        }
                    }

                    if d.observations.isEmpty && d.tbts.isEmpty && d.jso_closures.isEmpty
                        && d.near_misses.isEmpty && d.bbs.isEmpty {
                        Section {
                            Text("لا يوجد نشاط في آخر \(days) يوم")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                // ── Detail sheets ──────────────────────
                .sheet(item: $selObs)  { HSEObsDetailSheet(obs: $0) }
                .sheet(item: $selTbt)  { HSETbtDetailSheet(tbt: $0) }
                .sheet(item: $selJso)  { HSEJsoDetailSheet(jso: $0) }
                .sheet(item: $selNm)   { HSENearMissDetailSheet(nm: $0) }
                // ── PDF share ──────────────────────────
                .sheet(item: $pdfURL) { url in
                    ShareSheet(items: [url])
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            if let d = detail { Task { await exportPDF(d) } }
                        } label: {
                            if makingPDF { ProgressView() }
                            else { Image(systemName: "doc.richtext.fill") }
                        }
                        .disabled(makingPDF)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle).foregroundColor(.orange)
                    Text(errorMsg.isEmpty ? "فشل التحميل" : errorMsg)
                        .multilineTextAlignment(.center)
                    Button("إعادة المحاولة") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle(officer.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    // ── KPI mini card ─────────────────────────────────

    private func officerKpi(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).bold().foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(width: 72, height: 58)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // ── Row builders ──────────────────────────────────

    @ViewBuilder
    private func obsRow(_ obs: HseObservationItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(formatDate(obs.date)).font(.caption).foregroundColor(.secondary)
                Spacer()
                riskBadge(obs.risk_level)
                statusBadge(obs.status)
            }
            HStack(spacing: 6) {
                Text(obsTypeLabel(obs.obs_type)).font(.caption).bold()
                if !obs.category.isEmpty {
                    Text("· \(obs.category)").font(.caption).foregroundColor(.secondary)
                }
            }
            if !obs.location.isEmpty {
                Text("📍 \(obs.location)").font(.caption2).foregroundColor(.secondary)
            }
            if !obs.description.isEmpty {
                Text(obs.description).font(.caption).lineLimit(3)
                    .foregroundColor(.primary.opacity(0.85))
            }
            if !obs.action_taken.isEmpty {
                Text("⚡ \(obs.action_taken)").font(.caption2).foregroundColor(.blue).lineLimit(2)
            }
            if obs.status == "closed", !obs.closure_action.isEmpty {
                Text("✅ \(obs.closure_action)").font(.caption2).foregroundColor(.green).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func tbtRow(_ t: HseTbtDetailItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(t.date)).font(.caption).foregroundColor(.secondary)
                Spacer()
                Label("\(t.attendee_count) شخص", systemImage: "person.2.fill")
                    .font(.caption).foregroundColor(.purple)
            }
            if !t.topic.isEmpty {
                Text(t.topic).font(.subheadline).bold()
            }
            if !t.location.isEmpty {
                Text("📍 \(t.location)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func jsoRow(_ j: HseJsoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(j.date)).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("JSO #\(j.jso_number)").font(.caption).bold().foregroundColor(.orange)
            }
            if !j.location.isEmpty {
                Text("📍 \(j.location)").font(.caption2).foregroundColor(.secondary)
            }
            if !j.action_taken.isEmpty {
                Text(j.action_taken).font(.caption).lineLimit(3)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func nearMissRow(_ n: HseNearMissItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(n.date)).font(.caption).foregroundColor(.secondary)
                Spacer()
                if !n.reported_to.isEmpty {
                    Text("أُبلغ: \(n.reported_to)").font(.caption2).foregroundColor(.red)
                }
            }
            if !n.location.isEmpty {
                Text("📍 \(n.location)").font(.caption2).foregroundColor(.secondary)
            }
            if !n.description.isEmpty {
                Text(n.description).font(.caption).lineLimit(3)
            }
            if !n.immediate_cause.isEmpty {
                Text("🔍 \(n.immediate_cause)").font(.caption2).foregroundColor(.orange).lineLimit(2)
            }
            if !n.action_taken.isEmpty {
                Text("⚡ \(n.action_taken)").font(.caption2).foregroundColor(.blue).lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func bbsRow(_ b: HseBbsItem) -> some View {
        HStack {
            Text(formatDate(b.date)).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text("\(b.card_count) بطاقة").font(.subheadline).bold().foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }

    // ── Badge helpers ─────────────────────────────────

    @ViewBuilder
    private func riskBadge(_ risk: String) -> some View {
        let (label, color): (String, Color) = switch risk {
            case "H": ("عالي", .red)
            case "M": ("متوسط", .orange)
            default:  ("منخفض", .green)
        }
        Text(label).font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let closed = status == "closed"
        Text(closed ? "مغلق" : "مفتوح").font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((closed ? Color.green : Color.orange).opacity(0.15))
            .foregroundColor(closed ? .green : .orange)
            .cornerRadius(4)
    }

    // ── Load ──────────────────────────────────────────

    private func load() async {
        isLoading = true; errorMsg = ""
        do {
            detail = try await NetworkManager.shared.hseOfficerDetail(officerId: officer.id, days: days)
        } catch {
            errorMsg = "فشل: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // ── PDF Export ────────────────────────────────────

    @MainActor
    private func exportPDF(_ d: HseOfficerDetailResponse) async {
        makingPDF = true
        let html = buildHTMLReport(d)
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        renderer.setValue(a4, forKey: "paperRect")
        renderer.setValue(a4.insetBy(dx: 36, dy: 50), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, nil)
        renderer.prepare(forDrawingPages: NSMakeRange(0, renderer.numberOfPages))
        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()
        let safe = officer.name.replacingOccurrences(of: " ", with: "_")
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let url = tmpDir.appendingPathComponent("HSE_\(safe)_\(todayString()).pdf")
        try? (data as Data).write(to: url)
        makingPDF = false
        pdfURL = url
    }

    private func buildHTMLReport(_ d: HseOfficerDetailResponse) -> String {
        let today = todayString()
        let checkinStatus = officer.checked_in
            ? "✅ مسجل دخول — 📍 \(officer.location ?? "")"
            : "❌ لم يسجل دخول اليوم"
        let obsCount  = d.observations.count
        let tbtCount  = d.tbts.count
        let jsoCount  = d.jso_closures.count
        let nmCount   = d.near_misses.count
        let bbsTotal  = d.bbs.reduce(0) { $0 + $1.card_count }

        func obsTypeLblH(_ t: String) -> String {
            switch t { case "unsafe_act": return "فعل خطر"
                       case "unsafe_condition": return "حالة خطرة"
                       case "positive": return "إيجابي"
                       default: return t }
        }
        func riskLblH(_ r: String) -> String {
            switch r { case "H": return "<span class='rH'>● عالي</span>"
                       case "M": return "<span class='rM'>● متوسط</span>"
                       default:  return "<span class='rL'>● منخفض</span>" }
        }

        var obsRows = ""
        for o in d.observations {
            let st = o.status == "closed"
                ? "<span class='sc'>مغلق</span>" : "<span class='so'>مفتوح</span>"
            let photoNote = (o.photos ?? []).isEmpty ? "" : " 📷\((o.photos ?? []).count)"
            obsRows += """
            <tr>
              <td>\(o.date)</td>
              <td>\(obsTypeLblH(o.obs_type))</td>
              <td>\(o.category)</td>
              <td>\(riskLblH(o.risk_level))</td>
              <td>\(st)</td>
              <td>\(o.location)</td>
              <td>\(o.description)\(photoNote)</td>
              <td>\(o.action_taken)</td>
            </tr>
            """
        }

        var tbtRows = ""
        for t in d.tbts {
            tbtRows += """
            <tr>
              <td>\(t.date)</td>
              <td>\(t.topic)</td>
              <td>\(t.location)</td>
              <td style='text-align:center;font-weight:bold;color:#7c3aed'>\(t.attendee_count)</td>
            </tr>
            """
            if let ats = t.attendees, !ats.isEmpty {
                let names = ats.map { "\($0.emp_name) (\($0.emp_number))" }.joined(separator: " · ")
                tbtRows += "<tr><td colspan='4' style='font-size:10px;color:#64748b;padding:4px 8px'>\(names)</td></tr>"
            }
        }

        var jsoRows = ""
        for j in d.jso_closures {
            let photo = (j.photo_path ?? "").isEmpty ? "" : " 📷"
            jsoRows += "<tr><td>\(j.date)</td><td>\(j.jso_number)</td><td>\(j.location)</td><td>\(j.action_taken)\(photo)</td></tr>"
        }

        var nmRows = ""
        for n in d.near_misses {
            let photo = (n.photo_path ?? "").isEmpty ? "" : " 📷"
            nmRows += "<tr><td>\(n.date)</td><td>\(n.location)</td><td>\(n.description)\(photo)</td><td>\(n.action_taken)</td><td>\(n.reported_to)</td></tr>"
        }

        var checkinRows = ""
        for c in d.checkin_history {
            checkinRows += "<tr><td>\(c.date)</td><td>\(c.location)</td></tr>"
        }

        var bbsRows = ""
        for b in d.bbs {
            bbsRows += "<tr><td>\(b.date)</td><td style='text-align:center;font-weight:bold;color:#16a34a'>\(b.card_count)</td><td>\(b.notes)</td></tr>"
        }

        func section(_ title: String, _ tableHeader: String, _ rows: String) -> String {
            guard !rows.isEmpty else { return "" }
            return """
            <div class='sec'>\(title)</div>
            <table class='dt'>\(tableHeader)\(rows)</table>
            """
        }

        let obsSec = section("الملاحظات (\(obsCount))",
            "<tr><th>التاريخ</th><th>النوع</th><th>الفئة</th><th>الخطورة</th><th>الحالة</th><th>الموقع</th><th>الوصف</th><th>الإجراء</th></tr>",
            obsRows)
        let tbtSec = section("TBT (\(tbtCount))",
            "<tr><th>التاريخ</th><th>الموضوع</th><th>الموقع</th><th>الحضور</th></tr>", tbtRows)
        let jsoSec = section("JSO (\(jsoCount))",
            "<tr><th>التاريخ</th><th>رقم JSO</th><th>الموقع</th><th>الإجراء</th></tr>", jsoRows)
        let nmSec  = section("Near Miss (\(nmCount))",
            "<tr><th>التاريخ</th><th>الموقع</th><th>الوصف</th><th>الإجراء</th><th>أُبلغ</th></tr>", nmRows)
        let ciSec  = section("سجل الحضور",
            "<tr><th>التاريخ</th><th>الموقع</th></tr>", checkinRows)
        let bbsSec = section("BBS (\(bbsTotal) بطاقة)",
            "<tr><th>التاريخ</th><th>عدد البطاقات</th><th>ملاحظات</th></tr>", bbsRows)

        return """
        <!DOCTYPE html><html dir="rtl" lang="ar"><head><meta charset="UTF-8">
        <style>
        body{font-family:Helvetica,Arial,sans-serif;font-size:11px;direction:rtl;color:#1a1a2e;margin:0;padding:0}
        .hdr{background:#1e3a5f;color:white;padding:18px 20px;margin-bottom:14px}
        .hdr h1{margin:0;font-size:18px;font-weight:bold}
        .hdr p{margin:3px 0 0;font-size:10px;color:#93c5fd}
        .kpi-wrap{width:100%;border-collapse:collapse;margin-bottom:14px}
        .kpi-wrap td{text-align:center;border:1px solid #e2e8f0;padding:10px 6px;width:20%}
        .kn{font-size:18px;font-weight:bold;color:#1e40af}
        .kl{font-size:9px;color:#64748b;margin-top:2px}
        .sec{background:#1e3a5f;color:white;padding:5px 12px;font-weight:bold;font-size:11px;margin:14px 0 4px}
        table.dt{width:100%;border-collapse:collapse;font-size:10px;margin-bottom:10px}
        table.dt th{background:#334155;color:white;padding:5px 7px;border:1px solid #475569;text-align:right}
        table.dt td{padding:4px 7px;border:1px solid #e2e8f0;vertical-align:top}
        table.dt tr:nth-child(even) td{background:#f8fafc}
        .rH{color:#dc2626;font-weight:bold}
        .rM{color:#d97706;font-weight:bold}
        .rL{color:#16a34a;font-weight:bold}
        .sc{color:#16a34a}.so{color:#ea580c}
        .ci{padding:4px 12px;margin:2px 0;background:#f0fdf4;border-right:3px solid #16a34a;font-size:10px}
        .footer{margin-top:16px;padding-top:8px;border-top:1px solid #e2e8f0;font-size:9px;color:#94a3b8;text-align:center}
        </style></head><body>
        <div class='hdr'>
          <h1>تقرير HSE — \(officer.name)</h1>
          <p>الفترة: آخر \(days) يوم &nbsp;|&nbsp; تاريخ التقرير: \(today)</p>
          <p>\(checkinStatus)</p>
        </div>
        <table class='kpi-wrap'><tr>
          <td><div class='kn'>\(obsCount)</div><div class='kl'>ملاحظات</div></td>
          <td><div class='kn'>\(tbtCount)</div><div class='kl'>TBT</div></td>
          <td><div class='kn'>\(jsoCount)</div><div class='kl'>JSO</div></td>
          <td><div class='kn'>\(nmCount)</div><div class='kl'>Near Miss</div></td>
          <td><div class='kn'>\(bbsTotal)</div><div class='kl'>بطاقات BBS</div></td>
        </tr></table>
        \(obsSec)\(tbtSec)\(jsoSec)\(nmSec)\(ciSec)\(bbsSec)
        <div class='footer'>NSH HSE — \(today) — تقرير آلي</div>
        </body></html>
        """
    }

    // ── Export text (plain fallback) ──────────────────

    private func buildExportText(_ d: HseOfficerDetailResponse) -> String {
        var lines: [String] = []
        lines.append("تقرير HSE — \(officer.name)")
        lines.append("الفترة: آخر \(days) يوم")
        lines.append("تاريخ التقرير: \(todayString())")
        lines.append("")
        if officer.checked_in {
            lines.append("✅ مسجل دخول اليوم — 📍 \(officer.location ?? "")")
        } else {
            lines.append("❌ لم يسجل دخول اليوم")
        }
        lines.append("")

        if !d.observations.isEmpty {
            lines.append("━━ الملاحظات (\(d.observations.count)) ━━")
            for o in d.observations {
                let risk = o.risk_level == "H" ? "🔴" : o.risk_level == "M" ? "🟡" : "🟢"
                let status = o.status == "closed" ? "مغلق" : "مفتوح"
                lines.append("\(risk) \(o.date) | \(obsTypeLabel(o.obs_type)) | \(o.category) | \(status)")
                if !o.location.isEmpty   { lines.append("   📍 \(o.location)") }
                if !o.description.isEmpty { lines.append("   \(o.description)") }
                if !o.action_taken.isEmpty { lines.append("   ⚡ \(o.action_taken)") }
                if o.status == "closed", !o.closure_action.isEmpty {
                    lines.append("   ✅ \(o.closure_action)")
                }
            }
            lines.append("")
        }

        if !d.tbts.isEmpty {
            lines.append("━━ TBT (\(d.tbts.count)) ━━")
            for t in d.tbts {
                lines.append("• \(t.date) | \(t.topic) | حضور: \(t.attendee_count) شخص")
                if !t.location.isEmpty { lines.append("  📍 \(t.location)") }
            }
            lines.append("")
        }

        if !d.jso_closures.isEmpty {
            lines.append("━━ JSO (\(d.jso_closures.count)) ━━")
            for j in d.jso_closures {
                lines.append("• \(j.date) | JSO #\(j.jso_number)")
                if !j.location.isEmpty { lines.append("  📍 \(j.location)") }
                if !j.action_taken.isEmpty { lines.append("  \(j.action_taken)") }
            }
            lines.append("")
        }

        if !d.near_misses.isEmpty {
            lines.append("━━ Near Miss (\(d.near_misses.count)) ━━")
            for n in d.near_misses {
                lines.append("• \(n.date) | أُبلغ: \(n.reported_to)")
                if !n.location.isEmpty { lines.append("  📍 \(n.location)") }
                if !n.description.isEmpty { lines.append("  \(n.description)") }
                if !n.action_taken.isEmpty { lines.append("  ⚡ \(n.action_taken)") }
            }
            lines.append("")
        }

        if !d.bbs.isEmpty {
            let total = d.bbs.reduce(0) { $0 + $1.card_count }
            lines.append("━━ BBS — \(total) بطاقة إجمالاً ━━")
            for b in d.bbs {
                lines.append("• \(b.date) | \(b.card_count) بطاقة")
                if !b.notes.isEmpty { lines.append("  \(b.notes)") }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func obsTypeLabel(_ type: String) -> String {
        switch type {
        case "unsafe_act":       return "فعل خطر"
        case "unsafe_condition": return "حالة خطرة"
        case "positive":         return "إيجابي"
        default:                 return type
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Edit Sheets
// ═══════════════════════════════════════════════════

// ── Edit Observation ─────────────────────────────
struct HSEEditObservationView: View {
    let obs: HseObservationItem
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var location    = ""
    @State private var obsType     = "unsafe_act"
    @State private var category    = "PPE"
    @State private var riskLevel   = "L"
    @State private var description = ""
    @State private var actionTaken = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var saving      = false
    @State private var errorMsg    = ""

    let obsTypes   = [("unsafe_act","Unsafe Act"),("unsafe_condition","Unsafe Condition"),("positive","Positive")]
    let categories = ["PPE","Excavation","Housekeeping","Barrier Management",
                      "Vehicle & Equipment","Work at Height","Lifting Operations",
                      "Line of Fire","Control of Chemicals","High Risk Situation","Other"]
    let riskLevels = [("L","Low"),("M","Medium"),("H","High")]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("الموقع والنوع")) {
                    TextField("الموقع", text: $location)
                    Picker("النوع", selection: $obsType) {
                        ForEach(obsTypes, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("الفئة", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("مستوى الخطورة", selection: $riskLevel) {
                        ForEach(riskLevels, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section(header: Text("الوصف")) {
                    TextEditor(text: $description).frame(minHeight: 70)
                }
                Section(header: Text("الإجراء الفوري")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 50)
                }
                Section(header: Text("إضافة صورة")) {
                    PhotosPicker(selection: $pickerItem, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        Label(pickedImage == nil ? "اختر صورة" : "تغيير الصورة",
                              systemImage: "photo")
                    }
                    .onChange(of: pickerItem) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self),
                               let img  = UIImage(data: data) { pickedImage = img }
                        }
                    }
                    if let img = pickedImage {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 120).clipped().cornerRadius(8)
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ التعديلات") { Task { await save() } }
                        .disabled(saving).frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("تعديل الملاحظة")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
            .onAppear {
                location    = obs.location
                obsType     = obs.obs_type.isEmpty ? "unsafe_act" : obs.obs_type
                category    = obs.category.isEmpty ? "PPE" : obs.category
                riskLevel   = obs.risk_level.isEmpty ? "L" : obs.risk_level
                description = obs.description
                actionTaken = obs.action_taken
            }
        }
    }

    private func save() async {
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMsg = "الوصف مطلوب"; return
        }
        saving = true; errorMsg = ""
        do {
            try await NetworkManager.shared.hseObservationUpdate(
                id: obs.id, location: location, obsType: obsType, category: category,
                riskLevel: riskLevel, description: description, actionTaken: actionTaken)
            if let img = pickedImage,
               let data = img.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseObservationUploadPhoto(obsId: obs.id, imageData: data)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ── Edit JSO ────────────────────────────────────
struct HSEEditJsoView: View {
    let jso: HseJsoItem
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var jsoNumber   = ""
    @State private var location    = ""
    @State private var actionTaken = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var saving      = false
    @State private var errorMsg    = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات JSO")) {
                    TextField("رقم JSO *", text: $jsoNumber)
                    TextField("الموقع", text: $location)
                }
                Section(header: Text("الإجراء المتخذ")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 70)
                }
                Section(header: Text("استبدال الصورة")) {
                    PhotosPicker(selection: $pickerItem, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        Label(pickedImage == nil ? "اختر صورة جديدة" : "تغيير الصورة",
                              systemImage: "photo")
                    }
                    .onChange(of: pickerItem) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self),
                               let img  = UIImage(data: data) { pickedImage = img }
                        }
                    }
                    if let img = pickedImage {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 120).clipped().cornerRadius(8)
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ التعديلات") { Task { await save() } }
                        .disabled(saving || jsoNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("تعديل JSO")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
            .onAppear { jsoNumber = jso.jso_number; location = jso.location; actionTaken = jso.action_taken }
        }
    }

    private func save() async {
        let n = jsoNumber.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { errorMsg = "رقم JSO مطلوب"; return }
        saving = true; errorMsg = ""
        do {
            try await NetworkManager.shared.hseJsoUpdate(
                id: jso.id, jsoNumber: n, location: location, actionTaken: actionTaken)
            if let img = pickedImage,
               let data = img.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseJsoUploadPhoto(jsoId: jso.id, imageData: data)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ── Edit Near Miss ──────────────────────────────
struct HSEEditNearMissView: View {
    let nm: HseNearMissItem
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var location       = ""
    @State private var description    = ""
    @State private var immediateCause = ""
    @State private var actionTaken    = ""
    @State private var reportedTo     = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var saving         = false
    @State private var errorMsg       = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("المعلومات الأساسية")) {
                    TextField("الموقع", text: $location)
                    TextField("أُبلغ إلى *", text: $reportedTo)
                }
                Section(header: Text("وصف الحادث *")) {
                    TextEditor(text: $description).frame(minHeight: 70)
                }
                Section(header: Text("السبب المباشر *")) {
                    TextEditor(text: $immediateCause).frame(minHeight: 50)
                }
                Section(header: Text("الإجراء المتخذ *")) {
                    TextEditor(text: $actionTaken).frame(minHeight: 50)
                }
                Section(header: Text("استبدال الصورة")) {
                    PhotosPicker(selection: $pickerItem, matching: .images,
                                 preferredItemEncoding: .compatible) {
                        Label(pickedImage == nil ? "اختر صورة جديدة" : "تغيير الصورة",
                              systemImage: "photo")
                    }
                    .onChange(of: pickerItem) { item in
                        Task {
                            if let item = item,
                               let data = try? await item.loadTransferable(type: Data.self),
                               let img  = UIImage(data: data) { pickedImage = img }
                        }
                    }
                    if let img = pickedImage {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 120).clipped().cornerRadius(8)
                    }
                }
                if !errorMsg.isEmpty { Section { Text(errorMsg).foregroundColor(.red) } }
                Section {
                    Button("حفظ التعديلات") { Task { await save() } }
                        .disabled(saving).frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("تعديل Near Miss")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } } }
            .onAppear {
                location = nm.location; description = nm.description
                immediateCause = nm.immediate_cause; actionTaken = nm.action_taken
                reportedTo = nm.reported_to
            }
        }
    }

    private func save() async {
        let desc  = description.trimmingCharacters(in: .whitespaces)
        let cause = immediateCause.trimmingCharacters(in: .whitespaces)
        let act   = actionTaken.trimmingCharacters(in: .whitespaces)
        let rpt   = reportedTo.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty && !cause.isEmpty && !act.isEmpty && !rpt.isEmpty else {
            errorMsg = "جميع الحقول المطلوبة يجب ملؤها"; return
        }
        saving = true; errorMsg = ""
        do {
            try await NetworkManager.shared.hseNearMissUpdate(
                id: nm.id, location: location, description: desc,
                immediateCause: cause, actionTaken: act, reportedTo: rpt)
            if let img = pickedImage,
               let data = img.jpegData(compressionQuality: 0.75) {
                try? await NetworkManager.shared.hseNearMissUploadPhoto(nmId: nm.id, imageData: data)
            }
            onSaved(); dismiss()
        } catch { errorMsg = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Swift Extension Helper
// ═══════════════════════════════════════════════════
extension DateFormatter {
    func apply(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self); return self
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 7. PTW View
// ═══════════════════════════════════════════════════
struct HSEPtwView: View {
    @State private var ptw:          [HsePtwItem] = []
    @State private var isLoading     = true
    @State private var showForm      = false
    @State private var errorMsg      = ""

    // form fields
    @State private var permitNumber  = ""
    @State private var permitType    = "Cold Work"
    @State private var description   = ""
    @State private var location      = ""
    @State private var locations:    [String] = []
    @State private var saving        = false
    @State private var formError     = ""

    let permitTypes = ["Hot Work","Cold Work","Excavation","Confined Space",
                       "Working at Height","Electrical Isolation","Lifting","Other"]

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    Section { ProgressView() }
                } else {
                    if !errorMsg.isEmpty {
                        Section { Text(errorMsg).foregroundColor(.red).font(.caption) }
                    }
                    // Active PTW
                    let active  = ptw.filter { $0.status == "active" && !$0.expired }
                    let expiring = ptw.filter { $0.status == "active" && $0.expired }
                    let others  = ptw.filter { $0.status != "active" }

                    if !active.isEmpty {
                        Section(header: Text("نشطة")) {
                            ForEach(active) { p in ptwRow(p) }
                        }
                    }
                    if !expiring.isEmpty {
                        Section(header: Label("منتهية — تحتاج تجديد", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)) {
                            ForEach(expiring) { p in ptwRow(p) }
                        }
                    }
                    if !others.isEmpty {
                        Section(header: Text("مغلقة / موقوفة")) {
                            ForEach(others) { p in ptwRow(p) }
                        }
                    }
                    if ptw.isEmpty {
                        Section { Text("لا توجد بيرمتات مسجّلة.").foregroundColor(.secondary) }
                    }
                }
            }
            .navigationTitle("Permit to Work")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showForm = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showForm) { addForm }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private func ptwRow(_ p: HsePtwItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.permit_number).font(.headline).fontWeight(.bold)
                Spacer()
                statusBadge(p.status, expired: p.expired)
            }
            Text(p.permit_type)
                .font(.subheadline).foregroundColor(.secondary)
            if !p.location.isEmpty {
                Label(p.location, systemImage: "mappin.circle")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text("\(formatDate(p.week_start)) – \(formatDate(p.week_end))")
                .font(.caption2).foregroundColor(.secondary)
            if !p.description.isEmpty {
                Text(p.description).font(.caption).foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if p.status == "active" {
                HStack(spacing: 8) {
                    actionButton("تعليق", color: .orange) {
                        Task { await updateStatus(p.id, status: "suspended") }
                    }
                    actionButton("إغلاق", color: .red) {
                        Task { await updateStatus(p.id, status: "closed") }
                    }
                    if p.expired {
                        actionButton("تجديد", color: .blue) {
                            Task { await updateStatus(p.id, status: "active") }
                        }
                    }
                }
            } else if p.status == "suspended" {
                HStack(spacing: 8) {
                    actionButton("إعادة تفعيل", color: .green) {
                        Task { await updateStatus(p.id, status: "active") }
                    }
                    actionButton("إغلاق", color: .red) {
                        Task { await updateStatus(p.id, status: "closed") }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func statusBadge(_ status: String, expired: Bool) -> some View {
        let (label, color): (String, Color) = expired
            ? ("منتهي", .orange)
            : status == "active"    ? ("نشط", .green)
            : status == "suspended" ? ("موقوف", .orange)
            : ("مغلق", .gray)
        Text(label)
            .font(.caption).fontWeight(.bold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }

    @ViewBuilder private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(color.opacity(0.12))
                .foregroundColor(color)
                .cornerRadius(8)
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    private var addForm: some View {
        NavigationView {
            Form {
                Section(header: Text("بيانات البيرمت")) {
                    TextField("رقم البيرمت *", text: $permitNumber)
                        .autocapitalization(.allCharacters)
                    Picker("النوع *", selection: $permitType) {
                        ForEach(permitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("الوصف", text: $description)
                    HSELocationField(label: "الموقع", value: $location, suggestions: locations)
                }
                if !formError.isEmpty {
                    Section { Text(formError).foregroundColor(.red).font(.caption) }
                }
                Section {
                    Button(action: { Task { await submitPtw() } }) {
                        if saving { ProgressView() }
                        else { Text("حفظ البيرمت").frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white) }
                    }
                    .listRowBackground(Color.green)
                    .disabled(saving || permitNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("إضافة بيرمت")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { showForm = false }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do {
            async let p = NetworkManager.shared.hsePtwList()
            async let l = NetworkManager.shared.hseLocations()
            ptw = try await p; locations = try await l
        } catch { errorMsg = error.localizedDescription }
        isLoading = false
    }

    private func updateStatus(_ id: Int, status: String) async {
        do {
            try await NetworkManager.shared.hsePtwUpdateStatus(id: id, status: status)
            await load()
        } catch {}
    }

    private func submitPtw() async {
        let num = permitNumber.trimmingCharacters(in: .whitespaces)
        guard !num.isEmpty else { formError = "رقم البيرمت مطلوب"; return }
        saving = true; formError = ""
        do {
            _ = try await NetworkManager.shared.hsePtwCreate(
                permitNumber: num, permitType: permitType,
                description: description, location: location, weekStart: nil)
            permitNumber = ""; description = ""; location = ""
            showForm = false; await load()
        } catch { formError = "فشل: \(error.localizedDescription)" }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 8. Man Power View
// ═══════════════════════════════════════════════════
struct HSEManpowerView: View {
    @State private var existing:  HseManpowerItem? = nil
    @State private var history:   [HseManpowerItem] = []
    @State private var isLoading  = true
    @State private var totalCount = ""
    @State private var location   = ""
    @State private var notes      = ""
    @State private var locations: [String] = []
    @State private var saving     = false
    @State private var message    = ""
    @State private var showAlert  = false

    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section { ProgressView() }
                } else {
                    if let ex = existing {
                        Section(header: Label("سجّل اليوم", systemImage: "checkmark.circle.fill")) {
                            HStack {
                                Image(systemName: "person.3.fill").foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(ex.total_count) عامل").font(.headline)
                                    if !ex.location.isEmpty {
                                        Text(ex.location).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section(header: Text(existing == nil ? "إدخال اليوم" : "تحديث")) {
                        HStack {
                            Text("إجمالي العمال")
                            Spacer()
                            TextField("0", text: $totalCount)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HSELocationField(label: "الموقع", value: $location, suggestions: locations)
                        TextField("ملاحظات", text: $notes)
                    }

                    Section {
                        Button(action: { Task { await save() } }) {
                            if saving { ProgressView() }
                            else { Text(existing == nil ? "حفظ" : "تحديث")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white) }
                        }
                        .listRowBackground(Color.blue)
                        .disabled(saving || totalCount.isEmpty)
                    }

                    if !history.isEmpty {
                        Section(header: Text("السجل الأخير")) {
                            ForEach(history) { rec in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(rec.date)).font(.subheadline)
                                        if !rec.location.isEmpty {
                                            Text(rec.location).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(rec.total_count)")
                                        .font(.title3).fontWeight(.bold).foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Man Power")
            .task { await load() }
            .alert("", isPresented: $showAlert) { Button("حسناً") {} } message: { Text(message) }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func load() async {
        isLoading = true
        do {
            async let e = NetworkManager.shared.hseManpowerToday()
            async let h = NetworkManager.shared.hseManpowerHistory()
            async let l = NetworkManager.shared.hseLocations()
            existing = try await e; history = try await h; locations = try await l
            if let ex = existing {
                totalCount = "\(ex.total_count)"
                location   = ex.location
                notes      = ex.notes
            }
        } catch {}
        isLoading = false
    }

    private func save() async {
        guard let total = Int(totalCount), total >= 0 else {
            message = "أدخل رقماً صحيحاً"; showAlert = true; return
        }
        saving = true
        do {
            try await NetworkManager.shared.hseManpowerSave(
                totalCount: total, location: location, notes: notes, breakdown: [:])
            message = "تم الحفظ بنجاح ✓"; showAlert = true
            await load()
        } catch { message = "فشل: \(error.localizedDescription)"; showAlert = true }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - 9. Inspection Checklist View
// ═══════════════════════════════════════════════════
struct HSEInspectionView: View {
    @State private var existing:    HseInspectionItem? = nil
    @State private var history:     [HseInspectionHistoryItem] = []
    @State private var isLoading    = true
    @State private var location     = ""
    @State private var notes        = ""
    @State private var locations:   [String] = []
    @State private var saving       = false
    @State private var message      = ""
    @State private var showAlert    = false

    // Local checklist state — item text → (ok, note)
    @State private var checks: [(item: String, ok: Bool, note: String)] = []

    var score: Double {
        guard !checks.isEmpty else { return 0 }
        let ok = checks.filter(\.ok).count
        return Double(ok) / Double(checks.count) * 100
    }

    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section { ProgressView() }
                } else {
                    // Score preview
                    Section {
                        HStack {
                            Text("النتيجة").font(.headline)
                            Spacer()
                            Text(String(format: "%.0f%%", score))
                                .font(.title2).fontWeight(.bold)
                                .foregroundColor(score >= 80 ? .green : score >= 60 ? .orange : .red)
                        }
                    }

                    Section(header: Text("الموقع والملاحظات")) {
                        HSELocationField(label: "الموقع", value: $location, suggestions: locations)
                        TextField("ملاحظات عامة", text: $notes)
                    }

                    Section(header: Text("بنود الفحص (\(checks.filter(\.ok).count)/\(checks.count))")) {
                        ForEach(checks.indices, id: \.self) { idx in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    Button {
                                        checks[idx].ok.toggle()
                                    } label: {
                                        Image(systemName: checks[idx].ok
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(checks[idx].ok ? .green : .gray)
                                            .font(.title3)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    Text(checks[idx].item)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !checks[idx].ok {
                                    TextField("ملاحظة...", text: Binding(
                                        get: { checks[idx].note },
                                        set: { checks[idx].note = $0 }
                                    ))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 32)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section {
                        Button(action: { Task { await saveInspection() } }) {
                            if saving { ProgressView() }
                            else { Text(existing == nil ? "حفظ الجولة" : "تحديث الجولة")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white) }
                        }
                        .listRowBackground(Color(score >= 80 ? .green : score >= 60 ? .orange : .red))
                        .disabled(saving)
                    }

                    if !history.isEmpty {
                        Section(header: Text("السجل الأخير")) {
                            ForEach(history) { rec in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(rec.date)).font(.subheadline)
                                        if !rec.location.isEmpty {
                                            Text(rec.location).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let s = rec.overall_score {
                                        Text(String(format: "%.0f%%", s))
                                            .fontWeight(.bold)
                                            .foregroundColor(s >= 80 ? .green : s >= 60 ? .orange : .red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inspection Checklist")
            .task { await load() }
            .alert("", isPresented: $showAlert) { Button("حسناً") {} } message: { Text(message) }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private let defaultItems = [
        "PPE Compliance (Helmet, Vest, Boots)",
        "Housekeeping & Work Area Clean",
        "Barricading & Warning Signs in Place",
        "Fire Extinguisher Accessible",
        "PTW Displayed at Work Site",
        "First Aid Kit Available",
        "No Unauthorized Personnel in Area",
        "Electrical Safety (No Exposed Wires)",
        "Scaffolding Tagged & Inspected",
        "Emergency Exits Clear",
    ]

    private func load() async {
        isLoading = true
        do {
            async let e = NetworkManager.shared.hseInspectionToday()
            async let h = NetworkManager.shared.hseInspectionHistory()
            async let l = NetworkManager.shared.hseLocations()
            let (ex, hist, locs) = try await (e, h, l)
            existing  = ex
            history   = hist
            locations = locs
            if let ex = ex, let cl = ex.checklist, !cl.isEmpty {
                checks   = cl.map { (item: $0.item, ok: $0.ok, note: $0.note) }
                location = ex.location
                notes    = ex.notes
            } else {
                checks = defaultItems.map { (item: $0, ok: false, note: "") }
            }
        } catch {}
        isLoading = false
    }

    private func saveInspection() async {
        saving = true
        let cl = checks.map { HseChecklistEntry(item: $0.item, ok: $0.ok, note: $0.note) }
        do {
            let s = try await NetworkManager.shared.hseInspectionSave(
                location: location, notes: notes, checklist: cl)
            message = String(format: "تم الحفظ — النتيجة: %.0f%%", s)
            showAlert = true
            await load()
        } catch { message = "فشل: \(error.localizedDescription)"; showAlert = true }
        saving = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Task Status Enum & Helper Components
// ═══════════════════════════════════════════════════

enum TaskStatus { case done, required, optional, overdue }

struct DailyTaskCard: View {
    let title:  String
    let icon:   String
    let status: TaskStatus
    let detail: String

    var statusColor: Color {
        switch status {
        case .done:     return .green
        case .required: return .red
        case .optional: return Color(.systemGray3)
        case .overdue:  return .red
        }
    }
    var statusText: String {
        switch status {
        case .done:     return "✓ مكتمل"
        case .required: return "● مطلوب"
        case .optional: return "○ اختياري"
        case .overdue:  return "⚠ متأخر"
        }
    }
    var bgColor: Color {
        switch status {
        case .done:     return Color.green.opacity(0.08)
        case .required: return Color.red.opacity(0.06)
        case .optional: return Color(.secondarySystemBackground)
        case .overdue:  return Color.red.opacity(0.1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(statusColor)
                Spacer()
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AlertBanner: View {
    let icon:  String
    let color: Color
    let text:  String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.subheadline).foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct QuickAccessButton: View {
    let title:       String
    let icon:        String
    let color:       Color
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - HSE Officer Home View
// ═══════════════════════════════════════════════════

struct HSEOfficerHomeView: View {
    @State private var checkin:    HseCheckinItem?    = nil
    @State private var manpower:   HseManpowerItem?   = nil
    @State private var inspection: HseInspectionItem? = nil
    @State private var myCas:      [HseCaItem]        = []
    @State private var ptws:       [HsePtwItem]       = []
    @State private var isLoading   = true

    var openCas:    Int { myCas.filter { $0.status != "completed" }.count }
    var overdueCas: Int { myCas.filter { $0.overdue }.count }
    var expiredPtw: Int { ptws.filter { $0.status == "active" && $0.expired }.count }
    var activePtw:  Int { ptws.filter { $0.status == "active" && !$0.expired }.count }

    var todayDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE، d MMMM yyyy"
        f.locale = Locale(identifier: "ar")
        return f.string(from: Date())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("جاري التحميل...").padding(.top, 60)
                    } else {
                        headerCard

                        Text("مهام اليوم")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        dailyTasksGrid

                        if overdueCas > 0 || expiredPtw > 0 {
                            alertsSection
                        }

                        Text("وصول سريع")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        quickAccessGrid
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("مرحباً 👷")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadAll() }
            .refreshable { await loadAll() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    var headerCard: some View {
        VStack(spacing: 6) {
            Text(todayDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let loc = checkin?.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6)
        .padding(.horizontal)
    }

    var dailyTasksGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(destination: HSECheckinView()) {
                DailyTaskCard(
                    title: "تسجيل الدخول",
                    icon: "location.fill",
                    status: checkin != nil ? .done : .required,
                    detail: checkin?.location ?? "لم يُسجَّل بعد"
                )
            }

            NavigationLink(destination: HSEManpowerView()) {
                DailyTaskCard(
                    title: "Man Power",
                    icon: "person.3.fill",
                    status: manpower != nil ? .done : .required,
                    detail: manpower != nil ? "\(manpower!.total_count) عامل" : "لم يُدخَل بعد"
                )
            }

            NavigationLink(destination: HSEInspectionView()) {
                DailyTaskCard(
                    title: "جولة التفتيش",
                    icon: "checklist",
                    status: inspection != nil ? .done : .optional,
                    detail: inspection.flatMap { $0.overall_score }.map {
                        String(format: "%.0f%%", $0)
                    } ?? "لم تُنجَز بعد"
                )
            }

            NavigationLink(destination: HSEMyCaView()) {
                DailyTaskCard(
                    title: "إجراءات تصحيحية",
                    icon: "list.clipboard.fill",
                    status: overdueCas > 0 ? .overdue : openCas > 0 ? .required : .done,
                    detail: openCas == 0
                        ? "لا يوجد مفتوح"
                        : "\(openCas) مفتوح\(overdueCas > 0 ? " • \(overdueCas) متأخر" : "")"
                )
            }
        }
        .padding(.horizontal)
    }

    var alertsSection: some View {
        VStack(spacing: 8) {
            if overdueCas > 0 {
                AlertBanner(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    text: "\(overdueCas) إجراء تصحيحي متأخر عن موعده"
                )
            }
            if expiredPtw > 0 {
                AlertBanner(
                    icon: "doc.badge.clock.fill",
                    color: .orange,
                    text: "\(expiredPtw) بيرمت منتهي يحتاج تجديد"
                )
            }
        }
        .padding(.horizontal)
    }

    var quickAccessGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            QuickAccessButton(title: "ملاحظة", icon: "eye.fill", color: .blue,
                              destination: AnyView(HSEObservationsView()))
            QuickAccessButton(title: "PTW", icon: "doc.badge.checkmark", color: .purple,
                              destination: AnyView(HSEPtwView()))
            QuickAccessButton(title: "JSO", icon: "doc.badge.plus", color: .indigo,
                              destination: AnyView(HSEJsoView()))
            QuickAccessButton(title: "TBT", icon: "person.2.badge.gearshape", color: .teal,
                              destination: AnyView(HSETbtView()))
            QuickAccessButton(title: "Near Miss", icon: "exclamationmark.triangle.fill", color: .red,
                              destination: AnyView(HSENearMissView()))
            QuickAccessButton(title: "BBS", icon: "checkmark.circle.fill", color: .green,
                              destination: AnyView(HSEBbsView()))
            QuickAccessButton(title: "CAs", icon: "list.clipboard.fill", color: .orange,
                              destination: AnyView(HSEMyCaView()))
        }
        .padding(.horizontal)
    }

    func loadAll() async {
        isLoading = true
        async let c  = try? NetworkManager.shared.hseCheckinToday()
        async let m  = try? NetworkManager.shared.hseManpowerToday()
        async let i  = try? NetworkManager.shared.hseInspectionToday()
        async let ca = try? NetworkManager.shared.hseMyCa()
        async let p  = try? NetworkManager.shared.hsePtwList()
        checkin    = await c
        manpower   = await m
        inspection = await i
        myCas      = await ca ?? []
        ptws       = await p  ?? []
        isLoading  = false
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  MARK: - TBT PDF Generation
// ═══════════════════════════════════════════════════════════════════════

// Share sheet wrapper (UIActivityViewController)
struct HSEShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// ── Main PDF generator ───────────────────────────────────────────────

@MainActor
func makeTbtPdf(
    topic: String,
    date: String,
    location: String,
    supervisorName: String,
    attendees: [(name: String, badge: String)]
) async -> URL? {
    // Fetch company logo
    var logo: UIImage? = nil
    if let logoUrl = URL(string: "\(BASE_URL)/static/img/logo.png"),
       let (data, _) = try? await URLSession.shared.data(from: logoUrl) {
        logo = UIImage(data: data)
    }

    let layout = HSETbtPdfLayout(
        topic: topic, date: date, location: location,
        supervisorName: supervisorName, attendees: attendees, logo: logo
    )

    let renderer = ImageRenderer(content: layout)
    renderer.scale = 2.0
    renderer.proposedSize = ProposedViewSize(width: 595, height: nil)

    guard let img = renderer.uiImage else { return nil }

    // Build multi-page PDF (A4 = 595×842 pt)
    let pageW: CGFloat = 595
    let pageH: CGFloat = 842
    let contentH = img.size.height                // in points (renderer already accounts for scale)
    let numPages = Int(ceil(contentH / pageH))
    let pdfBounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)

    let pdfRenderer = UIGraphicsPDFRenderer(bounds: pdfBounds)
    let pdfData = pdfRenderer.pdfData { ctx in
        guard let cgImg = img.cgImage else { return }
        let scale = img.scale
        for p in 0..<numPages {
            let yPx  = Int(CGFloat(p) * pageH * scale)
            let hPx  = Int(min(pageH * scale, CGFloat(cgImg.height) - CGFloat(yPx)))
            guard hPx > 0,
                  let slice = cgImg.cropping(to: CGRect(x: 0, y: yPx,
                                                        width: cgImg.width, height: hPx))
            else { continue }
            ctx.beginPage()
            let sliceImg = UIImage(cgImage: slice, scale: scale, orientation: .up)
            sliceImg.draw(in: CGRect(x: 0, y: 0, width: pageW, height: CGFloat(hPx) / scale))
        }
    }

    // Write to Documents (tmp is not reliably accessible from UIActivityViewController)
    let safeTitle = topic.prefix(20)
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: " ", with: "_")
    let fileName = "TBT_\(date)_\(safeTitle).pdf"
    let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
                   ?? NSTemporaryDirectory()
    let url = URL(fileURLWithPath: docsPath).appendingPathComponent(fileName)
    do {
        try pdfData.write(to: url, options: .atomic)
        return url
    } catch {
        return nil
    }
}

// ── PDF Layout (A4 width = 595 pt) ───────────────────────────────────

struct HSETbtPdfLayout: View {
    let topic:          String
    let date:           String
    let location:       String
    let supervisorName: String
    let attendees:      [(name: String, badge: String)]
    let logo:           UIImage?

    // Column widths for attendees table
    private let colNo:  CGFloat = 28
    private let colBdg: CGFloat = 100
    private let colSig: CGFloat = 80

    private let blue   = Color(hex: "#0D47A1")
    private let lblBlue = Color(hex: "#1565C0")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pdfHeader
            Rectangle().fill(blue).frame(height: 2)
            pdfInfoBlock
            Spacer(minLength: 12)
            leadsSection
            Spacer(minLength: 10)
            attendeesSection
            Spacer(minLength: 16)
            pdfFooter
        }
        .padding(.horizontal, 18)
        .frame(width: 595)
        .background(Color.white)
        .environment(\.layoutDirection, .leftToRight)
    }

    // ── Header ────────────────────────────────────────────────────────
    private var pdfHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            if let lg = logo {
                Image(uiImage: lg).resizable().scaledToFit().frame(height: 50)
            } else {
                Text("NSH").font(.system(size: 20, weight: .bold)).foregroundColor(blue)
                    .frame(width: 70)
            }
            Spacer()
            VStack(spacing: 3) {
                Text("Toolbox Talk Report").font(.system(size: 14, weight: .bold))
                Text("تقرير أدوات الحوار اليومي").font(.system(size: 10)).foregroundColor(.secondary)
                Text("Safety Green Light").font(.system(size: 9)).foregroundColor(.secondary)
            }
            Spacer()
            Color.clear.frame(width: 70, height: 50)
        }
        .padding(.vertical, 10)
    }

    // ── Info block (Topic / Location / Date) ──────────────────────────
    private var pdfInfoBlock: some View {
        HStack(spacing: 0) {
            infoCell("الموضوع / Topic", topic, flex: true)
            Rectangle().fill(Color.gray.opacity(0.4)).frame(width: 0.5)
            infoCell("الموقع / Location", location.isEmpty ? "—" : location, flex: false)
            Rectangle().fill(Color.gray.opacity(0.4)).frame(width: 0.5)
            infoCell("التاريخ / Date", formatDate(date), flex: false)
        }
        .frame(height: 48)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
        .padding(.top, 10)
    }

    private func infoCell(_ label: String, _ value: String, flex: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 7)).foregroundColor(.secondary)
            Text(value).font(.system(size: 9, weight: .medium)).lineLimit(2)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .frame(maxWidth: flex ? .infinity : 115, alignment: .leading)
    }

    // ── Safety Green Light leads by ────────────────────────────────────
    private var leadsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Safety Green Light Leads By:")
                .font(.system(size: 8, weight: .bold)).foregroundColor(blue).padding(.bottom, 4)

            // Header
            HStack(spacing: 0) {
                thCell("الاسم / Name",         flex: true)
                thCell("المنصب / Position",     w: 110)
                thCell("الشركة / Company",      w: 80)
                thCell("التوقيع / Signature",   w: 85)
            }
            // Data row
            HStack(spacing: 0) {
                tdCell(supervisorName.isEmpty ? "—" : supervisorName, flex: true)
                tdCell("Safety Supervisor",  w: 110)
                tdCell("NSH",               w: 80)
                tdCell("",                  w: 85, minH: 28)
            }
        }
    }

    // ── Attendees table ────────────────────────────────────────────────
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Attendees / الحاضرون:")
                .font(.system(size: 8, weight: .bold)).foregroundColor(blue).padding(.bottom, 4)

            // Header
            HStack(spacing: 0) {
                thCell("#",                     w: colNo)
                thCell("الاسم / Name",          flex: true)
                thCell("الرقم / Badge No.",     w: colBdg)
                thCell("التوقيع / Signature",   w: colSig)
            }
            // Data rows — at least 15, up to attendees count
            let total = max(attendees.count, 15)
            ForEach(0..<total, id: \.self) { i in
                let n = i < attendees.count ? attendees[i].name  : ""
                let b = i < attendees.count ? attendees[i].badge : ""
                HStack(spacing: 0) {
                    tdCell("\(i+1)",  w: colNo)
                    tdCell(n,         flex: true)
                    tdCell(b,         w: colBdg)
                    tdCell("",        w: colSig, minH: 24)
                }
            }
        }
    }

    // ── Footer ─────────────────────────────────────────────────────────
    private var pdfFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(blue).frame(height: 1)
            HStack {
                Text("NSH — Amiral/SATORP, Package 3, Area 321")
                Spacer()
                Text("DRP Classification: Restricted Distribution")
            }
            .font(.system(size: 7)).foregroundColor(.secondary).padding(.vertical, 5)
        }
    }

    // ── Table cell helpers ─────────────────────────────────────────────
    private func thCell(_ txt: String, flex: Bool = false, w: CGFloat = 0) -> some View {
        Text(txt).font(.system(size: 7, weight: .bold)).foregroundColor(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: flex ? .infinity : w, minHeight: 22, alignment: .center)
            .padding(.horizontal, 2)
            .background(lblBlue)
            .border(blue, width: 0.5)
    }

    private func tdCell(_ txt: String, flex: Bool = false, w: CGFloat = 0, minH: CGFloat = 22) -> some View {
        Text(txt).font(.system(size: 8))
            .frame(maxWidth: flex ? .infinity : w, minHeight: minH, alignment: .center)
            .padding(.horizontal, 2)
            .border(Color.gray.opacity(0.35), width: 0.5)
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  MARK: - HSE Report PDF (Weekly / Monthly)
// ═══════════════════════════════════════════════════════════════════════

@MainActor
func makeReportPdf(
    title: String,
    period: String,
    rows: [HseReportRow],
    prevRows: [HseReportRow]
) async -> URL? {
    var logo: UIImage? = nil
    if let logoUrl = URL(string: "\(BASE_URL)/static/img/logo.png"),
       let (data, _) = try? await URLSession.shared.data(from: logoUrl) {
        logo = UIImage(data: data)
    }

    let layout = HSEReportPdfLayout(
        title: title, period: period, rows: rows, prevRows: prevRows, logo: logo
    )

    let renderer = ImageRenderer(content: layout)
    renderer.scale = 2.0
    renderer.proposedSize = ProposedViewSize(width: 595, height: nil)

    guard let img = renderer.uiImage else { return nil }

    let pageW: CGFloat = 595
    let pageH: CGFloat = 842
    let numPages = Int(ceil(img.size.height / pageH))
    let pdfBounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)

    let pdfRenderer = UIGraphicsPDFRenderer(bounds: pdfBounds)
    let pdfData = pdfRenderer.pdfData { ctx in
        guard let cgImg = img.cgImage else { return }
        let scale = img.scale
        for p in 0..<numPages {
            let yPx = Int(CGFloat(p) * pageH * scale)
            let hPx = Int(min(pageH * scale, CGFloat(cgImg.height) - CGFloat(yPx)))
            guard hPx > 0,
                  let slice = cgImg.cropping(to: CGRect(x: 0, y: yPx, width: cgImg.width, height: hPx))
            else { continue }
            ctx.beginPage()
            UIImage(cgImage: slice, scale: scale, orientation: .up)
                .draw(in: CGRect(x: 0, y: 0, width: pageW, height: CGFloat(hPx) / scale))
        }
    }

    let safePeriod = period
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "—", with: "-")
        .replacingOccurrences(of: "/", with: "-")
    let fileName = "HSE_Report_\(safePeriod).pdf"
    let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
                   ?? NSTemporaryDirectory()
    let url = URL(fileURLWithPath: docsPath).appendingPathComponent(fileName)
    do {
        try pdfData.write(to: url, options: .atomic)
        return url
    } catch { return nil }
}

// ── PDF Layout ────────────────────────────────────────────────────────

struct HSEReportPdfLayout: View {
    let title:    String
    let period:   String
    let rows:     [HseReportRow]
    let prevRows: [HseReportRow]
    let logo:     UIImage?

    private let dkBlue  = Color(hex: "#0D47A1")
    private let mdBlue  = Color(hex: "#1565C0")

    // Column widths (total = 559 = 595 - 36 padding)
    private let cNm:  CGFloat = 88
    private let cCI:  CGFloat = 29
    private let cObs: CGFloat = 32
    private let cUA:  CGFloat = 27
    private let cUC:  CGFloat = 27
    private let cPos: CGFloat = 29
    private let cH:   CGFloat = 22
    private let cJso: CGFloat = 29
    private let cTbt: CGFloat = 29
    private let cAtt: CGFloat = 33
    private let cNm2: CGFloat = 27
    private let cBbs: CGFloat = 29
    private let cSco: CGFloat = 40
    private let cTrn: CGFloat = 28

    private var prevMap: [Int: HseReportRow] {
        Dictionary(uniqueKeysWithValues: prevRows.map { ($0.officer_id, $0) })
    }

    var body: some View {
        let prev = prevMap
        VStack(alignment: .leading, spacing: 0) {
            pdfHeader
            Rectangle().fill(dkBlue).frame(height: 2)
            kpiStrip
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 0.5)
            tableHeader
            tableRows(prev: prev)
            Spacer(minLength: 16)
            pdfFooter
        }
        .frame(width: 595)
        .background(Color.white)
    }

    // ── Header ────────────────────────────────────────────────────────
    private var pdfHeader: some View {
        HStack(alignment: .center) {
            if let lg = logo {
                Image(uiImage: lg).resizable().scaledToFit().frame(height: 50)
            } else {
                Text("NSH").font(.system(size: 18, weight: .bold)).foregroundColor(dkBlue)
            }
            Spacer()
            VStack(spacing: 3) {
                Text(title).font(.system(size: 13, weight: .bold))
                Text(period).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            Color.clear.frame(width: 50, height: 50)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    // ── KPI strip ─────────────────────────────────────────────────────
    private var kpiStrip: some View {
        let totalObs = rows.reduce(0)  { $0 + $1.obs_total }
        let totalTbt = rows.reduce(0)  { $0 + $1.tbt }
        let totalBbs = rows.reduce(0)  { $0 + $1.bbs }
        let highRisk = rows.reduce(0)  { $0 + $1.obs_high }
        let nm       = rows.reduce(0)  { $0 + $1.nm }
        let inactive = rows.filter     { $0.total_activity == 0 }.count

        let pObs = prevRows.reduce(0)  { $0 + $1.obs_total }
        let pTbt = prevRows.reduce(0)  { $0 + $1.tbt }
        let pBbs = prevRows.reduce(0)  { $0 + $1.bbs }
        let pH   = prevRows.reduce(0)  { $0 + $1.obs_high }
        let pNm  = prevRows.reduce(0)  { $0 + $1.nm }
        let pIn  = prevRows.filter     { $0.total_activity == 0 }.count

        return HStack(spacing: 0) {
            kpiCell("ملاحظات",     "\(totalObs)", trendInfo(cur: totalObs, prev: pObs), .blue)
            kpiCell("TBT",          "\(totalTbt)", trendInfo(cur: totalTbt, prev: pTbt), .purple)
            kpiCell("BBS",          "\(totalBbs)", trendInfo(cur: totalBbs, prev: pBbs), .teal)
            kpiCell("خطورة عالية", "\(highRisk)",  trendInfo(cur: highRisk,  prev: pH),   highRisk == 0 ? .green : .red)
            kpiCell("Near Miss",   "\(nm)",         trendInfo(cur: nm,        prev: pNm),  nm == 0 ? .green : .red)
            kpiCell("بلا نشاط",   "\(inactive)",   trendInfo(cur: inactive,  prev: pIn),  inactive == 0 ? .green : .red)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }

    private func kpiCell(_ label: String, _ value: String,
                         _ trend: (symbol: String, color: Color, pct: String),
                         _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            HStack(spacing: 2) {
                Text(trend.symbol).font(.system(size: 8, weight: .bold)).foregroundColor(trend.color)
                if !trend.pct.isEmpty {
                    Text(trend.pct).font(.system(size: 8)).foregroundColor(trend.color)
                }
            }
            Text(label).font(.system(size: 7)).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
    }

    // ── Table header ──────────────────────────────────────────────────
    private var tableHeader: some View {
        HStack(spacing: 0) {
            pth("الاسم",  cNm,  leftPad: true)
            pth("CI",     cCI)
            pth("OBS",    cObs)
            pth("UA",     cUA)
            pth("UC",     cUC)
            pth("POS",    cPos)
            pth("H",      cH)
            pth("JSO",    cJso)
            pth("TBT",    cTbt)
            pth("TBT👥",  cAtt)
            pth("NM",     cNm2)
            pth("BBS",    cBbs)
            pth("Score",  cSco)
            pth("▲▼",     cTrn)
        }
        .padding(.horizontal, 18)
    }

    // ── Table rows ────────────────────────────────────────────────────
    private func tableRows(prev: [Int: HseReportRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                let p = prev[row.officer_id]
                let t = trendInfo(cur: row.total_activity, prev: p?.total_activity ?? 0)
                let bg = row.total_activity == 0 ? Color.red.opacity(0.06) : Color.clear
                HStack(spacing: 0) {
                    ptd(row.officer_name.components(separatedBy: " ").prefix(2).joined(separator: " "),
                        cNm, .primary, left: true)
                    ptd(row.checkin_days    > 0 ? "\(row.checkin_days)"    : "—", cCI,  row.checkin_days    > 0 ? Color(hex:"#0D7A5F") : .secondary)
                    ptd(row.obs_total       > 0 ? "\(row.obs_total)"       : "—", cObs, row.obs_total       > 0 ? .blue   : .secondary)
                    ptd(row.obs_unsafe_act  > 0 ? "\(row.obs_unsafe_act)"  : "—", cUA,  row.obs_unsafe_act  > 0 ? .red    : .secondary)
                    ptd(row.obs_unsafe_cond > 0 ? "\(row.obs_unsafe_cond)" : "—", cUC,  row.obs_unsafe_cond > 0 ? .orange : .secondary)
                    ptd(row.obs_positive    > 0 ? "\(row.obs_positive)"    : "—", cPos, row.obs_positive    > 0 ? .green  : .secondary)
                    ptd(row.obs_high        > 0 ? "\(row.obs_high)"        : "—", cH,   row.obs_high        > 0 ? .red    : .secondary)
                    ptd(row.jso             > 0 ? "\(row.jso)"             : "—", cJso, row.jso             > 0 ? .indigo : .secondary)
                    ptd(row.tbt             > 0 ? "\(row.tbt)"             : "—", cTbt, row.tbt             > 0 ? .purple : .secondary)
                    ptd(row.tbt_attendees   > 0 ? "\(row.tbt_attendees)"   : "—", cAtt, row.tbt_attendees   > 0 ? .purple : .secondary)
                    ptd(row.nm              > 0 ? "\(row.nm)"              : "—", cNm2, row.nm              > 0 ? .red    : .secondary)
                    ptd(row.bbs             > 0 ? "\(row.bbs)"             : "—", cBbs, row.bbs             > 0 ? .teal   : .secondary)
                    pScore(row.score, cSco)
                    ptd(t.symbol, cTrn, t.color)
                }
                .background(bg)
                .padding(.horizontal, 18)
                Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 0.5).padding(.horizontal, 18)
            }
        }
    }

    // ── Footer ────────────────────────────────────────────────────────
    private var pdfFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(dkBlue).frame(height: 1)
            HStack {
                Text("NSH — Amiral/SATORP, Package 3, Area 321")
                Spacer()
                Text("DRP Classification: Restricted Distribution")
            }
            .font(.system(size: 7)).foregroundColor(.secondary)
            .padding(.horizontal, 18).padding(.vertical, 5)
        }
    }

    // ── Cell helpers ──────────────────────────────────────────────────
    private func pth(_ txt: String, _ w: CGFloat, leftPad: Bool = false) -> some View {
        Text(txt).font(.system(size: 7, weight: .bold)).foregroundColor(.white)
            .frame(width: w, height: 22, alignment: leftPad ? .leading : .center)
            .padding(.leading, leftPad ? 4 : 0)
            .background(mdBlue).border(dkBlue, width: 0.3)
    }

    private func ptd(_ txt: String, _ w: CGFloat, _ color: Color = .primary, left: Bool = false) -> some View {
        Text(txt).font(.system(size: 8)).foregroundColor(color)
            .frame(width: w, height: 20, alignment: left ? .leading : .center)
            .padding(.leading, left ? 3 : 0)
            .border(Color.gray.opacity(0.2), width: 0.3)
    }

    private func pScore(_ score: Double, _ w: CGFloat) -> some View {
        let c: Color = score >= 15 ? .green : score >= 8 ? .orange : .red
        return Text(String(format: "%.1f", score)).font(.system(size: 8, weight: .bold))
            .foregroundColor(c).frame(width: w, height: 20, alignment: .center)
            .border(Color.gray.opacity(0.2), width: 0.3)
    }
}

