//
//  SimpleAppCheckProviderFactory.swift
//  Virvi
//
//  Created by Ethan Zhang on 23/10/2025.
//


import Foundation
import FirebaseCore
import FirebaseAppCheck

class SimpleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}
