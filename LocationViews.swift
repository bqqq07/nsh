import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - UserLocationView
// ═══════════════════════════════════════════════════
struct UserLocationView: View {
    private var user: AppUser? { SessionManager.shared.currentUser }
    private var isAdmin: Bool {
        ["admin", "super_admin"].contains(user?.role ?? "")
    }
    private var isSiteSup: Bool { user?.role == "site_supervisor" }

    @State private var myLocation: UserLocationItem?
    @State private var pkg: String = "3"
    @State private var unit: String = ""
    @State private var areaText: String = ""
    @State private var isSaving = false
    @State private var saveMsg: String? = nil
    @State private var saveMsgOk = true

    @State private var nearest: [NearestPerson] = []
    @State private var allLocations: [NearestPerson] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            if isAdmin {
                adminView
            } else {
                fieldView
            }
        }
    }

    // ── Admin View: all locations ──
    var adminView: some View {
        List {
            Section(header: HStack {
                Text("All Staff Locations")
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.7) }
                else { Button(action: { Task { await loadAdminLocations() } }) {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }}
            }) {
                if allLocations.isEmpty {
                    Text("No locations registered yet")
                        .font(.caption).foregroundColor(.secondary).padding(.vertical, 6)
                } else {
                    ForEach(allLocations) { person in
                        LocationPersonRow(person: person, showRole: true)
                    }
                }
            }
        }
        .navigationTitle("📍 Locations")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadAdminLocations() }
        .refreshable { await loadAdminLocations() }
    }

    // ── Field Staff View: register + nearest ──
    var fieldView: some View {
        List {
            // Current location card
            Section(header: Text("My Location")) {
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
                        Text(String(loc.updatedAt.prefix(16)))
                            .font(.caption2).foregroundColor(.secondary)
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
                    TextField("Unit (e.g. 320)", text: $unit)
                        .keyboardType(.numbersAndPunctuation)
                    Divider()
                    TextField("Area (e.g. str3000)", text: $areaText)
                }

                Button(action: saveLocation) {
                    HStack {
                        if isSaving { ProgressView().scaleEffect(0.8) }
                        else { Image(systemName: "location.fill") }
                        Text("Save Location")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(unit.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

                if let msg = saveMsg {
                    Text(msg).font(.caption)
                        .foregroundColor(saveMsgOk ? .green : .red)
                }
            }

            // Nearest person
            if myLocation != nil {
                let title = user?.role == "safety_officer" ? "Nearest Supervisor" : "Nearest Safety Officer"
                Section(header: HStack {
                    Text(title)
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.7) }
                    else { Button(action: { Task { await loadNearest() } }) {
                        Image(systemName: "arrow.clockwise").font(.caption)
                    }}
                }) {
                    if nearest.isEmpty {
                        Text("No one has registered their location yet")
                            .font(.caption).foregroundColor(.secondary).padding(.vertical, 6)
                    } else {
                        ForEach(nearest) { person in
                            LocationPersonRow(person: person, showRole: false)
                        }
                    }
                }
            }

            // Site supervisor: all supervisors
            if isSiteSup && myLocation != nil {
                Section(header: HStack {
                    Text("My Supervisors' Locations")
                    Spacer()
                    Button(action: { Task { await loadSupervisorLocations() } }) {
                        Image(systemName: "arrow.clockwise").font(.caption)
                    }
                }) {
                    if allLocations.isEmpty {
                        Text("No supervisors have registered their location")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(allLocations) { s in
                            LocationPersonRow(person: s, showRole: false)
                        }
                    }
                }
            }
        }
        .navigationTitle("📍 My Location")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    // ── Helpers ──
    @ViewBuilder
    private func pkgBadge(_ p: Int) -> some View {
        Text("PKG \(p)")
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 8).padding(.vertical, 3)
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
        if isSiteSup { await loadSupervisorLocations() }
    }

    private func loadNearest() async {
        isLoading = true
        defer { isLoading = false }
        nearest = (try? await NetworkManager.shared.getNearestPersons()) ?? []
    }

    private func loadSupervisorLocations() async {
        allLocations = (try? await NetworkManager.shared.getMySupervisorsLocations()) ?? []
    }

    private func loadAdminLocations() async {
        isLoading = true
        defer { isLoading = false }
        allLocations = (try? await NetworkManager.shared.getAllLocations()) ?? []
    }

    private func saveLocation() {
        let u = unit.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, let p = Int(pkg) else { return }
        isSaving = true; saveMsg = nil
        Task {
            do {
                try await NetworkManager.shared.saveLocation(pkg: p, unit: u,
                    areaText: areaText.trimmingCharacters(in: .whitespaces))
                saveMsg = "✓ Location saved"
                saveMsgOk = true
                if let loc = try? await NetworkManager.shared.getMyLocation() { myLocation = loc }
                await loadNearest()
            } catch {
                saveMsg = "✗ Failed to save"
                saveMsgOk = false
            }
            isSaving = false
        }
    }
}

// ── Location Person Row ─────────────────────────────
struct LocationPersonRow: View {
    let person: NearestPerson
    let showRole: Bool

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
                if showRole {
                    Text(person.roleLabel).font(.caption2).foregroundColor(.secondary)
                } else {
                    Text(person.supervisorCode).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if person.proximity >= 0 {
                Text(person.proximityLabel)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(proximityColor.opacity(0.15))
                    .foregroundColor(proximityColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 3)
    }
}
