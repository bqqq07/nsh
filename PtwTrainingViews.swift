import SwiftUI
import PhotosUI

// ═══════════════════════════════════════════════════
//  MARK: - PTW Training Home (officer)
// ═══════════════════════════════════════════════════
struct PtwTrainingHomeView: View {
    @State private var status: PtwStatusResponse? = nil
    @State private var isLoading = true
    @State private var errorMsg  = ""

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let accentGreen = Color(hex: "#16a34a")

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading...").frame(maxHeight: .infinity)
                } else if let s = status, s.active {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            PtwProgressBanner(modules: s.modules)
                            Text("Training Modules")
                                .font(.headline)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(s.modules) { mod in
                                    NavigationLink(destination: PtwModuleDoorsView(mod: mod)) {
                                        PtwModuleCard(mod: mod)
                                    }
                                    .disabled(mod.locked)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else if !errorMsg.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundColor(.orange)
                        Text(errorMsg).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    Text("PTW Training is not active.").foregroundColor(.secondary).padding()
                }
            }
            .navigationTitle("PTW Training")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true; errorMsg = ""
        do { status = try await NetworkManager.shared.ptwTrainingStatus() }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

private struct PtwProgressBanner: View {
    let modules: [PtwModuleSummary]
    var totalDone:  Int { modules.reduce(0) { $0 + $1.done } }
    var totalItems: Int { modules.reduce(0) { $0 + $1.total } }
    var progress: Double { totalItems > 0 ? Double(totalDone) / Double(totalItems) : 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Overall Progress").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%").font(.subheadline.bold()).foregroundColor(Color(hex: "#16a34a"))
            }
            ProgressView(value: progress)
                .tint(Color(hex: "#16a34a"))
            HStack {
                Text("\(totalDone) / \(totalItems) doors completed").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct PtwModuleCard: View {
    let mod: PtwModuleSummary
    var progress: Double { mod.total > 0 ? Double(mod.done) / Double(mod.total) : 0 }
    var isComplete: Bool { mod.done >= mod.total && mod.total > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle().fill(mod.locked ? Color.gray.opacity(0.15) : Color(hex: "#16a34a").opacity(0.12))
                        .frame(width: 36, height: 36)
                    if mod.locked {
                        Image(systemName: "lock.fill").font(.callout).foregroundColor(.gray)
                    } else if isComplete {
                        Image(systemName: "checkmark.seal.fill").font(.callout).foregroundColor(Color(hex: "#16a34a"))
                    } else {
                        Text("\(mod.seq)").font(.callout.bold()).foregroundColor(Color(hex: "#16a34a"))
                    }
                }
                Spacer()
                Text("\(mod.done)/\(mod.total)").font(.caption2).foregroundColor(.secondary)
            }
            Text(mod.title).font(.caption.bold()).lineLimit(3).foregroundColor(mod.locked ? .secondary : .primary)
            ProgressView(value: progress).tint(Color(hex: "#16a34a"))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
        .opacity(mod.locked ? 0.6 : 1)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Module Doors List
// ═══════════════════════════════════════════════════
struct PtwModuleDoorsView: View {
    let mod: PtwModuleSummary
    @State private var doorsResp: PtwModuleDoorsResponse? = nil
    @State private var isLoading = true
    @State private var errorMsg  = ""

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...").frame(maxHeight: .infinity)
            } else if let resp = doorsResp {
                List(resp.doors) { door in
                    NavigationLink(destination: PtwDoorView(modSeq: mod.seq, doorSeq: door.seq)) {
                        PtwDoorRow(door: door)
                    }
                    .disabled(!(door.unlocked ?? false))
                }
                .listStyle(.insetGrouped)
            } else {
                Text(errorMsg).foregroundColor(.secondary).padding()
            }
        }
        .navigationTitle("Module \(mod.seq)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { doorsResp = try await NetworkManager.shared.ptwModuleDoors(modSeq: mod.seq) }
        catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

private struct PtwDoorRow: View {
    let door: PtwDoorDetail
    var unlocked: Bool { door.unlocked ?? false }

    var statusColor: Color {
        switch door.status {
        case "approved": return .green
        case "pending":  return .orange
        case "rejected": return .red
        default:         return .gray
        }
    }

    var statusIcon: String {
        switch door.status {
        case "approved": return "checkmark.circle.fill"
        case "pending":  return "clock.fill"
        case "rejected": return "xmark.circle.fill"
        default:         return unlocked ? "circle" : "lock.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon).foregroundColor(unlocked ? statusColor : .gray).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(door.title).font(.subheadline).foregroundColor(unlocked ? .primary : .secondary)
                if door.ref_only {
                    Text("Reference door — tap to mark reviewed").font(.caption).foregroundColor(.secondary)
                } else if door.status == "rejected", let note = door.reviewer_note, !note.isEmpty {
                    Text("Rejected: \(note)").font(.caption).foregroundColor(.red).lineLimit(1)
                } else if door.status == "pending" {
                    Text("Awaiting supervisor review").font(.caption).foregroundColor(.orange)
                } else if door.status == "not_started" && unlocked {
                    Text("Tap to submit").font(.caption).foregroundColor(.blue)
                }
            }
            Spacer()
        }
        .opacity(unlocked ? 1 : 0.5)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Door Submission View
// ═══════════════════════════════════════════════════
struct PtwDoorView: View {
    let modSeq: Int
    let doorSeq: Int

    @State private var door: PtwDoorDetail? = nil
    @State private var isLoading = true
    @State private var isBusy    = false
    @State private var errorMsg  = ""
    @State private var answers: [String] = []
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var photoImage: Image? = nil
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...").padding(.top, 60)
            } else if let d = door {
                VStack(alignment: .leading, spacing: 16) {
                    doorHeader(d)
                    if d.status == "approved" {
                        approvedBanner(d)
                    } else if d.status == "pending" {
                        pendingBanner
                    } else {
                        if !d.ref_only {
                            questionsSection(d)
                            photoSection
                        }
                        submitButton(d)
                    }
                    if !errorMsg.isEmpty {
                        Text(errorMsg).foregroundColor(.red).font(.caption).padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Door \(doorSeq)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Submitted!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your submission is pending supervisor review.")
        }
    }

    @ViewBuilder
    private func doorHeader(_ d: PtwDoorDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d.title).font(.title3.bold()).padding(.horizontal)
            if !d.brief.isEmpty {
                Text(d.brief).font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
            }
            if !d.ref.isEmpty {
                Text("Reference: \(d.ref)").font(.caption).foregroundColor(.blue).padding(.horizontal)
            }
            if d.ref_only {
                Label("Reference door — read and mark as reviewed", systemImage: "book.fill")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal).padding(.vertical, 4)
                    .background(Color(.systemGray6)).cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func approvedBanner(_ d: PtwDoorDetail) -> some View {
        VStack(spacing: 8) {
            Label("Approved", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(.green)
            if !d.answers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your answers:").font(.subheadline.bold())
                    ForEach(Array(d.answers.enumerated()), id: \.offset) { i, ans in
                        if i < d.questions.count {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Q\(i+1): \(d.questions[i])").font(.caption).foregroundColor(.secondary)
                                Text(ans).font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6)).cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.green.opacity(0.08)).cornerRadius(12).padding(.horizontal)
    }

    private var pendingBanner: some View {
        Label("Submitted — awaiting review", systemImage: "clock.fill")
            .font(.subheadline).foregroundColor(.orange)
            .frame(maxWidth: .infinity).padding()
            .background(Color.orange.opacity(0.1)).cornerRadius(12).padding(.horizontal)
    }

    @ViewBuilder
    private func questionsSection(_ d: PtwDoorDetail) -> some View {
        if !d.questions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Questions").font(.headline).padding(.horizontal)
                ForEach(Array(d.questions.enumerated()), id: \.offset) { i, q in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Q\(i+1): \(q)").font(.subheadline.bold())
                        TextField("Your answer", text: Binding(
                            get: { i < answers.count ? answers[i] : "" },
                            set: { v in
                                while answers.count <= i { answers.append("") }
                                answers[i] = v
                            }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Evidence").font(.headline).padding(.horizontal)
            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                        .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(.systemGray5)).cornerRadius(8)
                }
                if let img = photoImage {
                    img.resizable().scaledToFill()
                        .frame(width: 60, height: 60).clipped().cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .onChange(of: selectedPhoto) { item in
            Task {
                guard let item else { return }
                if let d = try? await item.loadTransferable(type: Data.self) {
                    photoData = d
                    if let ui = UIImage(data: d) { photoImage = Image(uiImage: ui) }
                }
            }
        }
    }

    @ViewBuilder
    private func submitButton(_ d: PtwDoorDetail) -> some View {
        Button {
            Task { await submit(d) }
        } label: {
            if isBusy {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(14)
                    .background(Color(hex: "#16a34a")).cornerRadius(12)
            } else {
                Text(d.ref_only ? "Mark as Reviewed" : "Submit")
                    .font(.headline).frame(maxWidth: .infinity).padding(14)
                    .background(Color(hex: "#16a34a")).foregroundColor(.white).cornerRadius(12)
            }
        }
        .disabled(isBusy)
        .padding(.horizontal)
    }

    private func load() async {
        isLoading = true
        do {
            door = try await NetworkManager.shared.ptwDoorDetail(modSeq: modSeq, doorSeq: doorSeq)
            if let d = door { answers = Array(repeating: "", count: d.questions.count) }
        } catch { errorMsg = error.localizedDescription }
        isLoading = false
    }

    private func submit(_ d: PtwDoorDetail) async {
        isBusy = true; errorMsg = ""
        do {
            _ = try await NetworkManager.shared.ptwSubmitDoor(
                modSeq: modSeq, doorSeq: doorSeq,
                answers: answers,
                photoData: photoData,
                photoExt: "jpg"
            )
            showSuccess = d.ref_only ? false : true
            if d.ref_only { dismiss() }
        } catch { errorMsg = error.localizedDescription }
        isBusy = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Supervisor Pending Review
// ═══════════════════════════════════════════════════
struct PtwSupervisorReviewView: View {
    @State private var items: [PtwPendingItem] = []
    @State private var isLoading = true
    @State private var selectedItem: PtwPendingItem? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...").frame(maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill").font(.largeTitle).foregroundColor(.secondary)
                    Text("No pending submissions").foregroundColor(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                List(items) { item in
                    Button { selectedItem = item } label: {
                        PtwPendingRow(item: item)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("PTW Submissions (\(items.count))")
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedItem) { item in
            PtwReviewSheet(item: item) { await load() }
        }
    }

    private func load() async {
        isLoading = true
        items = (try? await NetworkManager.shared.ptwSupervisorPending()) ?? []
        isLoading = false
    }
}

private struct PtwPendingRow: View {
    let item: PtwPendingItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.officer_name).font(.subheadline.bold())
                Spacer()
                Text(item.submitted_at.flatMap { PtwReviewSheet.shortDate($0) } ?? "").font(.caption).foregroundColor(.secondary)
            }
            Text("Module \(item.module_seq): \(item.module_title)").font(.caption).foregroundColor(.secondary)
            Text("Door \(item.door_seq): \(item.door_title)").font(.caption).foregroundColor(.blue)
        }
    }
}

struct PtwReviewSheet: View {
    let item: PtwPendingItem
    let onDone: () async -> Void

    @State private var note = ""
    @State private var isBusy = false
    @State private var errorMsg = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        HStack { Text("Officer:").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.officer_name).font(.subheadline.bold()) }
                        HStack { Text("Module:").font(.caption).foregroundColor(.secondary); Spacer(); Text("M\(item.module_seq): \(item.module_title)").font(.subheadline) }
                        HStack { Text("Door:").font(.caption).foregroundColor(.secondary); Spacer(); Text("D\(item.door_seq): \(item.door_title)").font(.subheadline) }
                    }
                    .padding(.horizontal)

                    Divider()

                    if !item.answers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Answers").font(.headline).padding(.horizontal)
                            ForEach(Array(item.answers.enumerated()), id: \.offset) { i, ans in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Q\(i+1)").font(.caption.bold()).foregroundColor(.secondary)
                                    Text(ans).font(.subheadline)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if !item.photo_path.isEmpty {
                        AsyncImage(url: URL(string: "\(BASE_URL)/static/hse_photos/\(item.photo_path)")) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit().cornerRadius(10)
                            default: Color(.systemGray5).frame(height: 120).cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note (optional)").font(.subheadline.bold()).padding(.horizontal)
                        TextField("Reviewer note...", text: $note, axis: .vertical)
                            .lineLimit(2...4).textFieldStyle(.roundedBorder).padding(.horizontal)
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg).foregroundColor(.red).font(.caption).padding(.horizontal)
                    }

                    HStack(spacing: 12) {
                        Button { Task { await review("reject") } } label: {
                            Label("Reject", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity).padding(12)
                                .background(Color.red).foregroundColor(.white).cornerRadius(12)
                        }
                        Button { Task { await review("approve") } } label: {
                            Label("Approve", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity).padding(12)
                                .background(Color(hex: "#16a34a")).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    .disabled(isBusy)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Review Submission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func review(_ action: String) async {
        isBusy = true; errorMsg = ""
        do {
            _ = try await NetworkManager.shared.ptwSupervisorReview(subId: item.id, action: action, note: note)
            await onDone()
            dismiss()
        } catch { errorMsg = error.localizedDescription }
        isBusy = false
    }

    static func shortDate(_ iso: String) -> String? {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else { return nil }
        let out = DateFormatter(); out.dateFormat = "d MMM yyyy"
        return out.string(from: d)
    }
}
