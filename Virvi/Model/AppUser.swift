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
        let first = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return AppUser(id: user.uid, firstName: first, email: user.email ?? "")
    }
}
