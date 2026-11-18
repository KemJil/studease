# StudEase: An Interactive Learning and Study Companion

**StudEase** is a Material 3 Android study companion built with Flutter and Firebase that brings courses, lesson PDFs, AI-assisted flashcards and quizzes, open-access books, language practice, and daily streak tracking into one unified workspace.

## Academic Project Information

- **Course:** ICS26011 — Applications Development and Emerging Technologies 3
- **Assessment:** Alternative Assessment (Final Academic Project), AY 2026–2027
- **Section & Group:** 3CSB — Group 3
- **Team Members:**
  - Charls Daniel Atilares (Lead)
  - John Stanley Dave
  - Jim Michael Ducut

## Key Features

- **Subject-Based Courses & Lesson PDFs:** Organize lessons under customizable subject courses, attach local lecture PDFs, and read them directly in-app.
- **Interactive Learning Tools:** Review with 3D flip flashcards and multiple-choice quizzes filtered by course, created manually or generated from notes and PDFs via Firebase AI Logic (with an offline parser fallback).
- **Study Streak & Calendar:** Set a daily study target (1, 3, or 5 tasks), log completed study sessions automatically, and track streaks on a monthly calendar with per-day activity logs.
- **Learning Resources & Language Practice:** Read course-categorized open-access PDF books with saved page progress, and practice Japanese, Spanish, and French vocabulary decks with quick phrase checks.
- **Personalization & Accessibility:** Includes a one-tap Demo Account preview, customizable study reminders, subtle sound effects with volume control, and full Dark Mode support.

## Tech Stack

- **Framework:** Flutter 3.50 / Dart 3.14 (Material 3)
- **Backend:** Firebase Authentication & Cloud Firestore
- **AI Integration:** Firebase AI Logic (`firebase_ai`) with offline local-parser fallback
- **PDF Engine:** Syncfusion Flutter PDF Viewer & PDF Text Extractor

## Local Setup

1. Install the Flutter SDK and Android toolchain, then fetch dependencies:
   ```bash
   flutter pub get
