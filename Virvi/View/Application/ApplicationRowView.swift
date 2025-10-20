//
//  ApplicationRowView.swift
//  Virvi
//

import SwiftUI

struct ApplicationRowView: View {
    @ObservedObject var viewModel: ApplicationsListViewModel
    let applicationWithStages: ApplicationWithStages
    
    @State private var dragOffset = CGSize.zero
    @State private var isLongPressing = false
    @State private var previewStatus: ApplicationStatus? = nil
    @State private var isDragging = false
    
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
                        
                        Button(action: {
                            Task {
                                await viewModel.toggleStar(applicationWithStages.application)
                            }
                        }) {
                            Image(systemName: applicationWithStages.application.starred ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(applicationWithStages.application.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        StatusBadge(status: previewStatus ?? applicationWithStages.application.status)
                            .opacity(isDragging ? 0.7 : 1.0)
                        
                        Spacer()
                        
                        Text(applicationWithStages.application.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
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
            
            .onTapGesture {
                if !isLongPressing && !isDragging {
                    viewModel.toggleExpansion(for: applicationWithStages.id)
                }
            }
            
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLongPressing = true
                }
            } onPressingChanged: { isPressing in
                if !isPressing {
                    if !isDragging {
                        withAnimation {
                            isLongPressing = false
                        }
                    }
                }
            }
            
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard isLongPressing else { return }
                        isDragging = true
                        dragOffset = value.translation
                        
                        let dragDistance = value.translation.width
                        
                        if dragDistance > 80 {
                            previewStatus = viewModel.getNextStatus(current: applicationWithStages.application.status)
                        } else if dragDistance < -80 {
                            previewStatus = viewModel.getPreviousStatus(current: applicationWithStages.application.status)
                        } else {
                            previewStatus = nil
                        }
                    }
                    .onEnded { value in
                        guard isLongPressing else { return }
                        
                        let dragDistance = value.translation.width
                        
                        if abs(dragDistance) > 80 {
                            let newStatus: ApplicationStatus
                            if dragDistance > 0 {
                                newStatus = viewModel.getNextStatus(current: applicationWithStages.application.status)
                            } else {
                                newStatus = viewModel.getPreviousStatus(current: applicationWithStages.application.status)
                            }
                            
                            Task {
                                await viewModel.updateStatus(
                                    application: applicationWithStages.application,
                                    to: newStatus
                                )
                            }
                        }
                        
                        dragOffset = .zero
                        isLongPressing = false
                        isDragging = false
                        previewStatus = nil
                    }
            )
            
            // MARK: - Drag Guide Overlay
            
            if isLongPressing {
                HStack {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.secondary)
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
}
