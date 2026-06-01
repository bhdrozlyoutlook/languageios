# Learning Path (Öğrenme Yolculuğu) Design

## Goal

The post-onboarding home screen. A Duolingo-style winding path over a sea, themed by
the language the user chose during onboarding. Each stop is a **layered landmass**:
while locked or active it shows only a bare landmass ("sadece bir kara parçası"); when
the user completes it, the detail layers reveal one-by-one with an animation
("katmanlar tek tek açılır"). The path is different per language — American English
travels through US states, British English through London and other cities, German
through Münih, Köln, etc.

## Flow

1. Onboarding finishes → `OnboardingView`'s `onFinish` fires with the profile.
2. `RootView` stores `targetLanguage` + marks onboarding complete in `AppStore`
   (persisted to `UserDefaults`) and swaps to `LearningPathView`.
3. The map shows the journey for that language. Tapping the **active** stop completes
   it: its layers reveal one-by-one, the trail brightens, the next stop unlocks.
4. Progress is saved per language; relaunching restores exactly where the user left
   off (completed stops show fully built, no replay animation).

## Architecture

All code lives under `Sources/LanguageIOS/` so it is covered by `swift build` / `swift test`.

| File | Responsibility |
|------|----------------|
| `LearningPath/LearningPathModels.swift` | `StopArtwork`, `LearningStop`, `LearningJourney` + the 6-language catalog; `LearningProgress` / `StopStatus`. Pure value types. |
| `LearningPath/AppStore.swift` | `@Observable` source of truth; onboarding completion, chosen language, per-language progress; JSON-encoded into `UserDefaults`. SwiftUI-free. |
| `LearningPath/MapTheme.swift` | Sea + land palette, reuses `OnboardingTheme` accents. |
| `LearningPath/StopNodeView.swift` | One layered node: base landmass + reveal layers, status chrome, reveal animation, `LandmassShape`. |
| `LearningPath/LearningPathView.swift` | The screen: sea background, header + progress bar, winding `JourneyPathLayout` + dotted `JourneyTrail`. |
| `RootView.swift` | Owns `AppStore`, switches onboarding ↔ map. |

The reveal animation reuses the existing onboarding idiom (`Task { @MainActor }` +
`Task.sleep` + `withAnimation(.spring)`), as in `PersonalPlanSummaryView.triggerAnimations`.

## Asset naming convention (for the real PNGs)

Placeholders are procedural for now. To swap in real art, add the PNGs to an asset
catalog in the **app target** (`project.yml` already builds `App` + `Sources/LanguageIOS`;
create `App/Assets.xcassets` or add a catalog and reference it). Name each image exactly:

```
<languageRaw>_<slug>_base      # the landmass, shown locked/active
<languageRaw>_<slug>_l1         # detail layer 1 (revealed first)
<languageRaw>_<slug>_l2         # detail layer 2
…                               # up to the stop's layerCount (2–4)
```

- `<languageRaw>` is the `TargetLanguage` raw value: `englishUS`, `englishUK`,
  `german`, `spanish`, `french`, `turkish`.
- `<slug>` is the stop slug from the catalog, e.g. `california`, `london`, `muenchen`.
- Each layer PNG should be a **full-canvas transparent overlay** aligned to the base,
  so layers can fade/scale in independently.

`StopArtworkView.bundledImage(_:)` calls `UIImage(named:)`; when the named asset exists
it is used automatically, otherwise the procedural placeholder is drawn. No code change
is needed when art is delivered — only the correctly-named assets.

Full naming list is derivable from `LearningJourney.journey(for:)` (slug + layer count
per stop).

## Out of scope (next modules)

- Lesson/activity engine behind a stop (tapping currently just completes the stop).
- Real authentication (the auth screen completes onboarding locally for now).
- Real artwork (placeholders until PNGs are delivered).
