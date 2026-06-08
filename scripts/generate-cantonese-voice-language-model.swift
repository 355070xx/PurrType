import Foundation
import Speech

enum PurrTypeVoiceLanguageModelAssetError: Error, CustomStringConvertible {
    case missingArguments
    case emptyPhraseList

    var description: String {
        switch self {
        case .missingArguments:
            return "usage: swift scripts/generate-cantonese-voice-language-model.swift <phrases.txt> <output.bin>"
        case .emptyPhraseList:
            return "no non-comment phrases found for the Cantonese voice language model asset"
        }
    }
}

func phraseCount(for phrase: String) -> Int {
    if phrase.range(of: #"[A-Za-z0-9]"#, options: .regularExpression) != nil {
        return 180
    }
    return 80
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    throw PurrTypeVoiceLanguageModelAssetError.missingArguments
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let contents = try String(contentsOf: inputURL, encoding: .utf8)
let trimSet = CharacterSet.whitespacesAndNewlines
var phrases: [String] = []
var seen = Set<String>()

for rawLine in contents.components(separatedBy: .newlines) {
    let phrase = rawLine.trimmingCharacters(in: trimSet)
    if phrase.isEmpty || phrase.hasPrefix("#") || seen.contains(phrase) {
        continue
    }
    seen.insert(phrase)
    phrases.append(phrase)
}

guard !phrases.isEmpty else {
    throw PurrTypeVoiceLanguageModelAssetError.emptyPhraseList
}

let modelData = SFCustomLanguageModelData(locale: Locale(identifier: "zh-HK"),
                                          identifier: "org.purrtype.inputmethod.PurrTypeUnified.CantoneseVoice",
                                          version: "1") {
    for phrase in phrases {
        SFCustomLanguageModelData.PhraseCount(phrase: phrase, count: phraseCount(for: phrase))
    }
}

let fileManager = FileManager.default
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let temporaryURL = outputURL.appendingPathExtension("tmp")
try? fileManager.removeItem(at: temporaryURL)
try await modelData.export(to: temporaryURL)
try? fileManager.removeItem(at: outputURL)
try fileManager.moveItem(at: temporaryURL, to: outputURL)
