# Harita görselleri — katmanlı PNG rehberi

Harita duraklarının görselleri `App/Assets.xcassets` içindeki **imageset**'lerden gelir.
[StopArtworkView](../Sources/LanguageIOS/LearningPath/StopNodeView.swift) önce
`UIImage(named:)` ile katalogdan görseli arar; yoksa prosedürel placeholder çizer. Yani
**doğru adla PNG eklemek yeterli — kod değişikliği gerekmez.**

## Adlandırma kuralı

Her durak için, [LearningPathModels](../Sources/LanguageIOS/LearningPath/LearningPathModels.swift)
`StopArtwork`'ün ürettiği adlar:

```
<dil>_<slug>_base      → durağın "kara parçası" (kilitli/aktif/tamamlanmış hep görünür)
<dil>_<slug>_l1 … _lN  → tamamlanınca tek tek açılan katmanlar (2–4 adet)
```

- `<dil>` = `TargetLanguage` ham değeri: `englishUS`, `englishUK`, `german`, `spanish`, `french`, `turkish`
- `<slug>` = kataloğtaki durak slug'ı: `california`, `oregon`, `london`, `muenchen`, `madrid`, `paris`, `istanbul`, …
- Katman sayısı durak indeksine göre `2 + (index % 3)` → durak başına 2–4 katman.

### Örnek (englishUS, ilk 4 durak)

| Durak | base | katmanlar |
|-------|------|-----------|
| California (0) | `englishUS_california_base` | `_l1`, `_l2` |
| Oregon (1) | `englishUS_oregon_base` | `_l1`, `_l2`, `_l3` |
| Washington (2) | `englishUS_washington_base` | `_l1` … `_l4` |
| Nevada (3) | `englishUS_nevada_base` | `_l1`, `_l2` |

Tam liste `LearningJourney.journey(for:)` ve `StopArtwork.layerImageNames`'ten türetilir.

## Görsel hazırlama notları

- Her **katman**, base ile **aynı boyutta, hizalı, şeffaf arka planlı** bir PNG olmalı (ZStack ile üst üste binerler).
- `base` ekranda ~132pt'lik bir alana `scaledToFit` ile çizilir; kare (örn. 512×512) PNG'ler iyi sonuç verir.
- Katmanlar tamamlanınca alttan yukarı, yaylı animasyonla açılır.

## Şimdiki durum

`englishUS_california_*` için **placeholder** PNG'ler var (yeşil "CA" kara parçası + ev + ağaç),
sadece pipeline'ı göstermek için. Bunları kendi katmanlı sanatınla değiştir. Yeni placeholder
üretmek istersen: `swift Scripts/generate_placeholder_assets.swift`.
