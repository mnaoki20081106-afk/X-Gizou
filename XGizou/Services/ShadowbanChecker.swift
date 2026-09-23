import Foundation

struct ShadowbanResult: Decodable {
    let notFound: Bool
    let suspended: Bool
    let protected: Bool
    let noTweet: Bool
    let searchBan: Bool
    let searchSuggestionBan: Bool
    let noReply: Bool
    let ghostBan: Bool
    let replyDeboosting: Bool
    let user: ShadowbanUser?

    enum CodingKeys: String, CodingKey {
        case notFound = "not_found"
        case suspended = "suspend"
        case protected = "protect"
        case noTweet = "no_tweet"
        case searchBan = "search_ban"
        case searchSuggestionBan = "search_suggestion_ban"
        case noReply = "no_reply"
        case ghostBan = "ghost_ban"
        case replyDeboosting = "reply_deboosting"
        case user
    }
}

struct ShadowbanUser: Decodable {
    let typeName: String?
    let legacy: ShadowbanLegacyUser?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case legacy
    }
}

struct ShadowbanLegacyUser: Decodable {
    let name: String?
    let screenName: String?
    let description: String?
    let profileImageURLString: String?

    enum CodingKeys: String, CodingKey {
        case name
        case screenName = "screen_name"
        case description
        case profileImageURLString = "profile_image_url_https"
    }

    var profileImageURL: URL? {
        guard let profileImageURLString else { return nil }
        let large = profileImageURLString.replacingOccurrences(of: "_normal.", with: ".")
        return URL(string: large)
    }
}

enum ShadowbanCheckError: LocalizedError {
    case invalidUsername
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Xのユーザー名は1〜15文字の英数字またはアンダースコアで入力してください。"
        case .invalidResponse:
            return "判定サービスから正しい応答を受け取れませんでした。"
        case .httpStatus(let code):
            return "判定サービスでエラーが発生しました（HTTP \(code)）。"
        }
    }
}

enum ShadowbanChecker {
    static let serviceURL = URL(string: "https://shadowban.lami.zip/")!
    static let sourceURL = URL(string: "https://github.com/Shadowban-Test/X")!

    static func normalizeUsername(_ raw: String) throws -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("@") {
            value.removeFirst()
        }

        guard (1...15).contains(value.count) else {
            throw ShadowbanCheckError.invalidUsername
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ShadowbanCheckError.invalidUsername
        }

        return value
    }

    static func check(username rawUsername: String) async throws -> ShadowbanResult {
        let username = try normalizeUsername(rawUsername)

        var components = URLComponents(string: "https://shadowban.lami.zip/api/test")!
        components.queryItems = [
            URLQueryItem(name: "screen_name", value: username)
        ]

        guard let url = components.url else {
            throw ShadowbanCheckError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("X-Gizou/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ShadowbanCheckError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ShadowbanCheckError.httpStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(ShadowbanResult.self, from: data)
        } catch {
            throw ShadowbanCheckError.invalidResponse
        }
    }
}
