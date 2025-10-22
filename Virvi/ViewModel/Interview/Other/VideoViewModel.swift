//
//  VideoViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 8/10/2025.
//

import SwiftUI
import AVFoundation
import Speech

/// This videoModel is responsible for the camera UIKit view, transcription and storing the video
class VideoViewModel: ObservableObject {
    
    @Published var transcription: String = ""
    @Published var statusMessage: String = ""
    @Published var isProcessing: Bool = false
    @Published var permanentVideoURL: URL?
    
    // Apple transcription API
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    // MARK: - Permanent Storage Directory
    private var videosDirectory: URL {
        // /var/mobile/Containers/Data/Application/{APP-ID}/Documents/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // InterviewVideos/ folder
        let videosPath = documentsPath.appendingPathComponent("InterviewVideos", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: videosPath.path) {
            try? FileManager.default.createDirectory(at: videosPath, withIntermediateDirectories: true)
        }
        
        return videosPath
    }
    
    // MARK: - Copy Video to Permanent Storage
    private func saveVideoToPermanentStorage(from tempURL: URL) throws -> URL {
        // Generate unique filename from UUID and .mov
        let filename = UUID().uuidString + ".mov"
        // videos Directory: /Documents/InterviewVideos/
        // Append filename
        let permanentURL = videosDirectory.appendingPathComponent(filename)
        
        // Copy file from temp location to permanent location
        try FileManager.default.copyItem(at: tempURL, to: permanentURL)
        
        return permanentURL
    }
    
    // MARK: - Request Permissions
    func requestPermissions() async -> Bool {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return cameraGranted && speechGranted
    }
    
    // MARK: - Extract Audio from Video
    private func extractAudio(from videoURL: URL) async throws -> URL {
        // Get reference to video
        let asset = AVURLAsset(url: videoURL)
        
        // Generate a temporary location to store the audio
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // Ensure nothing already exists there, otherwise delete
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create a export session
        // Tool for converting and exporting media
        // AVAssetExportPresetAppleM4A: Extract audio, and output as M4A, a type of audio file
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "VideoTranscription", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        // Confirm output format
        exportSession.outputFileType = .m4a
        
        // Perform the export
        try await exportSession.export(to: outputURL, as: .m4a)
        
        // Return the audio URL
        return outputURL
    }
    
    // MARK: - Transcribe Audio
    /// Transcribe a audio file
    /// - Parameter audioURL: The file location of the audio file
    /// - Returns: String of transcribed text
    private func transcribe(audioURL: URL) async throws -> String {
        // Ensure speech recogniser is available (.isAvailable)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "VideoTranscription", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Make a request to transcribe the audio url
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            // Only get final result, we dont need real time transcription
            request.shouldReportPartialResults = false
            // Start the recognition task
            recognizer.recognitionTask(with: request) { result, error in
                // Handle any errors
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                // Check result is final result
                // if shouldReportPartialResults was true, it would not be final
                if let result = result, result.isFinal {
                    // Get the best transcription formatted as a string
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - Transcribe Video
    /// This is the initial entry point from the viewModel to process a temp video
    /// - Parameter tempURL: Temporary URL of video recording
    func transcribeVideo(at tempURL: URL) async {
        // Main actor so that we can update main UI
        // Reset previous values such as transcription
        await MainActor.run {
            isProcessing = true
            transcription = ""
            permanentVideoURL = nil
            statusMessage = "Saving video..."
        }
        
        do {
            // Copy the saved temp vid to permanent storage
            let savedURL = try saveVideoToPermanentStorage(from: tempURL)
            
            permanentVideoURL = savedURL
            
            // Extract audio from video
            let audioURL = try await extractAudio(from: savedURL)
            
            // Transcribe
            let result = try await transcribe(audioURL: audioURL)
            
            // Remove audio file, as we only needed the transcription
            try? FileManager.default.removeItem(at: audioURL)
            
            await MainActor.run {
                transcription = result
                statusMessage = "Complete! Video saved permanently."
                isProcessing = false
            }
            
        } catch {
            await MainActor.run {
                statusMessage = "Error: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
    
    // MARK: - Delete Video
    func deleteVideo(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Get All Saved Videos
    func getAllSavedVideos() -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: videosDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return urls.filter { $0.pathExtension == "mov" }
    }
}
// From https://gist.github.com/gunantosteven/dc4b6994fc319bf1dc51f5c133ac6487
// Extends on AVAsset to generate thumbnail from video file
extension AVAsset {
    func generateThumbnail(completion: @escaping (UIImage?) -> Void) {
        // Don't do on main thread
        DispatchQueue.global().async {
            // AVAssetImageGenerator is a tool for extracting frames from video
            let imageGenerator = AVAssetImageGenerator(asset: self)
            // Ensure rotation metadata is accounted for
            imageGenerator.appliesPreferredTrackTransform = true
            // Specify time (frame) to capture, in particular the first frame
            let time = CMTime(seconds: 0.0, preferredTimescale: 600)
            // Array with the one time
            let times = [NSValue(time: time)]
            // Generate the thumbnail
            imageGenerator.generateCGImagesAsynchronously(forTimes: times, completionHandler: { _, image, _, _, _ in
                if let image = image {
                    completion(UIImage(cgImage: image))
                } else {
                    completion(nil)
                }
            })
        }
    }
}

// MARK: - Video Picker Coordinator
/// SwiftUI view wrapper around UIViewControllerRepresentable
struct VideoPicker: UIViewControllerRepresentable {
    // Binding videoURL so that UIKit can update this variable with the link then we can access it
    @Binding var videoURL: URL?
    @Environment(\.dismiss) var dismiss
    let maxDuration: TimeInterval

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Use camera
        picker.sourceType = .camera
        // Recorded video and not photo
        picker.mediaTypes = ["public.movie"]
        // Medium quality video to save on storage
        picker.videoQuality = .typeIFrame1280x720
        // Maximum duration of video
        picker.videoMaximumDuration = maxDuration
        picker.delegate = context.coordinator
        // Make camera face front
        picker.cameraDevice = .front
        // Turn off flash
        picker.cameraFlashMode = .off
        return picker
    }

    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Bridge between swiftUI and UIKit camera
    // Handles camera events with UIImagePickerControllerDelegate
    // UINavigationControllerDelegate required due to protocol/Interface, however we don't use
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        /// Get a reference to the parent swiftUI wrapper so that we can propogate URL changes
        let parent: VideoPicker
        
        /// Initialise this coordinator by providing the parent videoPicker swiftUI view wrapper
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        /// Runs when user presses, use video after recording
        /// - Parameters:
        ///   - picker: Camera interface
        ///   - info: Dictionary of everything about the recording (in particular we need .mediaURL for recording)
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // From the info dictionary, get the mediaURL and cast it (as?) URL type
            // This URL is temporary
            if let url = info[.mediaURL] as? URL {
                // Set this temp URL to parents videoURL variable through binding
                parent.videoURL = url
            }
            // Dismiss this camera view
            // At this point videoURL has been updated and InterviewView will see that the URL has changed
            
            parent.dismiss()
        }
        
        /// This is run when the user presses cancel on the camera screen and it will dismiss the camera view
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
