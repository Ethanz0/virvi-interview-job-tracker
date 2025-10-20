//
//  StageTimelineView.swift
//  Virvi
//

import SwiftUI

struct StageTimelineView: View {
    let stages: [SDApplicationStage]
    
    var body: some View {
        VStack(spacing: 0) {
            let sortedStages = stages.sorted(by: { $0.sortOrder < $1.sortOrder })
            
            ForEach(Array(sortedStages.enumerated()), id: \.element.id) { index, stage in
                HStack(alignment: .top, spacing: 12) {
                    // MARK: - Progress Bar
                    VStack(spacing: 0) {
                        Image(systemName: stage.status.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(stage.status.color)
                        
                        if index < sortedStages.count - 1 {
                            let nextStageColor = sortedStages[index + 1].status.color
                            Rectangle()
                                .fill(nextStageColor)
                                .frame(width: 2, height: 46)
                        }
                    }
                    
                    // MARK: - Stage Details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stage.stage.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            Text(stage.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(stage.status.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !stage.note.isEmpty {
                            Text(stage.note)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.bottom, index < sortedStages.count - 1 ? 8 : 0)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
