<div align="center">
  <img src="virvi-logo.png" alt="Virvi Logo" width="200"/>
  
  # Virvi - Interview Practice & Job Tracker
  
  A native iOS app that helps job seekers prepare for interviews and track their applications.
  
  <img src="demo.gif" alt="Virvi Demo" width="300"/>
</div>

## Features

- **Mock Interviews**: Practice with AI-generated interview questions tailored to specific roles
- **Application Tracking**: Keep all your job applications organized in one place
- **Interview Recording**: Record yourself answering questions (stored locally on device)
- **Transcription**: Recordings are transcripted for ease of reviewing reponses
- **AI Feedback**: Get instant feedback on your interview responses
- **Cloud Sync**: Sign in with Google to backup and sync your data across devices
- **Home Screen Widget**: Daily interview question to keep you sharp

## Tech Stack

- **SwiftUI** - UI framework
- **SwiftData** - Local data persistence
- **Firebase**
  - Authentication (Google Sign-In)
  - Firestore (cloud sync)
  - Gemini AI (question generation and feedback)
- **WidgetKit** - Home screen widgets
- **UIKit** - Camera Recordings

## Requirements

- iOS 18.5+
- Xcode 15.0+
- Firebase project with Firestore and Firebase AI enabled

## Setup

1. Clone the repository

```bash
git clone https://github.com/Ethanz0/virvi-interview-job-tracker
cd virvi-interview-job-tracker
```

2. Open the project in Xcode

```bash
open Virvi.xcodeproj
```

2. Open the project in Xcode
```bash
open Virvi.xcodeproj
```

3. Add your Firebase configuration
   - Download `GoogleService-Info.plist` from your Firebase Console
   - Add it to the project (both main app and widget targets)
4. Configure Google Auth
   - Select your app target → Info tab → URL Types → +
   - Identifier: GoogleSignIn (any text is fine)
   - URL Schemes: copy REVERSED_CLIENT_ID from GoogleService-Info.plist
4. Build and run!

## Architecture

- **MVVM** - Clean separation of concerns
- **Repository Pattern** - Abstraction layer for data access
- **Sync Manager** - Handles bi-directional sync between local SwiftData and Firebase Firestore
- **Dependency Injection** - Centralized dependencies through `AppDependencies`

## Project Structure
```
Virvi/
├── Models/              # SwiftData models
├── ViewModels/          # Business logic
├── Views/               # SwiftUI views
├── Services/            # API services (Firebase, Gemini)
├── Repositories/        # Data access layer
└── Widget/              # Widget extension
```

## Privacy Policy & Contact

https://ethanz0.github.io/virvi-app/

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

