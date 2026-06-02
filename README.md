# LanguageIOS

Kamera, müzik, ses ve AI ile kişiselleştirilmiş, oyunlaştırılmış bir dil öğrenme
uygulaması (SwiftUI, iOS 17+). Türkçe arayüz.

## Özellikler

- **Onboarding** — 11 adımlı kişiselleştirme akışı (hedef/ana dil, yaş, amaç, seviye,
  stil, günlük hedef, hatırlatma saati) ve kişisel plan özeti.
- **Öğrenme haritası** — Duolingo tarzı, dile temalı kıvrımlı yol (Amerikan İngilizcesi
  = 50 eyalet; İngiliz İng./Almanca/İspanyolca/Fransızca/Türkçe = şehirler). Katmanlı
  görseller (gerçek PNG'ler veya prosedürel placeholder), animasyonlu deniz arka planı.
- **Ders motoru** — 5 egzersiz türü (kelime kartı, çoktan seçmeli, eşleştirme, yazarak,
  dinle-seç), 3 canlı hearts modeli, `AVSpeech` ile sesli telaffuz. 6 dilin ilk
  duraklarına elle yazılmış içerik + dil-başına yedek kelime havuzu.
- **Oyunlaştırma** — XP, günlük streak, durak-başı yıldız, zamanla yenilenen global can
  havuzu. Geri-getirme bildirimleri (streak hatırlatma, can yenilenme).
- **Pratik modu** — tamamlanan durakların kelimelerinden risksiz tekrar dersi.
- **Profil** — istatistikler, profil özeti, dil değiştirme.

## Mimari

Tek **composition root** (`AppEnvironment`) tüm servisleri/repository'leri tutar; launch'ta
kurulur, `AppStore`'a ve SwiftUI ağacına enjekte edilir. Offline-first; protokoller
"dikiş yeri", varsayılan implementasyonlar hafif (console/OSLog/MetricKit/UserDefaults) —
ileride 3. taraf sağlayıcı (Firebase/Sentry/…) aynı protokole takılır.

```
LanguageIOSApp ──(AppEnvironment.live())──► RootView(environment:)
        │                                       ├─ AppStore(environment:)   // @Observable
        │  analytics · logger · performance      └─ .environment(\.appEnvironment, env)
        │  crashReporter · speech · notifications
        │  profile/progress/settings/gamification repositories
        ▼
   Core/Persistence (KeyValueStore) ── tüm repository'lerin tek altı
```

## Modül haritası (`Sources/LanguageIOS/`)

| Klasör | İçerik |
|--------|--------|
| `App/` | `AppEnvironment` (DI), environment key |
| `Core/Observability/` | Analytics, Logging (OSLog), Performance (signpost+MetricKit), Crash |
| `Core/Persistence/` | `KeyValueStore`, şema + `Versioned<T>`, `StoreMigrator` (v1→v2) |
| `Core/Speech/` | `SpeechService` (AVSpeech / Noop) |
| `Data/` | `UserProfile` + Profile/Progress/Settings repository'leri |
| `Gamification/` | `GamificationState` (XP/streak/yıldız/can) + repository |
| `Onboarding/` | 11 adımlı akış, modeller, bileşenler |
| `LearningPath/` | Harita ekranı, `AppStore`, yolculuk katalogu, durak düğümü, tema |
| `Lessons/` | Ders modelleri, içerik + `LessonBuilder`, `LessonSession`, görünümler |
| `Profile/` | Profil/istatistik ekranı |
| `Notifications/` | Yerel bildirim yöneticisi + soyutlama |

Tüm kod `Sources/LanguageIOS/` altında (SPM kütüphanesi) → `swift build`/`swift test`
her şeyi kapsar. `App/LanguageIOSApp.swift` ince kabuktur.

## Kurulum & çalıştırma

Gereksinimler: Xcode 16+, [XcodeGen](https://github.com/yonsm/XcodeGen)
(`brew install xcodegen`).

```bash
# Kütüphaneyi derle ve test et (en hızlı geri bildirim)
swift build
swift test

# iOS uygulamasını üret ve çalıştır
xcodegen generate
xcodebuild -project LanguageIOS.xcodeproj -scheme LanguageIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

> Not: `LanguageIOS.xcodeproj` XcodeGen tarafından `project.yml`'den üretilir ve
> `.gitignore`'dadır. Yeni klasör/dosya eklediğinde `xcodegen generate` çalıştır.

## Görseller (PNG pipeline)

Durak görselleri `App/Assets.xcassets`'ten gelir; isimlendirme ve gerçek sanatın nasıl
ekleneceği için bkz. [docs/assets-naming.md](docs/assets-naming.md). Placeholder üretmek:
`swift Scripts/generate_placeholder_assets.swift`. App icon: `swift Scripts/generate_app_icon.swift`.

## CI & kalite

- [.github/workflows/ci.yml](.github/workflows/ci.yml): `swift build` → `swift test` →
  `xcodegen generate` → `xcodebuild` + `swiftlint`.
- Lint: `swiftlint` (kurallar `.swiftlint.yml`).

## Test

`swift test` ile tüm birim testleri (modeller, repository'ler, migration, analytics
funnel, gamification, ders motoru) host'ta (macOS) çalışır. UI testleri uygulama
hedefindedir ve `xcodebuild test` ile koşar.

## Yol haritası

- Gerçek auth & backend (offline-first mimari hazır)
- Daha çok dil/durak içeriği · gerçek katmanlı PNG sanatı
- Lokalizasyon (i18n) · erişilebilirlik
- Kamera-obje, müzik/şarkı sözü, AI cümle analizi (onboarding'de vaat edilen modüller)
