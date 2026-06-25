import SwiftUI

@main
struct HRApp: App {
    @ObservedObject private var session = SessionManager.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if session.isLoggedIn {
                MainTabView()
                    .environmentObject(session)
                    .environment(\.layoutDirection, .rightToLeft)
                    .preferredColorScheme(.light)
            } else {
                LoginView()
                    .environmentObject(session)
                    .environment(\.layoutDirection, .rightToLeft)
                    .preferredColorScheme(.light)
            }
        }
    }
}

// ═══════════════════════════════════════════════════
//  AppDelegate — إشعارات
// ═══════════════════════════════════════════════════
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        // ✅ تفعيل مراقب الشبكة وOfflineQueue من أول تشغيل
        _ = OfflineQueue.shared
        return true
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }

    // ── جدولة إشعار الأربعاء الساعة 10 صباحاً ──
    static func scheduleWednesdayReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["wednesday_eval_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "تذكير التقييم الأسبوعي"
        content.body  = "باقي يومان على نهاية الأسبوع — تأكد من إكمال تقييمات موظفيك"
        content.sound = .default

        var dateComponents        = DateComponents()
        dateComponents.weekday    = 4  // الأربعاء (1=الأحد، 4=الأربعاء)
        dateComponents.hour       = 10
        dateComponents.minute     = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "wednesday_eval_reminder",
                                            content: content, trigger: trigger)
        center.add(request)
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenStr = deviceToken.map { String(format: "%02x", $0) }.joined()
        // احفظه محلياً أولاً
        UserDefaults.standard.set(tokenStr, forKey: "apns_device_token")
        // إذا المستخدم مسجّل دخول أرسله فوراً
        if SessionManager.shared.isLoggedIn {
            Task { try? await NetworkManager.shared.registerDeviceToken(tokenStr) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // عند استلام إشعار — نُحدّث القائمة والـ badge
        let title = notification.request.content.title
        if title.contains("إنذار") || title.contains("تحديث") || title.contains("طلب") {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshRequests"), object: nil)
            }
        }
        // نحدّث الـ badge من السيرفر
        Task { await AppDelegate.updateBadge() }
        return [.banner, .badge, .sound]
    }

    // عند الضغط على الإشعار من خارج التطبيق
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        // صفّر الـ badge عند فتح الإشعار
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRequests"), object: nil)
        }
    }

    // تحديث badge + صفّر الإشعارات المُسلَّمة عند فتح التطبيق
    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        Task {
            await OfflineQueue.shared.syncAll()
            await AppDelegate.updateBadge()
        }
    }

    // جلب عدد الطلبات المعلقة من السيرفر وتحديث الـ badge
    static func updateBadge() async {
        guard SessionManager.shared.isLoggedIn else {
            await MainActor.run { UIApplication.shared.applicationIconBadgeNumber = 0 }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(
                for: NetworkManager.shared.makeRequest("/api/badge"))
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = json["badge"] as? Int {
                await MainActor.run {
                    UIApplication.shared.applicationIconBadgeNumber = count
                }
            }
        } catch {
            // لو فشل نصفّر
            await MainActor.run { UIApplication.shared.applicationIconBadgeNumber = 0 }
        }
    }
}
