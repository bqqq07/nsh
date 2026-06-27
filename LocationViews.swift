import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - UserLocationView (Safety Officer + Supervisor)
// ═══════════════════════════════════════════════════
struct UserLocationView: View {
    private var user: AppUser? { SessionManager.shared.currentUser }
    private var isSiteSupOrAdmin: Bool {
        ["site_supervisor", "admin", "super_admin"].contains(user?.role ?? "")
    }

    @State private var myLocation: UserLocationItem?
    @State private var pkg: String = "3"
    @State private var unit: String = ""
    @State private var areaText: String = ""
    @State private var isSaving = false
    @State private var saveMsg: String? = nil
    @State private var saveMsgOk = true

    @State private var nearest: [NearestPerson] = []
    @State private var supervisorLocations: [NearestPerson] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                // ── Register Location ──
                Section(header: Text("موقعي الحالي")) {
                    if let loc = myLocation {
                        HStack(spacing: 10) {
                            pkgBadge(loc.pkg)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unit \(loc.unit)").font(.subheadline).fontWeight(.semibold)
                                if !loc.areaText.isEmpty {
                                    Text(loc.areaText).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(loc.updatedAt.prefix(16)).font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Picker("Package", selection: $pkg) {
                        Text("PKG 2").tag("2")
                        Text("PKG 3").tag("3")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    HStack {
                        TextField("Unit (مثال: 320)", text: $unit)
                            .keyboardType(.numbersAndPunctuation)
                        Divider()
                        TextField("المنطقة (مثال: str3000)", text: $areaText)
                    }

                    Button(action: saveLocation) {
                        HStack {
                            if isSaving {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("حفظ الموقع")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(unit.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

                    if let msg = saveMsg {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(saveMsgOk ? .green : .red)
                    }
                }

                // ── Nearest Persons ──
                if myLocation != nil {
                    let title = (user?.role == "safety_officer") ? "أقرب مشرف" : "أقرب سيفتي أوفسر"
                    Section(header: HStack {
                        Text(title)
                        Spacer()
                        if isLoading { ProgressView().scaleEffect(0.7) }
                        else {
                            Button(action: loadNearest) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                        }
                    }) {
                        if nearest.isEmpty {
                            Text("لا يوجد أحد سجّل موقعه حتى الآن")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(nearest) { person in
                                NearestPersonRow(person: person)
                            }
                        }
                    }
                }

                // ── Site Supervisor: All Supervisors ──
                if isSiteSupOrAdmin && myLocation != nil {
                    Section(header: HStack {
                        Text("مواقع المشرفين")
                        Spacer()
                        Button(action: loadSupervisorLocations) {
                            Image(systemName: "arrow.clockwise").font(.caption)
                        }
                    }) {
                        if supervisorLocations.isEmpty {
                            Text("لا يوجد مشرفون سجّلوا مواقعهم")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(supervisorLocations) { s in
                                HStack {
                                    pkgBadge(s.pkg)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.subheadline).fontWeight(.semibold)
                                        Text("Unit \(s.unit)\(s.areaText.isEmpty ? "" : " — \(s.areaText)")")
                                            .font(.caption).foregroundColor(.secondary)
                                        Text(s.supervisorCode).font(.caption2).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("📍 موقعي")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadAll() }
            .refreshable { await loadAll() }
        }
    }

    // ── Helpers ──
    @ViewBuilder
    private func pkgBadge(_ p: Int) -> some View {
        Text("PKG \(p)")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(p == 2 ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundColor(p == 2 ? .blue : .orange)
            .clipShape(Capsule())
    }

    private func loadAll() async {
        if let loc = try? await NetworkManager.shared.getMyLocation() {
            myLocation = loc
            pkg = "\(loc.pkg)"
            unit = loc.unit
            areaText = loc.areaText
        }
        await loadNearest()
        if isSiteSupOrAdmin { await loadSupervisorLocations() }
    }

    private func loadNearest() async {
        isLoading = true
        defer { isLoading = false }
        nearest = (try? await NetworkManager.shared.getNearestPersons()) ?? []
    }

    private func loadSupervisorLocations() async {
        supervisorLocations = (try? await NetworkManager.shared.getMySupervisorsLocations()) ?? []
    }

    private func saveLocation() {
        let u = unit.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, let p = Int(pkg) else { return }
        isSaving = true
        saveMsg = nil
        Task {
            do {
                try await NetworkManager.shared.saveLocation(pkg: p, unit: u, areaText: areaText.trimmingCharacters(in: .whitespaces))
                saveMsg = "✓ تم حفظ الموقع"
                saveMsgOk = true
                if let loc = try? await NetworkManager.shared.getMyLocation() {
                    myLocation = loc
                }
                await loadNearest()
            } catch {
                saveMsg = "✗ فشل الحفظ"
                saveMsgOk = false
            }
            isSaving = false
        }
    }
}

// ── Nearest Person Row ──────────────────────────────
struct NearestPersonRow: View {
    let person: NearestPerson

    private var proximityColor: Color {
        switch person.proximity {
        case 0: return .green
        case 1: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(proximityColor.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("PKG\(person.pkg)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(proximityColor)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.subheadline).fontWeight(.semibold)
                Text(person.locationString).font(.caption).foregroundColor(.secondary)
                Text(person.supervisorCode).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text(person.proximityLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(proximityColor.opacity(0.15))
                .foregroundColor(proximityColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 3)
    }
}
