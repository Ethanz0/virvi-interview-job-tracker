//
//  ApplicationRowView.swift
//  Virvi
//
//  Created by Ethan Zhang on 4/10/2025.
//

import SwiftUI
import FirebaseFirestore
// MARK: - Application Row View
/// This view is a reuseable for ``ApplicationsListView`` to display each of its ``Application``
/// Takes a single ``ApplicationWithStages`` to display
struct ApplicationRowView: View {
    // Observed obj because main view is ApplicationListview
    @ObservedObject var viewModel: ApplicationsListViewModel
    
    /// Environment Object for tracking ids to save application changes to
    @EnvironmentObject var auth: AuthViewModel
    
    let applicationWithStages: ApplicationWithStages
    
    // Gesture state variables
    @State private var dragOffset = CGSize.zero
    @State private var isLongPressing = false
    @State private var previewStatus: ApplicationStatus? = nil
    @State private var isDragging = false
    
    /// Boolean for whether user has clicked on the row and to display ``StageTimelineView``
    var isExpanded: Bool {
        viewModel.expandedApplicationId == applicationWithStages.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Company and star toggle button
                    HStack {
                        Text(applicationWithStages.application.company)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        // Star toggle button
                        Button(action: {
                            Task {
                                await viewModel.toggleStar(
                                    applicationId: applicationWithStages.id ?? "",
                                    userId: auth.user?.id ?? ""
                                )
                            }
                        }) {
                            // Logic to display filled or unfilled star sf symbol
                            Image(systemName: applicationWithStages.application.starred ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    // Application Role
                    Text(applicationWithStages.application.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Application Status badge view, and the date of application
                    HStack {
                        StatusBadge(status: previewStatus ?? applicationWithStages.application.status)
                            .opacity(isDragging ? 0.7 : 1.0)
                        
                        Spacer()
                        
                        Text(formatDate(applicationWithStages.application.date))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                // Dropdown arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
            .animation(.none, value: viewModel.expandedApplicationId)
            
            // MARK: - Custom Gesture
            .offset(x: dragOffset.width * 0.3, y: 0)
            .scaleEffect(isLongPressing ? 1.02 : 1.0)
            .shadow(color: isLongPressing ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            
            // Open drop down on tap
            .onTapGesture {
                // Only toggle expansion if not in custom gesture mode
                if !isLongPressing && !isDragging {
                    viewModel.toggleExpansion(for: applicationWithStages.id)
                }
            }
            
            // Only activate after 0.5s of long press gesture
            // Ensures users doesnt accidentally change status
            // Allows for UI change (drag to change status) text
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLongPressing = true
                }
            // When user stops pressing, set isLongPressing var to false
            } onPressingChanged: { isPressing in
                if !isPressing {
                    if !isDragging {
                        withAnimation {
                            isLongPressing = false
                        }
                    }
                }
            }
            
            // Simultaneous Gesture to track drag gesture
            .simultaneousGesture(
                // Ensure user drags a bit before registering
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Ensure the user has first long pressed, otherwise return
                        guard isLongPressing else { return }
                        // UI change bool
                        isDragging = true
                        // Update drag translation
                        dragOffset = value.translation
                        
                        // Update drag distance by its width
                        let dragDistance = value.translation.width
                        
                        // If user drags to right, update previewStatus (used in StatusBadge view) to next status
                        if dragDistance > 80 {
                            previewStatus = viewModel.getNextStatus(current: applicationWithStages.application.status)
                        } else if dragDistance < -80 {
                            // If user drags to left, update previewStatus (used in StatusBadge view) to previous status
                            previewStatus = viewModel.getPreviousStatus(current: applicationWithStages.application.status)
                        } else {
                            previewStatus = nil
                        }
                    }
                    // User has stopped dragging
                    .onEnded { value in
                        guard isLongPressing else { return }
                        
                        // Check drag distance for final logic of updated status
                        let dragDistance = value.translation.width
                        
                        // Apply status change if dragged far enough
                        if abs(dragDistance) > 80 {
                            let newStatus: ApplicationStatus
                            if dragDistance > 0 {
                                newStatus = viewModel.getNextStatus(current: applicationWithStages.application.status)
                            } else {
                                newStatus = viewModel.getPreviousStatus(current: applicationWithStages.application.status)
                            }
                            
                            // Update status in Firestore
                            Task {
                                await viewModel.updateStatus(
                                    applicationId: applicationWithStages.id ?? "",
                                    to: newStatus,
                                    userId: auth.user?.id ?? ""
                                )
                            }
                        }
                        
                        // Reset state
                        dragOffset = .zero
                        isLongPressing = false
                        isDragging = false
                        previewStatus = nil
                    }
            )
            
            // MARK: - Drag Guide Overlay
            // If user is long pressing display helpful information on how to use gesture
            if isLongPressing {
                HStack {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.secondary)
                    // Once user starts dragging, update text to instruct how to apply changes
                    Text(isDragging ? "Release to apply" : "Drag to change status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .transition(.opacity)
            }
            
            // MARK: - Expanded Dropdown Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Note section
                    if !applicationWithStages.application.note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(applicationWithStages.application.note)
                                .font(.footnote)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Stage Timeline View
                    if !applicationWithStages.stages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Application Progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                            
                            StageTimelineView(stages: applicationWithStages.stages)
                        }
                    }
                    
                    // Edit Button
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.selectedApplicationToEdit = applicationWithStages
                        }) {
                            Label("Edit", systemImage: "pencil")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard let date = dateString.toDate() else { return dateString }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
