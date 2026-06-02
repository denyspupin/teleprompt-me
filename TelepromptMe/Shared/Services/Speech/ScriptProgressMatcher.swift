import Foundation

struct ScriptProgressMatch: Equatable {
    var wordIndex: Int
    var progress: Double
    var confidence: Double
}

final class ScriptProgressMatcher {
    private struct Token: Equatable {
        var value: String
        var characterOffset: Int
    }

    private var scriptTokens: [Token] = []
    private var currentWordIndex = 0
    private var lastTranscriptTokenCount = 0

    func prepare(script: String) {
        scriptTokens = Self.tokenize(script)
        currentWordIndex = 0
        lastTranscriptTokenCount = 0
    }

    func reset() {
        currentWordIndex = 0
        lastTranscriptTokenCount = 0
    }

    func match(transcript: String, sensitivity: Double) -> ScriptProgressMatch? {
        guard !scriptTokens.isEmpty else { return nil }

        let spoken = Self.tokenize(transcript).map(\.value)
        guard spoken.count >= 2 else { return nil }

        let newTokenCount = max(0, spoken.count - lastTranscriptTokenCount)
        lastTranscriptTokenCount = max(lastTranscriptTokenCount, spoken.count)

        let phraseLength = min(8, max(3, newTokenCount + 4))
        let phrase = Array(spoken.suffix(phraseLength))

        let searchStart = max(0, currentWordIndex - 6)
        let searchEnd = min(scriptTokens.count, currentWordIndex + 48)
        guard searchStart < searchEnd else { return nil }

        var bestIndex = currentWordIndex
        var bestScore = 0.0
        var bestRawScore = 0.0
        let maxWindow = min(phrase.count + 2, searchEnd - searchStart)

        for index in searchStart..<searchEnd {
            let remaining = searchEnd - index
            let windowLength = min(maxWindow, remaining)
            guard windowLength >= 2 else { continue }

            let scriptWindow = scriptTokens[index..<(index + windowLength)].map(\.value)
            let score = Self.similarity(spoken: phrase, script: scriptWindow)
            let distancePenalty = Double(max(0, index - currentWordIndex)) * 0.006
            let adjustedScore = score - distancePenalty
            if adjustedScore > bestScore {
                bestScore = adjustedScore
                bestRawScore = score
                bestIndex = min(scriptTokens.count - 1, index + max(1, phrase.count - 1))
            }
        }

        guard bestRawScore >= sensitivity else { return nil }

        let maximumAdvance = max(2, newTokenCount + 3)
        currentWordIndex = min(max(currentWordIndex, bestIndex), currentWordIndex + maximumAdvance)
        return ScriptProgressMatch(
            wordIndex: currentWordIndex,
            progress: Double(currentWordIndex) / Double(max(scriptTokens.count - 1, 1)),
            confidence: bestRawScore
        )
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { substring, range, _, _ in
            guard let substring else { return }
            let normalized = substring
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            let offset = text.distance(from: text.startIndex, to: range.lowerBound)
            tokens.append(Token(value: normalized, characterOffset: offset))
        }
        return tokens
    }

    private static func similarity(spoken: [String], script: [String]) -> Double {
        let rows = spoken.count + 1
        let columns = script.count + 1
        var scores = Array(repeating: Array(repeating: 0, count: columns), count: rows)

        for row in 1..<rows {
            for column in 1..<columns {
                if spoken[row - 1] == script[column - 1] {
                    scores[row][column] = scores[row - 1][column - 1] + 1
                } else {
                    scores[row][column] = max(scores[row - 1][column], scores[row][column - 1])
                }
            }
        }

        return Double(scores[spoken.count][script.count]) / Double(max(spoken.count, 1))
    }
}
