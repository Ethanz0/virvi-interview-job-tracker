//
//  StageTimelineView.swift
//  Virvi
//
//  Created by Ethan Zhang on 3/10/2025.
//


import SwiftUI

// MARK: - Stage Timeline View

/// This view is used for ``ApplicationRowView`` to display its list of ``ApplicationStage`` in a progress bar style
struct StageTimelineView: View {
    /// List of stages to display
    let stages: [ApplicationStage]
    
    var body: some View {
        VStack(spacing: 0) {
            // Sort stages by sortOrder attribute
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
                                // change how long rectangle is
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
                        // Stage
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

    
//    private func formatStageDate(_ dateString: String) -> String {
//        guard let date = dateString.toDate() else { return dateString }
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MMM d"
//        return formatter.string(from: date)
//    }
}

// MARK: - Preview

//#Preview {
//    let mockStages = [
//        ApplicationStage(
//            id: "s1",
//            stage: StageType.applied,
//            status: StageStatus.complete,
//            date: "2024-09-01",
//            note: "Application submitted online",
//            sortOrder: 0
//        ),
//        ApplicationStage(
//            id: "s2",
//            stage: StageType.phoneScreening,
//            status: StageStatus.complete,
//            date: "2024-09-05",
//            note: "30 min call with recruiter",
//            sortOrder: 1
//        ),
//        ApplicationStage(
//            id: "s3",
//            stage: StageType.interview,
//            status: StageStatus.inProgress,
//            date: "2024-09-15",
//            note: "Coming up this week",
//            sortOrder: 2
//        ),
//        ApplicationStage(
//            id: "s4",
//            stage: StageType.awaitingOffer,
//            status: StageStatus.incomplete,
//            date: "2024-09-20",
//            note: "",
//            sortOrder: 3
//        )
//    ]
//    
//    StageTimelineView(stages: mockStages)
//}
