//
//  LogoCustomLayout.swift
//  Virvi
//
//  Created by Ethan Zhang on 26/8/2025.
//
import SwiftUI

/// Virvi Custom Layout for logo
struct VirviLogoLayout: Layout {
    var padding: CGFloat = 20 // Configurable padding
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let side = min(proposal.width ?? 200, proposal.height ?? 200)
        return CGSize(width: side, height: side)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Expect at least the V and top symbol
        guard subviews.count >= 2 else { return }
        
        var index = 0
        
        // Outer shape is optional
        if subviews.count == 3 {
            let outer = subviews[index]
            outer.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(bounds.size)
            )
            index += 1
        }
        
        let vShape = subviews[index]
        let topSymbol = subviews[index + 1]
        
        let innerBounds = CGRect(
            x: bounds.minX + padding,
            y: bounds.minY + padding,
            width: bounds.width - (padding * 2),
            height: bounds.height - (padding * 2)
        )
        
        // vshape
        let vSize = CGSize(width: innerBounds.width * 0.65, height: innerBounds.height * 0.65)
        let vRect = CGRect(
            x: innerBounds.midX - vSize.width / 2 - innerBounds.width * 0.02,
            y: innerBounds.midY - vSize.height / 2,
            width: vSize.width,
            height: vSize.height
        )
        vShape.place(
            at: vRect.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(vRect.size)
        )
        
        // inner shape (top symbol)
        let topSize = CGSize(width: innerBounds.width * 0.1, height: innerBounds.height * 0.1)
        let topRect = CGRect(
            x: innerBounds.midX - topSize.width / 6,
            y: innerBounds.minY + innerBounds.height * 0.2 + topSize.height / 4,
            width: topSize.width,
            height: topSize.height
        )
        topSymbol.place(
            at: topRect.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(topRect.size)
        )
    }
}
#Preview {
    VStack{
        VirviLogoLayout(padding: 20) {
                        Circle()
                            .fill(Color.black)
            
            LogoSymbol()
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            RoundedRectangle(cornerRadius: 1)
                .stroke(.white, style: StrokeStyle(lineWidth: 5.5))
                .rotationEffect(.degrees(45))
                .aspectRatio(1, contentMode: .fit)
        }
        .frame(width: 200, height: 200)
        VirviLogoLayout(padding: 20) {
            //            Circle()
            //                .fill(Color.black)
            
            LogoSymbol()
                .stroke(.black, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            RoundedRectangle(cornerRadius: 1)
                .stroke(.black, style: StrokeStyle(lineWidth: 5.5))
                .rotationEffect(.degrees(45))
                .aspectRatio(1, contentMode: .fit)
        }
        .frame(width: 200, height: 200)
//        .border(Color.blue, width: 3) // simple border

        
    }
}
