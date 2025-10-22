//
//  InterviewQuestionWidgetBundle.swift
//  InterviewQuestionWidget
//
//  Created by Ethan Zhang on 10/10/2025.
//

import WidgetKit
import SwiftUI
import FirebaseCore

@main
struct InterviewQuestionWidgetBundle: WidgetBundle {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    var body: some Widget {
        InterviewQuestionWidget()
    }
}
