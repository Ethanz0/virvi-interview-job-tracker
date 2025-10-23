//
//  AppUser.swift
//  Virvi
//
//  Created by Ethan Zhang on 2/10/2025.
//

import Foundation
import FirebaseAuth

struct AppUser: Identifiable, Equatable {
    let id: String
    let firstName: String
    let email: String
    
    init(id: String, firstName: String, email: String) {
        self.id = id
        self.firstName = firstName
        self.email = email
    }
    
    static func fromFirebaseUser(_ user: User) -> AppUser {
        let displayName = user.displayName ?? ""
        let email = user.email ?? ""
        
        // Extract first name from display name
        var first = ""
        if !displayName.isEmpty {
            first = displayName.split(separator: " ").first.map(String.init) ?? displayName
        }
        
        // If firstName is empty and we have an email, try to extract a name
        if first.isEmpty && !email.isEmpty {
            // For Apple's obfuscated emails, just use a generic name
            if email.contains("privaterelay.appleid.com") {
                first = "User"
            } else {
                // For regular emails, try to extract name from email
                let emailPrefix = email.components(separatedBy: "@").first ?? ""
                if !emailPrefix.isEmpty {
                    // Capitalize first letter and remove numbers/special chars
                    let cleaned = emailPrefix.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
                    if !cleaned.isEmpty {
                        first = cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
                    }
                }
            }
        }
        
        return AppUser(
            id: user.uid,
            firstName: first.isEmpty ? "User" : first,
            email: email
        )
    }
}

// MARK: - Display Helpers

extension AppUser {
    /// The name to display in the UI
    var displayName: String {
        // If we have a proper first name (not the email), use it
        if !firstName.isEmpty && firstName != "User" && firstName != email {
            return firstName
        }
        
        // For Apple's obfuscated emails, just show "User"
        if email.contains("privaterelay.appleid.com") {
            return "User"
        }
        
        // For regular emails, try to extract a readable name
        if !email.isEmpty {
            let prefix = email.components(separatedBy: "@").first ?? ""
            if !prefix.isEmpty && prefix.count < 20 {
                return prefix
            }
        }
        
        return "User"
    }
    
    /// The initial to display in the profile circle
    var displayInitial: String {
        let name = displayName
        return String(name.prefix(1).uppercased())
    }
    
    /// Whether the email should be shown in the UI
    var shouldShowEmail: Bool {
        // Don't show obfuscated Apple emails
        if email.contains("privaterelay.appleid.com") {
            return false
        }
        // Show email if it's different from display name
        return email != displayName && !email.isEmpty
    }
}
