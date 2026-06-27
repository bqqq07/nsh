//
//  Loginview.swift
//  z NSH
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    @State private var code      = ""
    @State private var isLoading = false
    @State private var errorMsg  = ""
    @State private var showRegister = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1a1f3a"), Color(hex: "#2d3561")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    Text("نظام الموظفين")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("NSH · z-app.biz")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(2)
                }

                // Code field
                VStack(spacing: 14) {
                    glassField(icon: "lock.fill") {
                        SecureField("أدخل كود الدخول", text: $code)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.white)
                            .onChange(of: code) { _ in errorMsg = "" }
                            .placeholder(when: code.isEmpty) {
                                Text("أدخل كود الدخول")
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#e74c3c"))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Button {
                        Task { await doLogin() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("دخول")
                                    .font(.headline)
                                Image(systemName: "arrow.right.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#4f8ef7"))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading || code.isEmpty)
                }
                .padding(.horizontal, 32)

                // Register button
                Button {
                    showRegister = true
                } label: {
                    HStack(spacing: 6) {
                        Text("شركة جديدة؟")
                            .foregroundColor(.white.opacity(0.5))
                        Text("سجّل الآن")
                            .foregroundColor(Color(hex: "#4f8ef7"))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                Spacer()

                Text("Nasser S. Al-Hajri Corporation")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterCompanyView()
        }
    }

    // Glassmorphism field wrapper
    @ViewBuilder
    private func glassField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private func doLogin() async {
        isLoading = true
        errorMsg  = ""
        let savedDeviceToken = UserDefaults.standard.string(forKey: "apns_device_token")
        do {
            let resp = try await NetworkManager.shared.login(code: code, deviceToken: savedDeviceToken)
            await MainActor.run { session.save(token: resp.token, user: resp.user) }
            if let dt = savedDeviceToken {
                try? await NetworkManager.shared.registerDeviceToken(dt)
            }
        } catch {
            await MainActor.run {
                errorMsg = error.localizedDescription.isEmpty
                    ? "الكود غير صحيح أو تعذّر الاتصال"
                    : error.localizedDescription
            }
        }
        isLoading = false
    }
}

// ═══════════════════════════════════════════════════
//  MARK: - Register Company Sheet
// ═══════════════════════════════════════════════════

struct RegisterCompanyView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var confirm  = ""
    @State private var loading  = false
    @State private var success  = false
    @State private var error    = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.1)).frame(width: 72, height: 72)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 30)).foregroundColor(.blue)
                        }
                        Text("تسجيل شركة جديدة")
                            .font(.title2).fontWeight(.bold)
                        Text("سيتم مراجعة طلبك والموافقة عليه من قبل الإدارة")
                            .font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)

                    if success {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50)).foregroundColor(.green)
                            Text("تم إرسال طلبك بنجاح!")
                                .font(.headline).fontWeight(.bold)
                            Text("سيتم التواصل معك على البريد الإلكتروني بعد مراجعة الطلب")
                                .font(.caption).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("إغلاق") { dismiss() }
                                .padding(.top, 8)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            RegField(title: "اسم الشركة", placeholder: "اسم شركتك", text: $name)
                            RegField(title: "البريد الإلكتروني", placeholder: "admin@company.com", text: $email, keyboard: .emailAddress)
                            RegField(title: "كلمة المرور", placeholder: "كلمة مرور قوية", text: $password, secure: true)
                            RegField(title: "تأكيد كلمة المرور", placeholder: "أعد كلمة المرور", text: $confirm, secure: true)

                            if !error.isEmpty {
                                Text(error).foregroundColor(.red).font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await register() }
                            } label: {
                                HStack {
                                    if loading { ProgressView().tint(.white) }
                                    else { Text("إرسال الطلب").fontWeight(.bold) }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(formValid ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(!formValid || loading)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    var formValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirm
    }

    func register() async {
        loading = true; error = ""
        do {
            try await NetworkManager.shared.saCreateCompanyPublic(name: name, email: email, password: password)
            await MainActor.run { success = true }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        loading = false
    }
}

struct RegField: View {
    let title:       String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}
