//
//  SignInWithAppleButton.swift
//  Virvi
//
//  Created by Ethan Zhang on 23/10/2025.
//


//
//  SignInWithAppleButton.swift
//  Virvi
//
//  Created by Ethan Zhang on 23/10/2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignInWithAppleButton: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        SignInWithAppleButtonRepresentable(
            onRequest: { request in
                // Generate and hash nonce
                let nonce = (auth.authService as? AuthService)?.generateNonce() ?? ""
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            },
            onCompletion: { result in
                switch result {
                case .success(let authorization):
                    auth.signInWithApple(authorization: authorization)
                case .failure(let error):
                    auth.errorMessage = error.localizedDescription
                }
            }
        )
        .frame(height: 50)
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// UIViewRepresentable wrapper for ASAuthorizationAppleIDButton
struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton()
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleButtonPress), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onRequest: onRequest, onCompletion: onCompletion)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void
        
        init(onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
             onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onRequest = onRequest
            self.onCompletion = onCompletion
        }
        
        @objc func handleButtonPress() {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            onRequest(request)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onCompletion(.failure(error))
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                fatalError("No key window found")
            }
            return window
        }
    }
}

