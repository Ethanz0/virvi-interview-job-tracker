//
//  QuestionBubble.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import SwiftUI
import Foundation
import AVKit

struct QuestionBubble: View {
    let question: Question
    let showAnswer: Bool
    @State private var showingVideoPlayer = false
    @State private var thumbnail: UIImage?
    
    var body: some View {
        VStack(spacing: 12) {
            // Question bubble
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.question)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(16)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            if showAnswer, let transcript = question.transcript {
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Video thumbnail if available
                            if let videoURL = question.recordingURL {
                                Button {
                                    showingVideoPlayer = true
                                } label: {
                                    ZStack {
                                        if let thumbnail = thumbnail {
                                            Image(uiImage: thumbnail)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: 200)
                                                .clipped()
                                                .cornerRadius(8)
                                        } else {
                                            Color.black
                                                .aspectRatio(16/9, contentMode: .fit)
                                                .cornerRadius(8)
                                        }
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: 200)
                                }
                                .onAppear {
                                    generateThumbnail(for: videoURL)
                                }
                                .sheet(isPresented: $showingVideoPlayer) {
                                    VideoPlayerView(videoURL: videoURL)
                                }
                            }
                            
                            Text(transcript)
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
    
    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        asset.generateThumbnail { image in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}
