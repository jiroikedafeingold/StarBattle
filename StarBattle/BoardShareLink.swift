import Foundation

/// Encodes a puzzle's layout into a compact, URL-safe token and back, and builds / parses
/// the deep link that opens the app to an identical board.
///
/// Only the region layout (plus the grid size and stars-per-unit) travels in the link —
/// the unique solution is re-derived by the solver on the receiving device, so no space
/// is wasted transmitting it. The payload is bit-packed (4 bits per region id), then
/// zlib-compressed when that comes out smaller, then Base64URL-encoded. A 10×10 board
/// fits in roughly 70 URL-safe characters.
enum BoardShareLink {
    /// The app's custom URL scheme (registered in Info.plist).
    static let scheme = "starbattleplus"
    /// The link "host" marking a shared board: `starbattleplus://b/<token>`.
    private static let host = "b"
    private static let version: UInt8 = 1

    // MARK: Link

    /// A share URL for a board. Never fails — falls back to the project home page if the
    /// (fixed-shape) encoding somehow can't be built.
    static func url(for puzzle: Puzzle) -> URL {
        if let token = encode(puzzle), let url = URL(string: "\(scheme)://\(host)/\(token)") {
            return url
        }
        return URL(string: "https://github.com/jiroikedafeingold/StarBattle")!
    }

    /// Decodes a puzzle from an incoming URL, or nil if it isn't a valid board link.
    static func puzzle(from url: URL) -> Puzzle? {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame else { return nil }
        // Accept starbattleplus://b/<token>, .../b?d=<token>, and starbattleplus://<token>.
        var token = ""
        if url.host == host {
            token = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if token.isEmpty,
               let d = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "d" })?.value {
                token = d
            }
        } else {
            token = url.host ?? ""
        }
        return token.isEmpty ? nil : decode(token)
    }

    // MARK: Encoding

    static func encode(_ puzzle: Puzzle) -> String? {
        let n = puzzle.size
        guard n > 0, n <= 15, puzzle.starsPerUnit <= 15 else { return nil }

        var raw: [UInt8] = [version, UInt8(n), UInt8(puzzle.starsPerUnit)]
        // Region ids row-major, packed two-per-byte (each id is 0..<n ≤ 15).
        var pendingHigh = true
        var acc: UInt8 = 0
        for row in puzzle.regions {
            for id in row {
                let nibble = UInt8(id & 0x0F)
                if pendingHigh { acc = nibble << 4; pendingHigh = false }
                else { acc |= nibble; raw.append(acc); pendingHigh = true }
            }
        }
        if !pendingHigh { raw.append(acc) }   // flush a trailing odd nibble

        let rawData = Data(raw)
        var out = Data()
        if let zipped = try? (rawData as NSData).compressed(using: .zlib) as Data,
           zipped.count < rawData.count {
            out.append(1)              // compressed
            out.append(zipped)
        } else {
            out.append(0)              // stored
            out.append(rawData)
        }
        return base64URL(out)
    }

    static func decode(_ token: String) -> Puzzle? {
        guard var data = base64URLDecode(token), data.count >= 2 else { return nil }
        let flag = data.removeFirst()
        var body = data
        if flag == 1 {
            guard let inflated = try? (body as NSData).decompressed(using: .zlib) as Data else { return nil }
            body = inflated
        }
        let bytes = [UInt8](body)
        guard bytes.count >= 3, bytes[0] == version else { return nil }

        let n = Int(bytes[1]), stars = Int(bytes[2])
        guard n > 0, n <= 15, stars >= 1, stars <= 15 else { return nil }
        let neededBytes = 3 + (n * n + 1) / 2
        guard bytes.count >= neededBytes else { return nil }

        var regions = Array(repeating: Array(repeating: 0, count: n), count: n)
        var i = 0
        for r in 0..<n {
            for c in 0..<n {
                let byte = bytes[3 + i / 2]
                regions[r][c] = Int(i % 2 == 0 ? (byte >> 4) : (byte & 0x0F))
                i += 1
            }
        }
        // Re-derive the unique solution; reject anything that isn't a real, solvable board.
        guard let solution = PuzzleGenerator.findSolutions(regions: regions, size: n,
                                                           stars: stars, limit: 1).first,
              !solution.isEmpty else { return nil }
        var puzzle = Puzzle(size: n, starsPerUnit: stars, regions: regions, solution: solution)
        puzzle.difficulty = (n == 5) ? .beginner : .easy
        return puzzle
    }

    // MARK: Base64URL

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}
