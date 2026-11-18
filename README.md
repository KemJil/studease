# StudEase — An Interactive Learning and Study Companion

Flutter (Material 3) study app for **ICS26011 · Group 3**
(Charls Daniel Atilares, John Stanley Dave, Jim Michael Ducut).

Courses · Flashcards & Quizzes (AI or manual) · Streak & Calendar · Books & PDFs.

## Stack

- Flutter 3.50 / Dart 3.14, Material 3 (`package:material_ui`), Android-first.
- Firebase Auth + Cloud Firestore (`studease-27e63kemjil`), **no Cloud Storage**.
- Firebase AI Logic (`firebase_ai`) → `gemini-3.8-flash` (retry `gemini-3.5-flash-lite`),
  with an offline local notes parser as the guaranteed fallback.
- In-app PDF reader: `syncfusion_flutter_pdfviewer` (+ `syncfusion_flutter_pdf` for text extraction).

## First-run setup

1. `flutter pub get`
2. Firebase console → **Build → AI Logic**: enable the Gemini Developer API for the project,
   otherwise generation silently falls back to the local parser.
3. Publish the security rules (owner-only access to `users/{uid}/**`):
   ```bash
   firebase deploy --only firestore:rules
   ```
4. `flutter run` on an Android device/emulator.

## Demo access

The auth screen has **⚡ Try Demo Account** — one tap signs in (or creates) the shared
`demo.student@studease.app` account and seeds lessons, decks, a quiz and five open-access books.
Rotate/delete that account after the project defense.


## Project docs

- `docs/` — interactive UI prototype (`index.html`), user-flow diagram, and the ICS26011 project proposal.
- `firestore.rules` & `firebase.json` — owner-scoped Cloud Firestore security rules and Firebase configuration.
## Verify

```bash
flutter analyze
flutter test
```
