
//
//  InterviewQuestionWidget.swift
//  InterviewQuestionWidget
//
//  Created by Ethan Zhang on 10/10/2025.
//

import WidgetKit
import SwiftUI

// MARK: - Updated Widget Provider

/// Replace your existing Provider with this
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> QuestionEntry {
        QuestionEntry(
            date: Date(),
            question: "What's your greatest technical achievement?"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuestionEntry) -> ()) {
        let entry = QuestionEntry(
            date: Date(),
            question: "Tell me about a time you solved a difficult problem."
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Simply read from cache - no API calls needed!
        let question = SharedQuestionCache.getDailyQuestion()
                      ?? "Open Virvi to see today's question"
        
        let currentDate = Date()
        let entry = QuestionEntry(date: currentDate, question: question)
        
        // Refresh at midnight tomorrow
        let midnight = Calendar.current.startOfDay(for: currentDate)
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: midnight)!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}


/// This view is for the widget to display the question of the day and the current day
struct InterviewQuestionWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question of the Day")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(entry.question)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            HStack {
                Text(entry.date, style: .date)
                    .font(.caption2)
                Spacer()
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
struct InterviewQuestionWidget: Widget {
    let kind: String = "InterviewQuestionWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            InterviewQuestionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Interview Question")
        .description("Daily interview question to practice.")
        // Only medium size widget
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemSmall) {
    InterviewQuestionWidget()
} timeline: {
    QuestionEntry(date: .now, question: "Describe a challenging bug you fixed and how you approached it.")
    QuestionEntry(date: .now, question: "How do you stay updated with new technologies?")
}
