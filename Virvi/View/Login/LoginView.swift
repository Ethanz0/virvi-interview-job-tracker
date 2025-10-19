
import SwiftUI

/// This View the the screen for not authenticated users, they can log in with google
struct LoginView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onSignIn: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.7), .indigo.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App logo
                VirviLogoView()
                    .frame(width: 150, height: 200)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Virvi")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                    
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 40)
                }
                
                
                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "mic.fill", text: "Practice with realistic interviews")
                    FeatureRow(icon: "brain.head.profile", text: "Get AI-powered feedback")
                    FeatureRow(icon: "briefcase.fill", text: "Track your job applications")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
                
                // Sign in button
                VStack(spacing: 16) {
                    Button(action: onSignIn) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.blue)
                            } else {
                                Image(systemName: "globe")
                                    .font(.title3)
                            }
                            
                            Text(isLoading ? "Signing in..." : "Continue with Google")
                                .font(.headline)
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}

/// Reusable view for features used for ``LoginView``
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

#Preview {
    LoginView(
        isLoading: false,
        errorMessage: nil,
        onSignIn: { print("Sign in tapped") }
    )
}

