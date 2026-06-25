//
//  CacheManager.swift
//  z NSH
//
//  Cache خفيف للبيانات — يعرض القديم فوراً ويجلب الجديد في الخلفية
//  بدون مكتبات خارجية — UserDefaults فقط
//

import Foundation

// ══════════════════════════════════════════════════════
//  MARK: - CacheManager
// ══════════════════════════════════════════════════════
class CacheManager {
    static let shared = CacheManager()
    private init() {}

    private let ttl: TimeInterval = 5 * 60  // 5 دقائق — بعدها يُعتبر قديم

    // ── حفظ ──
    func save<T: Codable>(_ value: T, key: String) {
        let wrapper = CacheWrapper(data: value, savedAt: Date())
        if let data = try? JSONEncoder().encode(wrapper) {
            UserDefaults.standard.set(data, forKey: "cache_\(key)")
        }
    }

    // ── تحميل ──
    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: "cache_\(key)"),
              let wrapper = try? JSONDecoder().decode(CacheWrapper<T>.self, from: data)
        else { return nil }
        return wrapper.data
    }

    // ── هل البيانات حديثة؟ ──
    func isFresh(key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "cache_\(key)"),
              let wrapper = try? JSONDecoder().decode(CacheWrapper<CacheDate>.self, from: data)
        else { return false }
        return Date().timeIntervalSince(wrapper.savedAt) < ttl
    }

    // ── مسح كل الـ cache ──
    func clearAll() {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("cache_") }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // ── مسح مفتاح محدد ──
    func clear(key: String) {
        UserDefaults.standard.removeObject(forKey: "cache_\(key)")
    }
}

// ── Wrapper داخلي ──
private struct CacheWrapper<T: Codable>: Codable {
    let data:    T
    let savedAt: Date
}

// ── نوع مساعد للتحقق من التاريخ فقط ──
private struct CacheDate: Codable {}

// ══════════════════════════════════════════════════════
//  MARK: - Extension على NetworkManager للـ Cache
// ══════════════════════════════════════════════════════
extension NetworkManager {

    // ── جلب الموظفين مع Cache ──
    func getEmployeesCached() async throws -> [Employee] {
        let key = "employees_\(SessionManager.shared.currentUser?.id ?? 0)"

        // أرجع القديم فوراً لو موجود
        if let cached: [Employee] = CacheManager.shared.load([Employee].self, key: key) {
            // جلب جديد في الخلفية لو انتهت الصلاحية
            if !CacheManager.shared.isFresh(key: key) {
                Task {
                    if let fresh = try? await self.getEmployees() {
                        CacheManager.shared.save(fresh, key: key)
                    }
                }
            }
            return cached
        }

        // لا يوجد cache — جلب مباشر
        let fresh = try await getEmployees()
        CacheManager.shared.save(fresh, key: key)
        return fresh
    }

    // ── جلب التقارير الأسبوعية مع Cache ──
    func getWeeklyReportsCached(ws: String, we: String) async throws -> [EvalReport] {
        let key = "weekly_reports_\(ws)_\(we)_\(SessionManager.shared.currentUser?.id ?? 0)"

        if let cached: [EvalReport] = CacheManager.shared.load([EvalReport].self, key: key) {
            if !CacheManager.shared.isFresh(key: key) {
                Task {
                    if let fresh = try? await self.getWeeklyReports(ws: ws, we: we) {
                        CacheManager.shared.save(fresh, key: key)
                    }
                }
            }
            return cached
        }

        let fresh = try await getWeeklyReports(ws: ws, we: we)
        CacheManager.shared.save(fresh, key: key)
        return fresh
    }

    // ── جلب KPI مع Cache ──
    func getKPICached(ws: String?, we: String?) async throws -> KPIData {
        let key = "kpi_\(ws ?? "cur")_\(we ?? "cur")"

        if let cached: KPIData = CacheManager.shared.load(KPIData.self, key: key) {
            if !CacheManager.shared.isFresh(key: key) {
                Task {
                    if let fresh = try? await self.getKPI(ws: ws, we: we) {
                        CacheManager.shared.save(fresh, key: key)
                    }
                }
            }
            return cached
        }

        let fresh = try await getKPI(ws: ws, we: we)
        CacheManager.shared.save(fresh, key: key)
        return fresh
    }

    // ── جلب طلبات المشرف مع Cache ──
    func getMyRequestsCached() async throws -> [RequestItem] {
        let key = "my_requests_\(SessionManager.shared.currentUser?.id ?? 0)"

        if let cached: [RequestItem] = CacheManager.shared.load([RequestItem].self, key: key) {
            Task {
                if let fresh = try? await self.getMyRequests() {
                    CacheManager.shared.save(fresh, key: key)
                }
            }
            return cached  // دايماً يجلب جديد في الخلفية للطلبات
        }

        let fresh = try await getMyRequests()
        CacheManager.shared.save(fresh, key: key)
        return fresh
    }
}
