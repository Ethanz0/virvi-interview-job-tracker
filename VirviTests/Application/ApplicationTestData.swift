//
//  ApplicationTestData.swift
//  Virvi
//
//  Created by Ethan Zhang on 11/10/2025.
//


import Foundation
import FirebaseFirestore
import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - Test Data for Applications

enum ApplicationTestData {
    
    // MARK: - Applications

    static var appliedApplication: Application {
        Application(
            id: "test-app-1",
            role: "Software Engineer",
            company: "Apple",
            date: Date().toDateString(),
            status: .applied,
            starred: false,
            note: "",
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }

    static var onlineAssessmentApplication: Application {
        Application(
            id: "test-app-2",
            role: "iOS Developer",
            company: "Google",
            date: Date().addingTimeInterval(-3 * 24 * 60 * 60).toDateString(),
            status: .onlineAssessment,
            starred: true,
            note: "Hackerrank assessment due tomorrow",
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }

    static var interviewApplication: Application {
        Application(
            id: "test-app-3",
            role: "Senior Software Engineer",
            company: "Meta",
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60).toDateString(),
            status: .interview,
            starred: true,
            note: "Second round interview scheduled",
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
 
    static var rejectedApplication: Application {
        Application(
            id: "test-app-6",
            role: "Junior Developer",
            company: "Microsoft",
            date: Date().addingTimeInterval(-30 * 24 * 60 * 60).toDateString(),
            status: .rejected,
            starred: false,
            note: "Better luck next time",
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    // MARK: - Application Stages
    static var appliedStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-1",
            stage: .applied,
            status: .complete,
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60).toDateString(),
            note: "Application submitted successfully",
            sortOrder: 0,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var onlineAssessmentStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-2",
            stage: .onlineAssessment,
            status: .inProgress,
            date: Date().addingTimeInterval(1 * 24 * 60 * 60).toDateString(),
            note: "Complete by end of week",
            sortOrder: 1,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var phoneScreeningStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-3",
            stage: .phoneScreening,
            status: .complete,
            date: Date().addingTimeInterval(-5 * 24 * 60 * 60).toDateString(),
            note: "30 min call with recruiter - went well",
            sortOrder: 2,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var virtualInterviewStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-4",
            stage: .virtualInterview,
            status: .incomplete,
            date: Date().addingTimeInterval(3 * 24 * 60 * 60).toDateString(),
            note: "Technical interview via Zoom",
            sortOrder: 3,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var assessmentCentreStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-5",
            stage: .assessmentCentre,
            status: .incomplete,
            date: Date().addingTimeInterval(7 * 24 * 60 * 60).toDateString(),
            note: "Full day assessment in office",
            sortOrder: 4,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var interviewStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-6",
            stage: .interview,
            status: .inProgress,
            date: Date().toDateString(),
            note: "Panel interview with team leads",
            sortOrder: 5,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var awaitingOfferStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-7",
            stage: .awaitingOffer,
            status: .inProgress,
            date: Date().addingTimeInterval(-2 * 24 * 60 * 60).toDateString(),
            note: "Should hear back within a week",
            sortOrder: 6,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var offerStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-8",
            stage: .offer,
            status: .complete,
            date: Date().toDateString(),
            note: "Offer received! 🎉",
            sortOrder: 7,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    static var rejectedStage: ApplicationStage {
        ApplicationStage(
            id: "test-stage-9",
            stage: .rejected,
            status: .rejected,
            date: Date().addingTimeInterval(-1 * 24 * 60 * 60).toDateString(),
            note: "Not a good fit at this time",
            sortOrder: 8,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    }
    
    // MARK: - Applications with Stages
    
    static var fullProgressApplication: ApplicationWithStages {
        ApplicationWithStages(
            application: interviewApplication,
            stages: [
                appliedStage,
                phoneScreeningStage,
                virtualInterviewStage,
                interviewStage
            ]
        )
    }
    
    static var earlyStageApplication: ApplicationWithStages {
        ApplicationWithStages(
            application: onlineAssessmentApplication,
            stages: [
                appliedStage,
                onlineAssessmentStage
            ]
        )
    }
    
    
    static var rejectedAfterInterviewApplication: ApplicationWithStages {
        ApplicationWithStages(
            application: rejectedApplication,
            stages: [
                appliedStage,
                phoneScreeningStage,
                interviewStage,
                rejectedStage
            ]
        )
    }
    
    static var applicationWithNoStages: ApplicationWithStages {
        ApplicationWithStages(
            application: appliedApplication,
            stages: []
        )
    }

}

