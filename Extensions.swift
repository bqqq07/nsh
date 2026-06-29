//
//  Extensions.swift
//  z NSH
//

import SwiftUI

// ═══════════════════════════════════════════════════
//  MARK: - Color from Hex
// ═══════════════════════════════════════════════════
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - View placeholder
// ═══════════════════════════════════════════════════
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .trailing) {
            if shouldShow { placeholder() }
            self
        }
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Date Helpers
// ═══════════════════════════════════════════════════

// ✅ إصلاح: static formatter يُنشأ مرة واحدة فقط بدل كل استدعاء
private let _isoFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.locale = Locale(identifier: "en_US_POSIX")  // مهم: يمنع تأثير إعدادات الجهاز
    return df
}()

// ✅ إصلاح: static calendar يُنشأ مرة واحدة
private let _gregorianCal: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 1  // الأحد = أول الأسبوع
    return cal
}()

extension Date {
    var iso: String {
        _isoFormatter.string(from: self)
    }

    // أقرب يوم أحد سابق أو نفس اليوم
    var previousSunday: Date {
        let weekday = _gregorianCal.component(.weekday, from: self)  // 1=أحد
        let diff = -(weekday - 1)
        return _gregorianCal.date(byAdding: .day, value: diff, to: self) ?? self
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Conditional View Modifier
// ═══════════════════════════════════════════════════
extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
