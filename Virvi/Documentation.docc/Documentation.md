# ``Virvi``

Track your job applications with ease and clarity and prepare for your interviews.
@Metadata {
    @PageImage(
        purpose: icon, 
        source: "VirviLogo", 
        alt: "App Logo")
    @PageColor(gray)
}

## Overview

Virvi is a SwiftUI-based job application tracker that helps you manage your job search journey. Keep track of application stages, add notes, and visualize your progress through an intuitive timeline interface. This app will also prepare you for the recruitment process of job interviews. Manually create custom interviews, or use the built in question generation powered by Gemini. Finally, record your responses and review past interviews.

![Virvi Logo](VirviLogo)

### Configuration

Sensitive information such as API keys is securely stored in a `Secrets.plist` file.  
The format of this plist file should include a single row with key: GEMINI\_API_KEY and value: Api Key String


### Application Features

- **Application Tracking**: Monitor each job application through customizable stages
- **Visual Timeline**: See your application progress with a dynamic stage timeline
- **Filter and Search Applications**: Organize applications by state like Applied, Interview, Offer, and Starred
- **Notes & Dates**: Add notes and track important dates for each stage

### Interview Features

- **Create Interviews**: Create new interviews with a list of questions
- **Generate Interviews**: Generate a list of questions from the interview title and additional details
- **Complete Interviews**: Reply to the preset questions in a intuitive chat UI with video recordings

### Authentication
- **Google Authentication**: Login using your google account
- **Backup and Sync**: All applications are stored in firestore for cross device syncing and backing up


## Models

- ``Application``
- ``ApplicationStage``
- ``Interview``
- ``Question``

## Main Views

### Application
- ``ApplicationsListView``
- ``EditApplicationView``

### Interview
- ``InterviewForm``
- ``InterviewChatView``
- ``QuestionListView``
- ``VideoPicker``

### Authentication
- ``LoginView``
- ``ProfileView``

## Main View Models

### Application
- ``ApplicationsListViewModel``
- ``EditApplicationViewModel``

### Interview
- ``CompletedInterviewsViewModel``
- ``InterviewFormViewModel``
- ``InterviewViewModel``
- ``QuestionListViewModel``
- ``DynamicInterviewViewModel``

### Video
- ``VideoViewModel``

### Login
- ``AuthViewModel``

### Repositories/Services
- ``ApplicationRepository``
- ``AuthServicing``
- ``GeminiService``

