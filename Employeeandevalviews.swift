import SwiftUI

// ══════════════════════════════════════════
//  MARK: - Models جديدة
// ══════════════════════════════════════════
struct AttendanceRecord: Identifiable {
    let id = UUID()
    var empId: Int
    var empNumber: String
    var name: String
    var department: String?
    var site: String?
    var status: String?
    var remarks: String
}


// ══════════════════════════════════════════
//  MARK: - قائمة الموظفين (مع إضافة وحذف)
// ══════════════════════════════════════════
struct EmployeeRow: View {
    let emp: Employee
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#4f8ef7").opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(emp.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(Color(hex: "#4f8ef7"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(emp.name)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text(emp.emp_number)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let dept = emp.department, !dept.isEmpty {
                        Text("• \(dept)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// ── ورقة إضافة موظف ──
struct AddEmployeeSheet: View {
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var empNumber  = ""
    @State private var name       = ""
    @State private var department = ""
    @State private var site       = ""
    @State private var isSaving   = false
    @State private var errorMsg   = ""

    func isEnglishOnly(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { $0.value < 128 }
    }

    var nameError: String? {
        if name.isEmpty { return nil }
        return isEnglishOnly(name) ? nil : "الاسم يجب أن يكون بالإنجليزية"
    }
    var deptError: String? {
        if department.isEmpty { return nil }
        return isEnglishOnly(department) ? nil : "القسم يجب أن يكون بالإنجليزية"
    }
    var siteError: String? {
        if site.isEmpty { return nil }
        return isEnglishOnly(site) ? nil : "الموقع يجب أن يكون بالإنجليزية"
    }
    var formValid: Bool {
        !empNumber.isEmpty && !name.isEmpty &&
        nameError == nil && deptError == nil && siteError == nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section("بيانات الموظف") {
                    HStack {
                        Text("رقم الموظف *")
                        Spacer()
                        TextField("أرقام فقط", text: $empNumber)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            Text("الاسم *")
                            Spacer()
                            TextField("English only", text: $name)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.words)
                                .onChange(of: name) { v in name = v.filter { $0.isASCII } }
                        }
                        if let e = nameError {
                            Text(e).font(.caption2).foregroundColor(.red)
                        }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            Text("القسم")
                            Spacer()
                            TextField("English only", text: $department)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.words)
                                .onChange(of: department) { v in department = v.filter { $0.isASCII } }
                        }
                        if let e = deptError {
                            Text(e).font(.caption2).foregroundColor(.red)
                        }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            Text("الموقع")
                            Spacer()
                            TextField("English only", text: $site)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.words)
                                .onChange(of: site) { v in site = v.filter { $0.isASCII } }
                        }
                        if let e = siteError {
                            Text(e).font(.caption2).foregroundColor(.red)
                        }
                    }
                }
                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("إضافة موظف")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { Task { await save() } }
                        .disabled(!formValid || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMsg = ""
        let body: [String: Any] = [
            "emp_number": empNumber, "name": name,
            "department": department, "site": site
        ]
        var req = NetworkManager.shared.makeRequest("/api/employees/add", method: "POST",
                      body: try? JSONSerialization.data(withJSONObject: body))
        let (_, response) = (try? await URLSession.shared.data(for: req)) ?? (Data(), nil)
        if (response as? HTTPURLResponse)?.statusCode == 201 {
            onSave()
            dismiss()
        } else {
            errorMsg = "حدث خطأ، تأكد من رقم الموظف"
        }
        isSaving = false
    }
}

// ══════════════════════════════════════════
//  MARK: - تفاصيل موظف + تقييماته
// ══════════════════════════════════════════
struct EmployeeDetailView: View {
    let employee: Employee
    @State private var showDailyEval  = false
    @State private var showWeeklyEval = false
    @State private var showNewRequest = false

    var body: some View {
        ZStack {
            Color(hex: "#f0f4ff").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#4f8ef7"), Color(hex: "#7b5ea7")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            Text(String(employee.name.prefix(1)))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(employee.name).font(.title2.bold())
                        HStack(spacing: 16) {
                            Label(employee.emp_number, systemImage: "number")
                            if let dept = employee.department, !dept.isEmpty {
                                Label(dept, systemImage: "building.2")
                            }
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ActionButton(title: "تقييم يومي", icon: "calendar.badge.plus", color: Color(hex: "#4f8ef7")) {
                            showDailyEval = true
                        }
                        ActionButton(title: "تقييم أسبوعي", icon: "chart.bar.fill", color: Color(hex: "#7b5ea7")) {
                            showWeeklyEval = true
                        }
                        ActionButton(title: "طلب جديد", icon: "doc.badge.plus", color: Color(hex: "#2ecc71")) {
                            showNewRequest = true
                        }
                        NavigationLink(destination: EmployeeReportsView(employee: employee)) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("التقارير").font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color(hex: "#f39c12").opacity(0.12))
                            .foregroundColor(Color(hex: "#f39c12"))
                            .cornerRadius(12)
                        }
                        NavigationLink(destination: AttendanceCalendarView(employee: employee)) {
                            HStack {
                                Image(systemName: "calendar")
                                Text("تقويم الحضور").font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color(hex: "#1abc9c").opacity(0.12))
                            .foregroundColor(Color(hex: "#1abc9c"))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDailyEval)  { DailyEvalFormView(employee: employee) }
        .sheet(isPresented: $showWeeklyEval) { WeeklyEvalFormView(employee: employee) }
        .sheet(isPresented: $showNewRequest) { NewRequestView(preselectedEmployee: employee, onDone: nil) }
    }
}

struct ActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title).font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(color.opacity(0.12)).foregroundColor(color).cornerRadius(12)
        }
    }
}

// ══════════════════════════════════════════
//  MARK: - التقييم اليومي
// ══════════════════════════════════════════
struct DailyEvalFormView: View {
    let employee: Employee
    @Environment(\.dismiss) var dismiss

    @State private var evalDate = Date()
    @State private var t1_text = ""; @State private var t1_pct: Double = 0
    @State private var t2_text = ""; @State private var t2_pct: Double = 0
    @State private var t3_text = ""; @State private var t3_pct: Double = 0
    @State private var t4_text = ""; @State private var t4_pct: Double = 0
    @State private var p_punctuality = 0;    @State private var p_quality = 0
    @State private var p_productivity = 0;   @State private var p_communication = 0
    @State private var p_problemsolving = 0; @State private var p_compliance = 0
    @State private var strengths = ""; @State private var improvements = ""; @State private var training = ""
    @State private var isSaving = false; @State private var errorMsg = ""; @State private var successMsg = ""

    var body: some View {
        NavigationView {
            Form {
                Section("التاريخ") {
                    DatePicker("تاريخ التقييم", selection: $evalDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ar_SA"))
                }
                Section("الأهداف (40 درجة)") {
                    TargetRow(label: "الهدف 1", text: $t1_text, percent: $t1_pct)
                    TargetRow(label: "الهدف 2", text: $t2_text, percent: $t2_pct)
                    TargetRow(label: "الهدف 3", text: $t3_text, percent: $t3_pct)
                    TargetRow(label: "الهدف 4", text: $t4_text, percent: $t4_pct)
                }
                Section("الأداء (60 درجة)") {
                    RatingRow(label: "الانضباط",    value: $p_punctuality)
                    RatingRow(label: "الجودة",      value: $p_quality)
                    RatingRow(label: "الإنتاجية",   value: $p_productivity)
                    RatingRow(label: "التواصل",     value: $p_communication)
                    RatingRow(label: "حل المشكلات", value: $p_problemsolving)
                    RatingRow(label: "الامتثال",    value: $p_compliance)
                }
                Section("ملاحظات") {
                    TextField("نقاط القوة",      text: $strengths,    axis: .vertical).lineLimit(2...4)
                    TextField("نقاط التحسين",    text: $improvements, axis: .vertical).lineLimit(2...4)
                    TextField("التدريب المطلوب", text: $training,     axis: .vertical).lineLimit(2...4)
                }
                if !errorMsg.isEmpty   { Text(errorMsg).foregroundColor(.red).font(.caption) }
                if !successMsg.isEmpty { Text(successMsg).foregroundColor(.green).font(.caption) }
            }
            .navigationTitle("تقييم يومي — \(employee.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { Task { await save() } }.disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true; errorMsg = ""; successMsg = ""
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let body: [String: Any] = [
            "employee_id": employee.id,
            "eval_date": df.string(from: evalDate),
            "t1_text": t1_text, "t1_percent": t1_pct,
            "t2_text": t2_text, "t2_percent": t2_pct,
            "t3_text": t3_text, "t3_percent": t3_pct,
            "t4_text": t4_text, "t4_percent": t4_pct,
            "p_punctuality": p_punctuality,   "p_quality": p_quality,
            "p_productivity": p_productivity, "p_communication": p_communication,
            "p_problemsolving": p_problemsolving, "p_compliance": p_compliance,
            "strengths": strengths, "improvements": improvements, "training_needed": training,
        ]
        if OfflineQueue.shared.isOnline {
            do {
                let req = NetworkManager.shared.makeRequest("/api/daily-eval/save", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
                let (data, response) = try await URLSession.shared.data(for: req)
                if (response as? HTTPURLResponse)?.statusCode == 201 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let total = json["total"] as? Double, let band = json["band"] as? String {
                        successMsg = "تم الحفظ ✓  المجموع: \(Int(total)) — \(band)"
                    } else { successMsg = "تم الحفظ ✓" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                } else if (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String == "Evaluation already exists for this date" {
                    errorMsg = "يوجد تقييم لهذا اليوم مسبقاً"
                } else {
                    // فشل — احفظ offline
                    OfflineQueue.shared.enqueue(type: .dailyEval, endpoint: "/api/daily-eval/save", payload: body)
                    successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            } catch {
                OfflineQueue.shared.enqueue(type: .dailyEval, endpoint: "/api/daily-eval/save", payload: body)
                successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        } else {
            OfflineQueue.shared.enqueue(type: .dailyEval, endpoint: "/api/daily-eval/save", payload: body)
            successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
        isSaving = false
    }
}

// ══════════════════════════════════════════
//  MARK: - TargetRow
// ══════════════════════════════════════════
struct TargetRow: View {
    let label: String
    @Binding var text: String
    @Binding var percent: Double

    // init لـ TargetData (يُستخدم في WeeklyEvalEditView)
    init(label: String, data: Binding<TargetData>) {
        self.label    = label
        self._text    = Binding(get: { data.wrappedValue.text }, set: { data.wrappedValue.text = $0 })
        self._percent = Binding(get: { data.wrappedValue.pct  }, set: { data.wrappedValue.pct  = $0 })
    }

    // init عادي
    init(label: String, text: Binding<String>, percent: Binding<Double>) {
        self.label    = label
        self._text    = text
        self._percent = percent
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField("وصف الهدف", text: $text)
                .multilineTextAlignment(.trailing)
            HStack {
                Text("\(Int(percent))%")
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: "#4f8ef7"))
                    .frame(width: 36)
                Slider(value: $percent, in: 0...100, step: 5)
                    .tint(Color(hex: "#4f8ef7"))
            }
        }
        .padding(.vertical, 4)
    }
}

// ══════════════════════════════════════════
//  MARK: - RatingRow (مُصلحة)
//  المشكلة القديمة: لمس أي نجمة يعطي 5 مباشرة
//  السبب: buttonStyle افتراضي يمدد مساحة الـ button
//  الحل: .buttonStyle(.plain) + frame ثابت لكل نجمة
// ══════════════════════════════════════════
struct RatingRow: View {
    let label: String
    @Binding var value: Int   // 0–5

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        Button {
                            value = (value == star) ? 0 : star
                        } label: {
                            Image(systemName: star <= value ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(star <= value ? Color(hex: "#f39c12") : Color(.systemGray4))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                Text(label).font(.subheadline)
            }
            if value > 0 {
                Text(["", "ضعيف", "مقبول", "جيد", "جيد جداً", "ممتاز"][value])
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

// ══════════════════════════════════════════
//  MARK: - التقييم الأسبوعي
// ══════════════════════════════════════════
struct WeeklyEvalFormView: View {
    let employee: Employee
    @Environment(\.dismiss) var dismiss

    @State private var weekStart = Date().previousSunday
    @State private var t1_text = ""; @State private var t1_pct: Double = 0
    @State private var t2_text = ""; @State private var t2_pct: Double = 0
    @State private var t3_text = ""; @State private var t3_pct: Double = 0
    @State private var t4_text = ""; @State private var t4_pct: Double = 0
    @State private var p_punctuality = 0;    @State private var p_quality = 0
    @State private var p_productivity = 0;   @State private var p_communication = 0
    @State private var p_problemsolving = 0; @State private var p_compliance = 0
    @State private var strengths = ""; @State private var improvements = ""; @State private var training = ""
    @State private var isSaving = false; @State private var errorMsg = ""; @State private var successMsg = ""

    var weekEnd: Date { Calendar.current.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart }

    var body: some View {
        NavigationView {
            Form {
                Section("أسبوع التقييم (أحد → خميس)") {
                    DatePicker("بداية الأسبوع (أحد)", selection: $weekStart, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ar_SA"))
                    HStack {
                        Spacer()
                        Text("نهاية الأسبوع: \(weekEnd.iso)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("الأهداف (40 درجة)") {
                    TargetRow(label: "الهدف 1", text: $t1_text, percent: $t1_pct)
                    TargetRow(label: "الهدف 2", text: $t2_text, percent: $t2_pct)
                    TargetRow(label: "الهدف 3", text: $t3_text, percent: $t3_pct)
                    TargetRow(label: "الهدف 4", text: $t4_text, percent: $t4_pct)
                }
                Section("الأداء (60 درجة)") {
                    RatingRow(label: "الانضباط",    value: $p_punctuality)
                    RatingRow(label: "الجودة",      value: $p_quality)
                    RatingRow(label: "الإنتاجية",   value: $p_productivity)
                    RatingRow(label: "التواصل",     value: $p_communication)
                    RatingRow(label: "حل المشكلات", value: $p_problemsolving)
                    RatingRow(label: "الامتثال",    value: $p_compliance)
                }
                Section("ملاحظات") {
                    TextField("نقاط القوة",      text: $strengths,    axis: .vertical).lineLimit(2...4)
                    TextField("نقاط التحسين",    text: $improvements, axis: .vertical).lineLimit(2...4)
                    TextField("التدريب المطلوب", text: $training,     axis: .vertical).lineLimit(2...4)
                }
                if !errorMsg.isEmpty   { Text(errorMsg).foregroundColor(.red).font(.caption) }
                if !successMsg.isEmpty { Text(successMsg).foregroundColor(.green).font(.caption) }
            }
            .navigationTitle("تقييم أسبوعي — \(employee.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { Task { await save() } }.disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true; errorMsg = ""; successMsg = ""
        let body: [String: Any] = [
            "employee_id": employee.id,
            "week_start": weekStart.iso, "week_end": weekEnd.iso,
            "t1_text": t1_text, "t1_percent": t1_pct,
            "t2_text": t2_text, "t2_percent": t2_pct,
            "t3_text": t3_text, "t3_percent": t3_pct,
            "t4_text": t4_text, "t4_percent": t4_pct,
            "p_punctuality": p_punctuality,   "p_quality": p_quality,
            "p_productivity": p_productivity, "p_communication": p_communication,
            "p_problemsolving": p_problemsolving, "p_compliance": p_compliance,
            "strengths": strengths, "improvements": improvements, "training_needed": training,
        ]
        if OfflineQueue.shared.isOnline {
            do {
                let req = NetworkManager.shared.makeRequest("/api/weekly-eval/save", method: "POST",
                              body: try JSONSerialization.data(withJSONObject: body))
                let (data, response) = try await URLSession.shared.data(for: req)
                if (response as? HTTPURLResponse)?.statusCode == 201 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let total = json["total"] as? Double, let band = json["band"] as? String {
                        successMsg = "تم الحفظ ✓  المجموع: \(Int(total)) — \(band)"
                    } else { successMsg = "تم الحفظ ✓" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                } else {
                    OfflineQueue.shared.enqueue(type: .weeklyEval, endpoint: "/api/weekly-eval/save", payload: body)
                    successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            } catch {
                OfflineQueue.shared.enqueue(type: .weeklyEval, endpoint: "/api/weekly-eval/save", payload: body)
                successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        } else {
            OfflineQueue.shared.enqueue(type: .weeklyEval, endpoint: "/api/weekly-eval/save", payload: body)
            successMsg = "حُفظ محلياً ⏳ — سيُرسل عند الاتصال"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
        isSaving = false
    }
}

// ══════════════════════════════════════════
//  MARK: - تقارير الموظف
// ══════════════════════════════════════════
struct EmployeeReportsView: View {
    let employee: Employee
    @State private var weeklyReports: [EvalReport] = []
    @State private var dailyReports:  [EvalReport] = []
    @State private var isLoading  = true
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color(hex: "#f0f4ff").ignoresSafeArea()
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("أسبوعي").tag(0)
                    Text("يومي").tag(1)
                }
                .pickerStyle(.segmented).padding()

                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else {
                    let currentReports = selectedTab == 0 ? weeklyReports : dailyReports
                    if currentReports.isEmpty {
                        Spacer()
                        Text("لا توجد تقارير بعد").foregroundColor(.secondary)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                AverageReportCard(reports: currentReports)
                                LazyVStack(spacing: 10) {
                                    ForEach(currentReports) { r in
                                        EvalReportCard(report: r)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("تقارير \(employee.name)")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            async let weekly = NetworkManager.shared.getEmployeeWeeklyReports(empId: employee.id)
            async let daily  = NetworkManager.shared.getEmployeeDailyReports(empId: employee.id)
            weeklyReports = try await weekly
            dailyReports  = try await daily
        } catch {
            weeklyReports = []; dailyReports = []
        }
        isLoading = false
    }
}

struct AverageReportCard: View {
    let reports: [EvalReport]

    private var average: Double {
        guard !reports.isEmpty else { return 0 }
        let total = reports.reduce(0.0) { $0 + ($1.total ?? 0) }
        return total / Double(reports.count)
    }

    private var averageColor: Color {
        if average >= 90 { return .green }
        if average >= 80 { return .blue }
        if average >= 70 { return .orange }
        return .red
    }

    var body: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 4) {
                Text("متوسط كل التقارير").font(.caption).foregroundColor(.secondary)
                Text("من \(reports.count) تقرير").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "%.1f", average))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(averageColor)
        }
        .padding().background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct EvalReportCard: View {
    let report: EvalReport
    var body: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 6) {
                Text(report.eval_date ?? "\(report.week_start ?? "") → \(report.week_end ?? "")")
                    .font(.caption).foregroundColor(.secondary)
                HStack(spacing: 12) {
                    StatBadge(label: "الأهداف", value: report.targets ?? 0, max: 40)
                    StatBadge(label: "الأداء",  value: report.perf    ?? 0, max: 60)
                }
            }
            Spacer()
            VStack(spacing: 4) {
                Text("\(Int(report.total ?? 0))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(report.bandColor)
                Text(report.band ?? "—")
                    .font(.caption.bold()).foregroundColor(report.bandColor)
            }
        }
        .padding().background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct StatBadge: View {
    let label: String; let value: Double; let max: Double
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))/\(Int(max))").font(.caption.bold()).foregroundColor(Color(hex: "#1a1f3a"))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// ══════════════════════════════════════════
//  MARK: - الحضور اليومي
// ══════════════════════════════════════════
struct AttendanceRowView: View {
    @Binding var record: AttendanceRecord
    let statuses: [(String, String)]

    var statusColor: Color {
        switch record.status {
        case "present": return Color(hex: "#2ecc71")
        case "absent":  return Color(hex: "#e74c3c")
        case "leave":   return Color(hex: "#f39c12")
        default:        return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name).font(.subheadline.bold())
                Text(record.empNumber).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { record.status ?? "" },
                set: { record.status = $0 }
            )) {
                Text("—").tag("")
                ForEach(statuses, id: \.0) { val, label in
                    Text(label).tag(val)
                }
            }
            .pickerStyle(.menu).tint(statusColor)
        }
        .padding(.vertical, 4)
    }
}
