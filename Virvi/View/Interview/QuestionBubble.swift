//
//  QuestionBubble.swift
//  Virvi
//
//  Created by Ethan Zhang on 6/10/2025.
//

import SwiftUI
import Foundation
import AVKit

/// This struct is responsible for the UI of the question bubbles and video player thumbnails
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
                            if let recordingPath = question.recordingPath {
                                let videoURL = URL(fileURLWithPath: recordingPath)
                                // MARK: - Video Thumbnail
                                // Button which brings up videoplayerview
                                Button {
                                    showingVideoPlayer = true
                                } label: {
                                    // Zstack for thumbnail with play button on top
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
                                // Generate thumbnail when this view loads
                                .onAppear {
                                    generateThumbnail(for: videoURL)
                                }
                                // If thumbnail pressed, show videoplayer for videoURL
                                .sheet(isPresented: $showingVideoPlayer) {
                                    VideoPlayerView(videoURL: videoURL)
                                }
                            }
                            // MARK: - Transcript
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
    // MARK: - Generate thumbnail
    // Generate a video thumbnail from the video URL
    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        asset.generateThumbnail { image in
            // We need to use dispatch queue, because generate thumbnail uses old tech
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}
