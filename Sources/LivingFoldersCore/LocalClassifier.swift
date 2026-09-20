import Foundation

/// Deterministic, offline classifier. Scores each item from the folder name using
/// file-type vocabulary, filename words, and time words. No network, no API key.
public struct LocalClassifier: Sendable {
    public static let threshold = 0.55

    static let images: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "svg", "raw", "dng", "cr2", "arw"]
    static let videos: Set<String> = ["mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "mpg", "mpeg"]
    static let audio: Set<String> = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff", "aif"]
    static let documents: Set<String> = ["pdf", "doc", "docx", "txt", "rtf", "pages", "md", "odt", "tex"]
    static let sheets: Set<String> = ["xls", "xlsx", "csv", "numbers", "tsv", "ods"]
    static let slides: Set<String> = ["ppt", "pptx", "key", "odp"]
    static let archives: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]
    static let installers: Set<String> = ["dmg", "pkg", "app", "ipa", "apk", "msi", "exe"]
    static let code: Set<String> = ["swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "json", "java", "c", "h", "cpp", "rs", "go", "sh", "rb", "php", "kt", "yml", "yaml", "toml", "sql", "ipynb"]
    static let design: Set<String> = ["fig", "sketch", "psd", "ai", "xd", "afdesign", "blend"]
    static let fonts: Set<String> = ["ttf", "otf", "woff", "woff2"]
    static let books: Set<String> = ["epub", "mobi", "azw3"]
    static let torrents: Set<String> = ["torrent"]

    /// Prompt word -> extensions it implies.
    static let vocabulary: [String: Set<String>] = [
        "image": images, "img": images, "photo": images, "picture": images, "pic": images, "wallpaper": images, "png": ["png"], "jpg": ["jpg", "jpeg"], "jpeg": ["jpg", "jpeg"], "heic": ["heic", "heif"], "gif": ["gif"], "svg": ["svg"], "icon": ["png", "svg", "icns"],
        "video": videos, "movie": videos, "film": videos, "clip": videos, "recording": videos.union(audio), "mp4": ["mp4"], "mov": ["mov"],
        "music": audio, "audio": audio, "song": audio, "sound": audio, "podcast": audio, "voice": audio, "mp3": ["mp3"],
        "document": documents, "doc": documents, "text": documents, "note": documents, "paper": documents, "letter": documents, "essay": documents, "reading": documents.union(books), "pdf": ["pdf"], "word": ["doc", "docx"], "markdown": ["md"],
        "spreadsheet": sheets, "sheet": sheets, "excel": sheets, "csv": ["csv"], "table": sheets, "data": sheets.union(["json"]),
        "presentation": slides, "slide": slides, "deck": slides, "keynote": ["key"], "powerpoint": ["ppt", "pptx"],
        "archive": archives, "zip": archives, "compressed": archives, "backup": archives,
        "installer": installers, "app": installers, "application": installers, "dmg": ["dmg"], "setup": installers, "download": installers.union(archives),
        "code": code, "script": code, "source": code, "programming": code, "dev": code, "project": code, "python": ["py", "ipynb"], "swift": ["swift"], "javascript": ["js", "ts"], "web": ["html", "css", "js"], "notebook": ["ipynb"], "config": ["json", "yml", "yaml", "toml"],
        "design": design, "figma": ["fig"], "sketch": ["sketch"], "photoshop": ["psd"], "illustrator": ["ai"], "mockup": design.union(images),
        "font": fonts, "typeface": fonts,
        "book": books.union(["pdf"]), "ebook": books, "epub": ["epub"], "kindle": ["mobi", "azw3"],
        "torrent": torrents,
    ]

    /// Prompt word -> words that, when found in a filename, count as a match.
    static let synonyms: [String: [String]] = [
        "receipt": ["receipt", "invoice", "order", "purchase", "payment"],
        "invoice": ["invoice", "receipt", "bill", "statement"],
        "bill": ["bill", "statement", "invoice", "utility"],
        "tax": ["tax", "irs", "w2", "w-2", "1099", "return"],
        "finance": ["invoice", "receipt", "bill", "tax", "bank", "statement", "budget", "payroll", "salary"],
        "money": ["invoice", "receipt", "bill", "tax", "bank", "statement", "budget"],
        "bank": ["bank", "statement", "account", "transfer"],
        "work": ["meeting", "notes", "report", "q1", "q2", "q3", "q4", "okr", "roadmap", "spec", "client", "deck", "agenda"],
        "school": ["homework", "assignment", "lecture", "syllabus", "essay", "class", "exam", "study", "notes", "thesis"],
        "university": ["homework", "assignment", "lecture", "syllabus", "essay", "class", "exam", "thesis"],
        "study": ["homework", "assignment", "lecture", "notes", "exam", "study", "flashcard"],
        "travel": ["flight", "boarding", "hotel", "itinerary", "trip", "passport", "visa", "booking", "reservation", "airbnb", "ticket", "airport", "rail", "train", "packing", "pass"],
        "trip": ["flight", "boarding", "hotel", "itinerary", "trip", "passport", "booking", "reservation", "airbnb", "ticket", "airport", "packing", "rail", "pass", "visa", "luggage"],
        "vacation": ["flight", "boarding", "hotel", "itinerary", "trip", "passport", "booking", "reservation", "airbnb", "ticket", "packing", "beach", "resort"],
        "flight": ["flight", "boarding", "airline", "ticket", "airport"],
        "airport": ["flight", "boarding", "airline", "ticket", "airport", "passport", "lounge", "transfer"],
        "hotel": ["hotel", "airbnb", "booking", "reservation", "checkin", "check-in"],
        "health": ["doctor", "medical", "prescription", "lab", "insurance", "dental", "vaccine", "clinic"],
        "medical": ["doctor", "medical", "prescription", "lab", "insurance", "dental", "vaccine", "clinic"],
        "legal": ["contract", "agreement", "nda", "lease", "signed", "terms", "policy"],
        "contract": ["contract", "agreement", "nda", "lease", "signed"],
        "resume": ["resume", "résumé", "cv", "cover", "portfolio"],
        "job": ["resume", "résumé", "cv", "cover", "offer", "interview", "application"],
        "career": ["resume", "résumé", "cv", "cover", "offer", "interview", "linkedin"],
        "recipe": ["recipe", "cooking", "meal", "menu", "grocery"],
        "food": ["recipe", "cooking", "meal", "menu", "grocery", "restaurant", "ramen", "sushi"],
        "fitness": ["workout", "gym", "run", "training", "exercise", "diet", "plan"],
        "workout": ["workout", "gym", "training", "exercise"],
        "home": ["rent", "lease", "mortgage", "utility", "electric", "water", "internet", "furniture", "ikea"],
        "car": ["car", "insurance", "registration", "dmv", "vehicle", "toyota", "honda", "tesla"],
        "family": ["mom", "dad", "birthday", "wedding", "family", "kids", "baby"],
        "party": ["party", "birthday", "invite", "invitation", "wedding"],
        "meme": ["meme", "funny", "lol", "reaction"],
        "old": ["old", "archive", "backup", "copy", "final", "v1", "v2", "draft"],
        "draft": ["draft", "wip", "untitled", "copy", "v1", "v2"],
        "learning": ["course", "tutorial", "lesson", "guide", "crash", "learn", "beginner", "notes"],
        "tutorial": ["course", "tutorial", "lesson", "guide", "crash", "learn", "beginner"],
        "course": ["course", "tutorial", "lesson", "guide", "lecture"],
    ]

    static let stopWords: Set<String> = [
        "a", "an", "the", "my", "me", "i", "im", "we", "our", "your", "you", "this", "that", "these", "those", "it", "its",
        "stuff", "thing", "things", "file", "files", "folder", "folders", "item", "items", "everything", "all", "every",
        "for", "of", "to", "in", "on", "at", "from", "with", "about", "into", "and", "or", "but", "so", "as", "by", "is", "are", "was", "be",
        "need", "want", "have", "got", "get", "put", "keep", "move", "just", "only", "fine", "ok", "okay", "please", "some", "new", "random", "misc",
    ]

    public init() {}

    public func classify(folderName: String, items: [FileItem], now: Date = Date()) -> [Membership] {
        let prompt = folderName.lowercased()
        let words = Self.tokens(prompt).map(Self.stem)
        let keywords = words.filter { !Self.stopWords.contains($0) }
        let wantsFolders = words.contains("folder") || words.contains("directory") || words.contains("subfolder")
        let wantsFiles = words.contains("file") || words.contains("document")

        var extensions = Set<String>()
        var nameWords = Set<String>()
        var hasTopic = false
        for word in keywords {
            if let exts = Self.vocabulary[word] { extensions.formUnion(exts) } else if word != "screenshot" { hasTopic = true }
            if let extra = Self.synonyms[word] { nameWords.formUnion(extra) }
            nameWords.insert(word)
        }
        let wantsScreenshots = words.contains("screenshot") || prompt.contains("screen shot")
        let timeWindow = Self.timeWindow(in: prompt, now: now)

        func nameHits(_ item: FileItem) -> Int {
            let fileTokens = Self.tokens(item.name.lowercased()).map(Self.stem)
            let fileText = item.name.lowercased()
            var hits = nameWords.filter { word in
                word.count >= 2 && (fileTokens.contains(word) || (word.count >= 4 && fileText.contains(word)))
            }.count
            if wantsScreenshots, fileText.contains("screenshot") || fileText.contains("screen shot") { hits += 1 }
            return hits
        }
        let hitsByItem = Dictionary(uniqueKeysWithValues: items.map { ($0.id, nameHits($0)) })
        // "Tax documents": a type word alone is not enough once a topic word is present and matches something.
        let topicMatters = hasTopic && hitsByItem.values.contains { $0 > 0 }
        let extensionWeight = topicMatters ? 0.3 : 0.6

        return items.map { item in
            var score = 0.0
            let hits = hitsByItem[item.id] ?? 0

            if !item.isDirectory, extensions.contains(item.ext) { score += extensionWeight }
            if hits > 0 { score += 0.5 + Double(min(hits, 3) - 1) * 0.12 }

            if let window = timeWindow {
                if window.contains(item.modified) { score += extensions.isEmpty && hits == 0 ? 0.6 : 0.3 } else { score -= 0.5 }
            }
            if wantsFolders && !wantsFiles { score += item.isDirectory ? 0.6 : -0.3 }
            if wantsFiles && !wantsFolders && item.isDirectory { score -= 0.4 }
            if item.isDirectory && !wantsFolders && !extensions.isEmpty && hits == 0 { score -= 0.2 }

            let confidence = min(0.98, max(0.04, score == 0 ? 0.06 : 0.08 + score))
            return Membership(id: item.id, belongs: confidence >= Self.threshold, confidence: (confidence * 1000).rounded() / 1000)
        }
    }

    static func tokens(_ text: String) -> [String] {
        text.split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    static func stem(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 3, word.hasSuffix("es"), !word.hasSuffix("ses") { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }

    static func timeWindow(in prompt: String, now: Date) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: startOfToday)! }
        if prompt.contains("today") { return startOfToday...now }
        if prompt.contains("yesterday") { return daysAgo(1)...startOfToday }
        if prompt.contains("this week") || prompt.contains("past week") || prompt.contains("last week") || prompt.contains("recent") { return daysAgo(7)...now }
        if prompt.contains("this month") || prompt.contains("past month") || prompt.contains("last month") { return daysAgo(31)...now }
        if prompt.contains("this year") { return calendar.date(from: calendar.dateComponents([.year], from: now))!...now }
        if prompt.contains("older than a year") || prompt.contains("last year") { return Date.distantPast...daysAgo(365) }
        if tokens(prompt).contains("old") { return Date.distantPast...daysAgo(90) }
        return nil
    }
}
