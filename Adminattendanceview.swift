//
//  AdminAttendanceView.swift
//  z NSH
//
//  شاشة الحضور الشهرية للأدمن:
//  - ملخص عام (نسبة حضور + أعداد)
//  - جدول كل موظف بالشهر (حاضر/غائب/إجازة/نسبة)
//  - فلترة بالقسم أو الموقع أو المشرف
//

import SwiftUI

// ══════════════════════════════════════════════════════
//  MARK: - Models
// ══════════════════════════════════════════════════════
struct MonthlyAttSummary: Codable {
    let total_employees: Int
    let total_present:   Int
    let total_absent:    Int
    let total_leave:     Int
    let avg_rate:        Double
}

struct MonthlyAttEmpRow: Codable, Identifiable {
    let emp_id:     Int
    let emp_number: String
    let name:       String
    let department: String
    let site:       String
    let supervisor: String
    let present:    Int
    let absent:     Int
    let leave:      Int
    let recorded:   Int
    let rate:       Double
    var id: Int { emp_id }
}

struct MonthlyAttResponse: Codable {
    let year:      Int
    let month:     Int
    let days:      Int
    let summary:   MonthlyAttSummary
    let employees: [MonthlyAttEmpRow]
}

// ══════════════════════════════════════════════════════
//  MARK: - AdminAttendanceView
// ══════════════════════════════════════════════════════
@MainActor
struct AdminAttendanceView: View {

    // ── حالة التاريخ ──
    @State private var year:  Int = Calendar.current.component(.year,  from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    // ── بيانات ──
    @State private var response:  MonthlyAttResponse? = nil
    @State private var isLoading    = true
    @State private var errorMsg     = ""
    @State private var isGenerating      = false
    @State private var generatingType    = ""   // "summary" or "detailed"
    @State private var pdfURL:           URL? = nil
    @State private var showPDF           = false

    // ── فلترة ──
    @State private var searchText    = ""
    @State private var filterDept    = ""
    @State private var filterSite    = ""
    @State private var sortBy        = SortField.name

    enum SortField: String, CaseIterable {
        case name    = "الاسم"
        case rate    = "نسبة الحضور"
        case absent  = "الغياب"
    }

    // ── الأشهر بالعربي ──
    let monthNames = ["","يناير","فبراير","مارس","أبريل","مايو","يونيو",
                      "يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"]

    // ── القائمة بعد الفلترة والترتيب ──
    var filtered: [MonthlyAttEmpRow] {
        var rows = response?.employees ?? []
        if !searchText.isEmpty {
            rows = rows.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.supervisor.localizedCaseInsensitiveContains(searchText) ||
                $0.emp_number.contains(searchText)
            }
        }
        if !filterDept.isEmpty { rows = rows.filter { $0.department == filterDept } }
        if !filterSite.isEmpty { rows = rows.filter { $0.site == filterSite } }
        switch sortBy {
        case .name:   rows.sort { $0.name < $1.name }
        case .rate:   rows.sort { $0.rate < $1.rate }
        case .absent: rows.sort { $0.absent > $1.absent }
        }
        return rows
    }

    // ── قوائم الأقسام والمواقع ──
    var departments: [String] {
        let all = (response?.employees ?? []).map { $0.department }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }
    var sites: [String] {
        let all = (response?.employees ?? []).map { $0.site }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#f0f4ff").ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── شريط الشهر ──
                    monthPicker

                    if isLoading {
                        Spacer(); ProgressView(); Spacer()
                    } else if let r = response {
                        ScrollView {
                            VStack(spacing: 14) {
                                // ── بطاقات الملخص ──
                                summaryCards(r.summary, days: r.days)

                                // ── فلاتر ──
                                filtersBar

                                // ── جدول الموظفين ──
                                employeeTable
                            }
                            .padding(.vertical, 12)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 50)).foregroundColor(.gray.opacity(0.3))
                            Text("لا توجد بيانات لهذا الشهر").foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("الحضور والغياب")
            .alert("خطأ", isPresented: .constant(!errorMsg.isEmpty), actions: {
                Button("حسناً") { errorMsg = "" }
            }, message: { Text(errorMsg) })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Menu {
                            Button {
                                Task { await generatePDF(type: "summary") }
                            } label: {
                                Label("تقرير إجمالي", systemImage: "doc.text.fill")
                            }
                            Button {
                                Task { await generatePDF(type: "detailed") }
                            } label: {
                                Label("تقرير مفصّل", systemImage: "doc.text.magnifyingglass")
                            }
                        } label: {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(Color(hex: "#7b5ea7"))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showPDF) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .task { await load() }
    }

    // ══════════════════════════════════════════════════
    //  MARK: - Sub Views
    // ══════════════════════════════════════════════════

    // ── شريط اختيار الشهر ──
    var monthPicker: some View {
        HStack {
            Button {
                if month == 1 { month = 12; year -= 1 } else { month -= 1 }
                Task { await load() }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "#7b5ea7")).font(.headline)
            }

            Spacer()
            VStack(spacing: 2) {
                Text(monthNames[month]).font(.headline.bold())
                Text("\(year)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()

            Button {
                let now = Calendar.current.dateComponents([.year,.month], from: Date())
                if year < now.year! || (year == now.year! && month < now.month!) {
                    if month == 12 { month = 1; year += 1 } else { month += 1 }
                    Task { await load() }
                }
            } label: {
                let now = Calendar.current.dateComponents([.year,.month], from: Date())
                Image(systemName: "chevron.left")
                    .foregroundColor(
                        (year < now.year! || (year == now.year! && month < now.month!))
                        ? Color(hex: "#7b5ea7") : .gray.opacity(0.3)
                    )
                    .font(.headline)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // ── بطاقات الملخص ──
    func summaryCards(_ s: MonthlyAttSummary, days: Int) -> some View {
        VStack(spacing: 10) {
            // ── نسبة الحضور ──
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("متوسط نسبة الحضور")
                        .font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", s.avg_rate))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(rateColor(s.avg_rate))
                }
                Spacer()
                // شريط دائري
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#ecf0f1"), lineWidth: 10)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(s.avg_rate / 100))
                        .stroke(rateColor(s.avg_rate), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(s.avg_rate))%")
                        .font(.caption.bold())
                        .foregroundColor(rateColor(s.avg_rate))
                }
            }
            .padding()
            .background(Color.white).cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6)

            // ── الأعداد ──
            HStack(spacing: 10) {
                AttMonthCard(label: "حاضر",       count: s.total_present, color: Color(hex: "#2ecc71"))
                AttMonthCard(label: "غائب",        count: s.total_absent,  color: Color(hex: "#e74c3c"))
                AttMonthCard(label: "إجازة",       count: s.total_leave,   color: Color(hex: "#f39c12"))
                AttMonthCard(label: "الموظفون",    count: s.total_employees, color: Color(hex: "#7b5ea7"))
            }
        }
        .padding(.horizontal)
    }

    // ── شريط الفلاتر ──
    var filtersBar: some View {
        VStack(spacing: 8) {
            // بحث
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("بحث بالاسم أو الرقم أو المشرف", text: $searchText)
            }
            .padding(10).background(Color.white).cornerRadius(10)
            .padding(.horizontal)

            // فلاتر
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // ترتيب
                    Menu {
                        ForEach(SortField.allCases, id: \.self) { f in
                            Button(f.rawValue) { sortBy = f }
                        }
                    } label: {
                        Label("ترتيب: \(sortBy.rawValue)", systemImage: "arrow.up.arrow.down")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color(hex: "#7b5ea7").opacity(0.1))
                            .foregroundColor(Color(hex: "#7b5ea7"))
                            .cornerRadius(20)
                    }

                    // قسم
                    if !departments.isEmpty {
                        Menu {
                            Button("الكل") { filterDept = "" }
                            ForEach(departments, id: \.self) { d in
                                Button(d) { filterDept = d }
                            }
                        } label: {
                            Label(filterDept.isEmpty ? "القسم" : filterDept, systemImage: "building.2")
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(filterDept.isEmpty ? Color.white : Color(hex: "#4f8ef7").opacity(0.1))
                                .foregroundColor(filterDept.isEmpty ? .secondary : Color(hex: "#4f8ef7"))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.04), radius: 3)
                        }
                    }

                    // موقع
                    if !sites.isEmpty {
                        Menu {
                            Button("الكل") { filterSite = "" }
                            ForEach(sites, id: \.self) { s in
                                Button(s) { filterSite = s }
                            }
                        } label: {
                            Label(filterSite.isEmpty ? "الموقع" : filterSite, systemImage: "location")
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(filterSite.isEmpty ? Color.white : Color(hex: "#2ecc71").opacity(0.1))
                                .foregroundColor(filterSite.isEmpty ? .secondary : Color(hex: "#2ecc71"))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.04), radius: 3)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // ── جدول الموظفين ──
    var employeeTable: some View {
        VStack(spacing: 8) {
            // رأس الجدول
            HStack {
                Text("الموظف").font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Text("حاضر").font(.caption.bold()).foregroundColor(Color(hex: "#2ecc71")).frame(width: 44)
                Text("غائب").font(.caption.bold()).foregroundColor(Color(hex: "#e74c3c")).frame(width: 44)
                Text("إجازة").font(.caption.bold()).foregroundColor(Color(hex: "#f39c12")).frame(width: 44)
                Text("نسبة").font(.caption.bold()).foregroundColor(Color(hex: "#7b5ea7")).frame(width: 50)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal)

            // الصفوف
            ForEach(filtered) { emp in
                AttEmpMonthRow(emp: emp)
            }

            if filtered.isEmpty {
                Text("لا توجد نتائج").foregroundColor(.secondary)
                    .padding().frame(maxWidth: .infinity)
                    .background(Color.white).cornerRadius(12).padding(.horizontal)
            }
        }
    }

    // ══════════════════════════════════════════════════
    //  MARK: - Helpers
    // ══════════════════════════════════════════════════
    func rateColor(_ r: Double) -> Color {
        if r >= 90 { return Color(hex: "#2ecc71") }
        if r >= 70 { return Color(hex: "#f39c12") }
        return Color(hex: "#e74c3c")
    }

    func generatePDF(type: String = "detailed") async {
        await MainActor.run {
            isGenerating   = true
            generatingType = type
            errorMsg       = ""
        }
        let path = "/api/admin/monthly-report?year=\(year)&month=\(month)&type=\(type)"
        do {
            let (data, resp) = try await URLSession.shared.data(
                for: NetworkManager.shared.makeRequest(path))
            if (resp as? HTTPURLResponse)?.statusCode == 200 {
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("monthly_\(type)_\(year)_\(month).pdf")
                try data.write(to: tmpURL)
                await MainActor.run { pdfURL = tmpURL; showPDF = true }
            } else {
                errorMsg = "تعذّر توليد التقرير"
            }
        } catch {
            errorMsg = "تعذّر الاتصال بالسيرفر"
        }
        await MainActor.run { isGenerating = false }
    }

    func load() async {
        isLoading = true; errorMsg = ""
        let path = "/api/admin/attendance/monthly?year=\(year)&month=\(month)"
        do {
            let (data, resp) = try await URLSession.shared.data(
                for: NetworkManager.shared.makeRequest(path))
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200 {
                do {
                    response = try JSONDecoder().decode(MonthlyAttResponse.self, from: data)
                } catch let decodeError {
                    // خطأ في التحليل — نعرض تفاصيل للتشخيص
                    let raw = String(data: data, encoding: .utf8) ?? "no data"
                    errorMsg = "خطأ في البيانات: \(decodeError.localizedDescription)"
                    print("❌ Decode error: \(decodeError)")
                    print("❌ Raw response: \(raw.prefix(500))")
                }
            } else if statusCode == 404 {
                errorMsg = "الـ API غير موجود — تأكد من رفع main.py الجديد للسيرفر"
            } else if statusCode == 401 || statusCode == 403 {
                errorMsg = "غير مصرح — تأكد من صلاحية الأدمن"
            } else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                errorMsg = "خطأ \(statusCode)"
                print("❌ Server error \(statusCode): \(raw.prefix(200))")
            }
        } catch {
            errorMsg = "تعذّر الاتصال بالسيرفر: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// ══════════════════════════════════════════════════════
//  MARK: - Sub Components
// ══════════════════════════════════════════════════════

struct AttMonthCard: View {
    let label: String; let count: Int; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white).cornerRadius(12)
        .shadow(color: color.opacity(0.1), radius: 4)
    }
}

struct AttEmpMonthRow: View {
    let emp: MonthlyAttEmpRow

    var rateColor: Color {
        if emp.rate >= 90 { return Color(hex: "#2ecc71") }
        if emp.rate >= 70 { return Color(hex: "#f39c12") }
        return Color(hex: "#e74c3c")
    }

    var body: some View {
        HStack(spacing: 0) {
            // اسم الموظف
            VStack(alignment: .trailing, spacing: 2) {
                Text(emp.name).font(.subheadline.bold()).lineLimit(1)
                HStack(spacing: 4) {
                    if !emp.department.isEmpty {
                        Text(emp.department).font(.caption2).foregroundColor(.secondary)
                    }
                    if !emp.supervisor.isEmpty {
                        Text("• \(emp.supervisor)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // أعداد
            Text("\(emp.present)").font(.subheadline.bold())
                .foregroundColor(Color(hex: "#2ecc71")).frame(width: 44)
            Text("\(emp.absent)").font(.subheadline.bold())
                .foregroundColor(emp.absent > 0 ? Color(hex: "#e74c3c") : .secondary).frame(width: 44)
            Text("\(emp.leave)").font(.subheadline.bold())
                .foregroundColor(emp.leave > 0 ? Color(hex: "#f39c12") : .secondary).frame(width: 44)

            // نسبة
            VStack(spacing: 2) {
                Text(emp.recorded > 0 ? String(format: "%.0f%%", emp.rate) : "—")
                    .font(.caption.bold()).foregroundColor(rateColor)
                // شريط صغير
                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#ecf0f1")).frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rateColor)
                            .frame(width: geo.size.width * CGFloat(emp.rate / 100), height: 4)
                    }
                }.frame(height: 4)
            }
            .frame(width: 50)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white).cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4)
        .padding(.horizontal)
    }
}

// ══════════════════════════════════════════════════════
//  MARK: - Share Sheet
// ══════════════════════════════════════════════════════
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
