//
//  OfflineQueue.swift
//  z NSH
//
//  نظام offline بسيط — يحفظ العمليات محلياً ويرسلها لما الشبكة ترجع
//  بدون CoreData — يستخدم UserDefaults فقط
//

import SwiftUI
import Network
import Combine

// ═══════════════════════════════════════════════════
//  MARK: - نوع العملية المحفوظة
// ═══════════════════════════════════════════════════
struct PendingOperation: Codable, Identifiable {
    let id:        String          // UUID فريد
    let type:      OperationType
    let endpoint:  String          // مثال: /api/attendance/save
    let method:    String          // POST / PUT
    let payload:   Data            // JSON body
    let createdAt: Date
    var attempts:  Int             // عدد محاولات الإرسال

    enum OperationType: String, Codable {
        case attendance      = "حضور"
        case dailyEval       = "تقييم يومي"
        case weeklyEval      = "تقييم أسبوعي"
        case request         = "طلب"
        // HSE operations
        case hseCheckin      = "تسجيل حضور HSE"
        case hseObservation  = "ملاحظة سلامة"
        case hseTbt          = "TBT"
        case hseNearMiss     = "حادثة وشيكة"
        case hseBbs          = "BBS"
        case hseJso          = "إغلاق JSO"
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - OfflineQueue الرئيسي
// ═══════════════════════════════════════════════════
@MainActor
class OfflineQueue: ObservableObject {

    static let shared = OfflineQueue()

    // ── الحالة ──
    @Published var isOnline:     Bool = true
    @Published var pendingCount: Int  = 0
    @Published var isSyncing:    Bool = false

    // ── التخزين ──
    private let storageKey = "offline_queue_v1"
    private let maxAttempts = 5
    private var operations: [PendingOperation] = []

    // ── Network Monitor ──
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "nsh.network.monitor")

    private init() {
        loadFromDisk()
        startMonitoring()
    }

    // ═══════════════════════════════════════════════
    //  MARK: - إضافة عملية للـ queue
    // ═══════════════════════════════════════════════
    func enqueue(
        type: PendingOperation.OperationType,
        endpoint: String,
        method: String = "POST",
        payload: [String: Any]
    ) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        let op = PendingOperation(
            id:        UUID().uuidString,
            type:      type,
            endpoint:  endpoint,
            method:    method,
            payload:   data,
            createdAt: Date(),
            attempts:  0
        )
        operations.append(op)
        saveToDisk()
        pendingCount = operations.count

        // لو الشبكة شغّالة حاول فوراً
        if isOnline {
            Task { await syncAll() }
        }
    }

    // ═══════════════════════════════════════════════
    //  MARK: - إرسال كل العمليات المعلقة
    // ═══════════════════════════════════════════════
    func syncAll() async {
        guard isOnline, !isSyncing, !operations.isEmpty else { return }

        isSyncing = true
        var remaining: [PendingOperation] = []

        for var op in operations {
            let success = await sendOperation(op)
            if success {
                // تم الإرسال — لا نضيفه للـ remaining
            } else {
                op.attempts += 1
                if op.attempts < maxAttempts {
                    remaining.append(op)
                }
                // لو تجاوز maxAttempts — نحذفه (بيانات قديمة جداً)
            }
        }

        operations = remaining
        saveToDisk()
        pendingCount = operations.count
        isSyncing = false
    }

    // ═══════════════════════════════════════════════
    //  MARK: - إرسال عملية واحدة
    // ═══════════════════════════════════════════════
    private func sendOperation(_ op: PendingOperation) async -> Bool {
        var req = NetworkManager.shared.makeRequest(op.endpoint, method: op.method, body: op.payload)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            // نعتبر 200 و201 و409 (مكرر) نجاحاً
            return code == 200 || code == 201 || code == 409
        } catch {
            return false
        }
    }

    // ═══════════════════════════════════════════════
    //  MARK: - مراقبة الشبكة
    // ═══════════════════════════════════════════════
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = (path.status == .satisfied)

                // لو رجعت الشبكة — أرسل كل المعلق
                if wasOffline && self.isOnline && !self.operations.isEmpty {
                    await self.syncAll()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // ═══════════════════════════════════════════════
    //  MARK: - حفظ وتحميل من الذاكرة
    // ═══════════════════════════════════════════════
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let ops  = try? JSONDecoder().decode([PendingOperation].self, from: data)
        else { return }
        operations   = ops
        pendingCount = ops.count
    }

    // ═══════════════════════════════════════════════
    //  MARK: - مسح كل المعلق (للطوارئ)
    // ═══════════════════════════════════════════════
    func clearAll() {
        operations   = []
        pendingCount = 0
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - شريط حالة الـ offline (يُضاف فوق أي View)
// ═══════════════════════════════════════════════════
struct OfflineBanner: View {
    @ObservedObject var queue = OfflineQueue.shared

    var body: some View {
        if !queue.isOnline || queue.pendingCount > 0 || queue.isSyncing {
            HStack(spacing: 8) {
                if queue.isSyncing {
                    ProgressView().scaleEffect(0.8).tint(.white)
                    Text("جارٍ المزامنة...")
                } else if !queue.isOnline {
                    Image(systemName: "wifi.slash")
                    Text(queue.pendingCount > 0
                         ? "غير متصل — \(queue.pendingCount) عملية معلقة"
                         : "غير متصل")
                } else if queue.pendingCount > 0 {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("\(queue.pendingCount) عملية قيد الإرسال")
                }
            }
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(queue.isOnline ? Color(hex: "#f39c12") : Color(hex: "#e74c3c"))
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: queue.isOnline)
        }
    }
}
