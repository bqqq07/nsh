//
//  AttendanceViews.swift
//  z NSH
//
//  تقويم الحضور الشهري للمشرف — يُفتح من صفحة تفاصيل الموظف
//

import SwiftUI

// ══════════════════════════════════════════════════════
//  MARK: - تقويم الحضور الشهري للمشرف
// ══════════════════════════════════════════════════════

struct AttendanceCalendarView: View {
    let employee: Employee
    @State private var monthOffset = 0
    @State private var records: [String: String] = [:]   // "2025-03-05": "present"
    @State private var isLoading = true

    private var currentMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }
    private var monthTitle: String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"; df.locale = Locale(identifier: "ar")
        return df.string(from: currentMonth)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── رأس الشهر ──
            HStack {
                Button {
                    monthOffset += 1
                    Task { await loadMonth() }
                } label: { Image(systemName: "chevron.right").foregroundColor(Color(hex: "#4f8ef7")) }

                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()

                Button {
                    if monthOffset < 0 { monthOffset += 1; Task { await loadMonth() } }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(monthOffset < 0 ? Color(hex: "#4f8ef7") : .gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.white)

            // ── أيام الأسبوع ──
            HStack(spacing: 0) {
                ForEach(["أح","إث","ثل","أر","خم","جم","سب"], id: \.self) { day in
                    Text(day).font(.caption2.bold()).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            .background(Color.white)
            .shadow(color: .black.opacity(0.04), radius: 4)

            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else {
                // ── شبكة التقويم ──
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(calendarDays(), id: \.self) { dateStr in
                            CalendarDayCell(
                                dateStr:  dateStr,
                                status:   dateStr.isEmpty ? nil : records[dateStr],
                                isToday:  dateStr == Date().iso,
                                isFuture: dateStr > Date().iso
                            )
                        }
                    }
                    .padding(8)

                    // ── مفتاح الألوان ──
                    HStack(spacing: 20) {
                        CalLegend(color: Color(hex: "#2ecc71"), label: "حاضر")
                        CalLegend(color: Color(hex: "#e74c3c"), label: "غائب")
                        CalLegend(color: Color(hex: "#f39c12"), label: "إجازة")
                        CalLegend(color: Color(hex: "#ecf0f1"), label: "لم يُسجَّل")
                    }
                    .padding()
                }
            }
        }
        .background(Color(hex: "#f0f4ff"))
        .navigationTitle("سجل حضور \(employee.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMonth() }
    }

    // ── كل أيام الشهر بشكل شبكة ──
    private func calendarDays() -> [String] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let firstWeekday = cal.component(.weekday, from: first) - 1  // 0=أحد

        var days: [String] = Array(repeating: "", count: firstWeekday)
        for day in range {
            let d = cal.date(byAdding: .day, value: day - 1, to: first)!
            days.append(df.string(from: d))
        }
        // أكمل الأسبوع الأخير
        while days.count % 7 != 0 { days.append("") }
        return days
    }

    private func loadMonth() async {
        isLoading = true
        // نجلب كل أيام الشهر
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else {
            isLoading = false; return
        }

        var result: [String: String] = [:]

        // نجلب الشهر أسبوعاً بأسبوع (5 طلبات كحد أقصى)
        var current = first
        while cal.component(.month, from: current) == cal.component(.month, from: first) {
            if let rows = try? await NetworkManager.shared.getAttendance(date: current.iso) {
                for row in rows where row.empId == employee.id {
                    if let status = row.status {
                        result[current.iso] = status
                    }
                }
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }

        records   = result
        isLoading = false
    }
}

struct CalendarDayCell: View {
    let dateStr:  String
    let status:   String?
    let isToday:  Bool
    let isFuture: Bool

    private var dayNum: String {
        String(dateStr.suffix(2).drop(while: { $0 == "0" }))
    }

    private var bg: Color {
        if dateStr.isEmpty { return .clear }
        if isFuture        { return Color(hex: "#f8f9fa") }
        switch status {
        case "present": return Color(hex: "#2ecc71").opacity(0.85)
        case "absent":  return Color(hex: "#e74c3c").opacity(0.85)
        case "leave":   return Color(hex: "#f39c12").opacity(0.85)
        default:        return Color(hex: "#ecf0f1")
        }
    }

    private var fg: Color {
        if isFuture { return .gray.opacity(0.4) }
        switch status {
        case "present", "absent", "leave": return .white
        default: return .secondary
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Color(hex: "#4f8ef7") : .clear, lineWidth: 2)
                )

            if !dateStr.isEmpty {
                Text(dayNum)
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundColor(fg)
            }
        }
        .frame(height: 38)
    }
}

struct CalLegend: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 14, height: 14)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
