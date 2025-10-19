//
//  ApplicationStatus.swift
//  Virvi
//
//  Created by Ethan Zhang on 4/10/2025.
//


import SwiftUI

enum ApplicationStatus: String, CaseIterable, Codable {
    case notApplied = "Not Applied"
    case applied = "Applied"
    case onlineAssessment = "Online Assessment"
    case interview = "Interview"
    case awaitingOffer = "Awaiting Offer"
    case offer = "Offer"
    case rejected = "Rejected"
    
    var color: Color {
        switch self {
        case .notApplied: return .gray
        case .applied: return .blue
        case .onlineAssessment: return .purple
        case .interview: return .orange
        case .awaitingOffer: return .orange.opacity(0.7)
        case .offer: return .green
        case .rejected: return .red
        }
    }
    
    var backgroundColor: Color {
        color.opacity(0.2)
    }
    
    func next() -> ApplicationStatus? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self),
              index < all.count - 1 else { return nil }
        return all[index + 1]
    }
    
    func previous() -> ApplicationStatus? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self),
              index > 0 else { return nil }
        return all[index - 1]
    }
}

enum StageType: String, CaseIterable, Codable {
    case applied = "Applied"
    case onlineAssessment = "Online Assessment"
    case virtualInterview = "Virtual Interview"
    case phoneScreening = "Phone Screening"
    case assessmentCentre = "Assessment Centre"
    case interview = "Interview"
    case awaitingOffer = "Awaiting Offer"
    case offer = "Offer"
    case rejected = "Rejected"
}

enum StageStatus: String, CaseIterable, Codable {
    case complete = "Complete"
    case inProgress = "In Progress"
    case rejected = "Rejected"
    case incomplete = "Incomplete"
    
    var icon: String {
        switch self {
        case .complete: return "checkmark.circle.fill"
        case .inProgress: return "clock.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .incomplete: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .complete: return .green
        case .inProgress: return .blue
        case .rejected: return .red
        case .incomplete: return .gray
        }
    }
}
