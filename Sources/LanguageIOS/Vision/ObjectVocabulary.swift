import Foundation

/// Maps common Vision classification identifiers (English nouns) to a Turkish gloss, so
/// a detected object becomes a learnable word pair. Unknown labels fall back to the
/// English term only.
enum ObjectVocabulary {
    static let turkish: [String: String] = [
        "cup": "fincan", "mug": "kupa", "coffee mug": "kahve kupası",
        "food": "yemek", "fruit": "meyve", "vegetable": "sebze",
        "drink": "içecek", "beverage": "içecek", "water": "su", "coffee": "kahve",
        "dog": "köpek", "cat": "kedi", "bird": "kuş", "fish": "balık", "horse": "at",
        "flower": "çiçek", "tree": "ağaç", "plant": "bitki", "grass": "çimen",
        "car": "araba", "bicycle": "bisiklet", "bus": "otobüs", "train": "tren",
        "book": "kitap", "chair": "sandalye", "table": "masa", "desk": "masa",
        "phone": "telefon", "mobile phone": "cep telefonu", "computer": "bilgisayar",
        "laptop": "dizüstü bilgisayar", "keyboard": "klavye", "mouse": "fare",
        "bottle": "şişe", "glass": "bardak", "plate": "tabak", "bowl": "kase",
        "sky": "gökyüzü", "cloud": "bulut", "building": "bina", "house": "ev",
        "door": "kapı", "window": "pencere", "wall": "duvar", "floor": "zemin",
        "shoe": "ayakkabı", "clothing": "giysi", "hat": "şapka", "bag": "çanta",
        "clock": "saat", "glasses": "gözlük", "eyeglasses": "gözlük",
        "spectacles": "gözlük", "sunglasses": "güneş gözlüğü",
        "sun glasses": "güneş gözlüğü", "dark glasses": "güneş gözlüğü",
        "shades": "güneş gözlüğü", "pen": "kalem", "pencil": "kurşun kalem",
        "paper": "kağıt", "money": "para", "key": "anahtar", "lamp": "lamba",
        "television": "televizyon", "guitar": "gitar", "ball": "top", "toy": "oyuncak"
    ]

    /// The best translatable (english, turkish) pair from classification results, or nil.
    static func bestMatch(in labels: [ObjectLabel]) -> (english: String, turkish: String)? {
        for label in labels {
            if let turkish = translation(for: label.identifier) {
                return (display(label.identifier), turkish)
            }
        }
        return nil
    }

    static func translation(for identifier: String) -> String? {
        let normalized = display(identifier).lowercased()
        if let direct = turkish[normalized] { return direct }
        // Taxonomy labels can be multi-word ("coffee mug"); try the last noun.
        if let last = normalized.split(separator: " ").last, let match = turkish[String(last)] {
            return match
        }
        return nil
    }

    static func display(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }
}
