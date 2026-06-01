# Onboarding Design

## Goal

Create the first onboarding module for a language learning iOS app. The onboarding should feel personal and motivating: it learns a few things about the user, builds a tailored learning plan, and then asks the user to sign in or register so the plan can be saved.

The flow should combine the friendly pace of Duolingo with the structured learning confidence of Babbel and Busuu, while leaving room for the app's differentiating features: camera-based object labels, music and lyrics learning, native voice output, and AI analysis.

## Core Product Decision

Login and registration happen at the end of onboarding, not at the beginning.

The app first gives the user value by creating a personal plan. The final account screen then has a clear reason to exist: saving the plan, progress, labels, and learning history.

## Flow

The onboarding has seven screens.

1. Welcome
2. Target language
3. Current level
4. Learning style
5. Daily goal
6. Personal plan summary
7. Login or register

## Screen Details

### 1. Welcome

Purpose: Set the app promise quickly and emotionally.

Title: "Dil öğrenmeyi hayatına taşı"

Body: "Gördüğün objelerden, dinlediğin şarkılardan ve konuşma pratiğinden sana özel dersler oluştur."

Primary action: "Başla"

### 2. Target Language

Purpose: Capture the user's main learning target.

Title: "Hangi dili öğrenmek istiyorsun?"

Options:

- İngilizce
- Türkçe
- Almanca
- İspanyolca
- Fransızca

Interaction: Single selection.

### 3. Current Level

Purpose: Set the starting difficulty and later personalize lesson depth.

Title: "Şu an seviyen nasıl?"

Options:

- Yeni başlıyorum
- Temel biliyorum
- Konuşmak istiyorum
- İleri seviye

Interaction: Single selection.

### 4. Learning Style

Purpose: Let the user express how they want to learn and make the product feel adaptive.

Title: "En çok nasıl öğrenmek istersin?"

Options:

- Kamera ile objeler
- Müzik ve şarkı sözleri
- Konuşma pratiği
- Kısa günlük dersler
- AI açıklamalar

Interaction: Multiple selection. At least one option should be selected before continuing.

### 5. Daily Goal

Purpose: Create commitment without making the app feel demanding.

Title: "Günde ne kadar çalışmak istersin?"

Options:

- 5 dakika
- 10 dakika
- 15 dakika
- 30 dakika

Interaction: Single selection.

### 6. Personal Plan Summary

Purpose: Convert the previous answers into a sense of progress and ownership. This screen should not feel like a generic feature tour. It should feel like the app prepared something for the user.

Title: "Planın hazır"

Example plan cards:

- Gerçek dünyadan kelime yakalama
- Şarkı sözleriyle çeviri ve kalıp öğrenme
- Native telaffuz ve sesli tekrar
- AI ile hata analizi ve açıklama

Behavior: The cards should adapt to the user's learning style choices where possible. If the user selected music, show the lyrics learning card. If the user selected camera, show the object label card. If the user selected speaking or AI, show voice and AI analysis cards.

Primary action: "Planımı kaydet"

### 7. Login Or Register

Purpose: Ask for account creation after the user has a reason to save progress.

Title: "Planını kaydet"

Body: "Hesabınla ilerlemen, etiketlerin ve öğrenme geçmişin saklanır."

Authentication options:

- Apple ile devam et
- Google ile devam et
- E-posta ile devam et

Secondary action: "Zaten hesabım var"

## UX Principles

- Keep each screen focused on one decision.
- Use large, tappable option cards.
- Show progress across the seven steps.
- Keep copy short and direct.
- Make the plan summary feel personal instead of promotional.
- Avoid forcing account creation before the user understands the value.

## SwiftUI Structure

Use a SwiftUI-first flow with local state owned by the onboarding root view.

Suggested components:

- `OnboardingView`: owns the current step and collected answers.
- `OnboardingStep`: enum for the seven screens.
- `OnboardingProfile`: value model containing selected language, level, learning styles, and daily goal.
- `OnboardingProgressView`: compact progress indicator.
- `OnboardingOptionCard`: reusable selectable card.
- `OnboardingPrimaryButton`: consistent primary action.
- `PersonalPlanSummaryView`: maps the user's answers into plan cards.
- `AuthChoiceView`: Apple, Google, and email entry points.

State should stay local while the user is inside onboarding. When the user finishes authentication, the completed profile can be persisted by the app's account or profile service.

## Data Flow

1. User starts onboarding.
2. Each screen writes a small value into `OnboardingProfile`.
3. The continue button advances only when the current screen has valid input.
4. The plan summary derives plan cards from `OnboardingProfile`.
5. The auth screen receives the profile and passes it into the sign-in/register completion path.

## Error Handling

- Disable continue actions until required selections exist.
- For authentication failures, show a short inline error and keep the user on the auth screen.
- For unavailable Google or Apple sign-in configuration, hide or disable the affected option in development builds.
- If the user exits onboarding before registering, preserve local onboarding answers only for the current session unless persistence is intentionally added later.

## Testing

Initial test coverage should verify:

- The continue button is disabled when required answers are missing.
- Single-select screens replace the previous selection.
- Learning style supports multiple selections.
- Personal plan cards are derived from selected learning styles.
- The final auth screen receives the completed onboarding profile.

## Out Of Scope For This First Module

- Full lesson engine.
- Camera object recognition.
- Spotify integration.
- ElevenLabs audio generation.
- Gemini or ChatGPT analysis.
- Real backend authentication implementation.

This first module creates the onboarding experience and the interfaces needed for later modules to connect real services.
