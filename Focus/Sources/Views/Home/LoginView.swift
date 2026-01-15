//
//  LoginView.swift
//  Focus
//
//  Simple login screen
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                
                Text("Project Next")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Stay focused. Get things done.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
            
            // Form
            VStack(spacing: 16) {
                // Email
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(.plain)
                            .textContentType(.emailAddress)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Password
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        if showPassword {
                            TextField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                        }
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Error
                if let error = authManager.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Sign In
                Button {
                    login()
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer
            Text("Syncs with your Focus web account")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    private func login() {
        Task {
            await authManager.login(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
