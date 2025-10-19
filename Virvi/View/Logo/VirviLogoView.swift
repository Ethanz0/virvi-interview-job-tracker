//
//  LogoView.swift
//  Virvi
//
//  Created by Ethan Zhang on 26/8/2025.
//

import Foundation
import SwiftUI

/// This view uses ``LogoSymbol`` and ``VirviLogoLayout`` to create the logo view
struct VirviLogoView: View {
    var body: some View {
        // Custom padding
        VirviLogoLayout(padding: 20) {
            Circle()
                .fill(Color.black)
            
            LogoSymbol()
                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            RoundedRectangle(cornerRadius: 1)
                .stroke(.white, style: StrokeStyle(lineWidth: 5.5))
                .rotationEffect(.degrees(45))
                .aspectRatio(1, contentMode: .fit)
        }

    }
}

#Preview {
    VirviLogoView()
        .frame(width: 200, height: 200)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        .ignoresSafeArea()
}
