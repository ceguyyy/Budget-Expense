//
//  AppleSignInManager.swift
//  Budget Expense
//

import SwiftUI
import AuthenticationServices
import Observation

@MainActor
@Observable
class AppleSignInManager {
    var isSignedIn = false
    var userDisplayName: String?
    var userEmail: String?
    var userId: String?
    var errorMessage: String?
    
    private let userIdKey = "apple_signin_user_id"
    private let userNameKey = "apple_signin_user_name"
    private let userEmailKey = "apple_signin_user_email"
    
    init() {
        loadUserData()
        checkCurrentSignInStatus()
    }
    
    // MARK: - Load Saved User Data
    
    private func loadUserData() {
        userId = UserDefaults.standard.string(forKey: userIdKey)
        userDisplayName = UserDefaults.standard.string(forKey: userNameKey)
        userEmail = UserDefaults.standard.string(forKey: userEmailKey)
        isSignedIn = userId != nil
    }
    
    // MARK: - Save User Data
    
    private func saveUserData() {
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }
        if let name = userDisplayName {
            UserDefaults.standard.set(name, forKey: userNameKey)
        }
        if let email = userEmail {
            UserDefaults.standard.set(email, forKey: userEmailKey)
        }
    }
    
    // MARK: - Check Current Status
    
    func checkCurrentSignInStatus() {
        guard let userId = userId else {
            isSignedIn = false
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { state, error in
            Task { @MainActor in
                switch state {
                case .authorized:
                    self.isSignedIn = true
                case .revoked, .notFound:
                    self.signOut()
                case .transferred:
                    // Handle transferred accounts
                    self.isSignedIn = true
                @unknown default:
                    self.signOut()
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            print("✅ Sign in with Apple succeeded!")
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                userId = credential.user
                print("📝 User ID: \(credential.user)")
                
                // Full name is only provided on first sign in
                if let fullName = credential.fullName {
                    let firstName = fullName.givenName ?? ""
                    let lastName = fullName.familyName ?? ""
                    userDisplayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    
                    // If name is empty, use a default
                    if userDisplayName?.isEmpty ?? true {
                        userDisplayName = "User"
                    }
                    print("👤 User name: \(userDisplayName ?? "nil")")
                }
                
                // Email might be provided or hidden
                if let email = credential.email {
                    userEmail = email
                    print("📧 Email: \(email)")
                }
                
                isSignedIn = true
                saveUserData()
                errorMessage = nil
                print("✅ Sign in complete!")
            }
            
        case .failure(let error):
            print("❌ Sign in with Apple failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSignedIn = false
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        userId = nil
        userDisplayName = nil
        userEmail = nil
        isSignedIn = false
        
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }
    
    // MARK: - Get Display Name
    
    func getDisplayName() -> String {
        return userDisplayName ?? "User"
    }
    
    func updateEmail(_ email: String) {
        self.userEmail = email
        UserDefaults.standard.set(email, forKey: userEmailKey)
    }
}

// MARK: - Environment Key

struct AppleSignInManagerKey: EnvironmentKey {
    static let defaultValue = AppleSignInManager()
}

extension EnvironmentValues {
    var appleSignInManager: AppleSignInManager {
        get { self[AppleSignInManagerKey.self] }
        set { self[AppleSignInManagerKey.self] = newValue }
    }
}

// MARK: - Sign In with Apple Button View

struct SignInWithAppleButton: View {
    @Environment(\.appleSignInManager) private var signInManager
    @Environment(\.colorScheme) private var colorScheme
    
    let onSuccess: () -> Void
    
    var body: some View {
        SignInWithAppleButtonRepresentable(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                signInManager.handleSignInResult(result)
                if case .success = result {
                    onSuccess()
                }
            }
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
    }
}

// MARK: - UIViewRepresentable for Sign In Button

struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .white
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleSignIn),
            for: .touchUpInside
        )
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
        
        @objc func handleSignIn() {
            print("🔵 Sign in with Apple button tapped")
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            onRequest(request)
            
            print("🔵 Creating authorization controller...")
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
            print("🔵 Performing sign in request...")
        }
        
        func authorizationController(controller: ASAuthorizationController,
                                    didCompleteWithAuthorization authorization: ASAuthorization) {
            print("✅ Authorization successful!")
            onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController,
                                    didCompleteWithError error: Error) {
            print("❌ Authorization failed: \(error.localizedDescription)")
            onCompletion(.failure(error))
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                return UIWindow()
            }
            return window
        }
    }
}
