import ArgumentParser
import Foundation

struct OllamaRequest: Codable {
    let prompt: String
    let model: String
}

struct OllamaResponseChunk: Codable {
    let response: String?
}

// Using a struct for config, no changes needed here
struct SummitConfig: Codable {
    var promptTemplate: String?
    var model: String?
    var endpointURL: String?
}

@main
struct Summit: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Insert summary into the file.")
    var insert = false

    @Option(name: .shortAndLong, help: "Ollama model name.")
    var model: String = "summit:latest"

    @Argument(help: "Path of the Markdown file to summarize.")
    var file: String

    // 1) Make these static to avoid decoding warnings
    private static let defaultPrompt = """
    Please create a short summary of this markdown note. 
    Don't include dates or times. 
    Be as concise as possible, include acronyms, etc. for brevity.
    """
    private static let defaultEndpoint = "http://localhost:11434/api/generate"

    // 2) Mark run() as mutating so we can modify 'model'
    mutating func run() throws {
        // Load optional config
        let config = loadConfig()

        // If config.model is present (and user hasn't specified a custom model), override
        if let configModel = config.model, model == "summit:latest" {
            model = configModel
        }

        let fileURL = URL(fileURLWithPath: file)
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) else {
            throw ValidationError("File or directory not found: \(fileURL.path)")
        }

        if isDir.boolValue {
            let items = try FileManager.default.contentsOfDirectory(atPath: fileURL.path)
            for item in items where item.hasSuffix(".md") {
                let mdURL = fileURL.appendingPathComponent(item)
                try summarizeFile(at: mdURL, config: config)
            }
        } else {
            try summarizeFile(at: fileURL, config: config)
        }
    }

    /// Load `~/.org.jrj.summit.config` if present, else return empty.
    private func loadConfig() -> SummitConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configURL = home.appendingPathComponent(".org.jrj.summit.config.plist")

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return SummitConfig()
        }

        do {
            let data = try Data(contentsOf: configURL)
            // Adjust decoder as needed; this uses PropertyList
            return try PropertyListDecoder().decode(SummitConfig.self, from: data)
        } catch {
            print("⚠️  Failed to load config from \(configURL.path): \(error)")
            return SummitConfig()
        }
    }

    private func summarizeFile(at fileURL: URL, config: SummitConfig) throws {
        let fileContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Use config.promptTemplate if present; else fallback
        let promptTemplate = config.promptTemplate ?? Self.defaultPrompt
        let prompt = "\(promptTemplate)\n\(fileContent)"

        let requestBody = OllamaRequest(prompt: prompt, model: model)

        // Use config.endpointURL if present; else fallback
        let endpointURL = config.endpointURL ?? Self.defaultEndpoint

        let rawSummary = try callOllamaAPIStreaming(
            request: requestBody,
            endpointURL: endpointURL
        )

        let noLinebreaks = rawSummary
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let cleanedSummary = noLinebreaks.trimmingCharacters(in: .whitespacesAndNewlines)
        let resultText = "✨" + cleanedSummary

        print("\n--- SUMMARY ---\n\(resultText)\n")

        if insert {
            let (updatedContent, didReplace) = insertSummary(into: fileContent, summary: resultText)
            if didReplace {
                try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ Summary updated in \(fileURL.lastPathComponent).")
            } else {
                print("⚠️ No summary updated in \(fileURL.lastPathComponent). 'Summary::' line not replaced.")
            }
        }
    }

    private func callOllamaAPIStreaming(request: OllamaRequest, endpointURL: String) throws -> String {
        guard let endpoint = URL(string: endpointURL) else {
            throw ValidationError("Invalid endpoint URL: \(endpointURL)")
        }
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)

        let streamer = StreamingDelegate()
        let session = URLSession(configuration: .default, delegate: streamer, delegateQueue: nil)

        let semaphore = DispatchSemaphore(value: 0)
        streamer.onComplete = { semaphore.signal() }

        let task = session.uploadTask(with: urlRequest, from: requestData)
        task.resume()

        semaphore.wait()
        return streamer.finalSummary
    }

    /// Inserts summary into the file content.
    private func insertSummary(into original: String, summary: String) -> (String, Bool) {
        var lines = original.components(separatedBy: .newlines)
        var replaced = false

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Summary::" || trimmed == "Summary:: Needs Review" {
                lines[i] = "Summary:: \(summary)"
                replaced = true
                break
            }
        }

        if replaced {
            return (lines.joined(separator: "\n"), true)
        } else {
            return (original, false)
        }
    }
}

/// Strips out <think>...</think> from the streamed response
class StreamingDelegate: NSObject, URLSessionDataDelegate {
    private let decoder = JSONDecoder()
    private var buffer = Data()
    private var isInsideThink = false

    var finalSummary = ""
    var onComplete: () -> Void = {}

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)

        // Process NDJSON line by line
        while let newlineRange = buffer.firstRange(of: Data([UInt8(ascii: "\n")])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

            if let chunk = try? decoder.decode(OllamaResponseChunk.self, from: lineData),
               let resp = chunk.response {
                processResponse(resp)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Process leftover data if not newline-terminated
        if !buffer.isEmpty {
            if let chunk = try? decoder.decode(OllamaResponseChunk.self, from: buffer),
               let resp = chunk.response {
                processResponse(resp)
            }
        }
        onComplete()
    }

    private func processResponse(_ text: String) {
        var i = text.startIndex
        while i < text.endIndex {
            if text[i...].hasPrefix("<think>") {
                isInsideThink = true
                i = text.index(i, offsetBy: "<think>".count)
            } else if text[i...].hasPrefix("</think>") {
                isInsideThink = false
                i = text.index(i, offsetBy: "</think>".count)
            } else {
                if isInsideThink {
                    // Show chain-of-thought in console but not in finalSummary
                    print(text[i], terminator: "")
                } else {
                    finalSummary.append(text[i])
                    print(text[i], terminator: "")
                }
                i = text.index(after: i)
            }
        }
        fflush(stdout)
    }
}
