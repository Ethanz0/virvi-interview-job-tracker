//
//  Logo.swift
//  Virvi
//
//  Created by Ethan Zhang on 26/8/2025.
//
import SwiftUI

/// This struct creates the Inner virvi logo shape
struct LogoSymbol: Shape {
    //create logo by first defining key points, then drawing a path between them
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX - rect.width*0.05, y: rect.minY + rect.height * 0.19 )
        let bottomLeft = CGPoint(x: rect.minX + rect.width * 0.45, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.maxY)
        let midRight = CGPoint(
            x: (topRight.x + bottomLeft.x) / 2.2,
            y: (topRight.y + bottomLeft.y) / 1.8
        )
        
        path.move(to: midRight)
        path.addLine(to: topLeft)
        path.addLine(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.addLine(to: topRight)
        path.addLine(to: bottomLeft)
        
        return path
    }
}

#Preview {
    LogoSymbol()
        .stroke(.black, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)).frame(width: 200, height: 200)
    
}
