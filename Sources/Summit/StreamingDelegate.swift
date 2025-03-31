
/// Strips out <think>...</think> from the streamed response, printing partial text as it arrives.
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
            }
            else if text[i...].hasPrefix("</think>") {
                isInsideThink = false
                i = text.index(i, offsetBy: "</think>".count)
            }
            else {
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