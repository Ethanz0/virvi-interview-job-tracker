//
//  GoogleSignInButton.swift
//  Virvi
//
//  Created by Ethan Zhang on 23/10/2025.
//


import SwiftUI

struct GoogleSignInButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image("google_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 35, height: 35)
                
                Text("Sign in with Google")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.26, green: 0.26, blue: 0.26))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.87, green: 0.87, blue: 0.87), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}


