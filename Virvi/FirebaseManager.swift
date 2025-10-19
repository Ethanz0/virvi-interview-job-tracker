//
//  FirebaseManager.swift
//  Virvi
//
//  Created by Ethan Zhang on 2/10/2025.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
final class FirebaseManager {
    static let shared = FirebaseManager()
    private init() {}
    let auth = Auth.auth()
    let db = Firestore.firestore()
}
