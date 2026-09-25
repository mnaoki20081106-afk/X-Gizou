import Foundation

enum RemoteEnvironmentVerificationError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case invalidIdentity
    case identityTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "独立環境の確認URLを作成できませんでした。"
        case .invalidResponse:
            "独立環境から有効な確認応答を受け取れませんでした。"
        case .invalidIdentity:
            "独立環境IDが不正です。サーバー構成を確認してください。"
        case .identityTooLarge:
            "独立環境IDの応答サイズが不正です。"
        }
    }
}

enum RemoteEnvironmentVerifier {
    static let identityPath = "/.well-known/xgizou-environment-id"

    static func identityURL(for endpoint: URL) -> URL? {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil else {
            return nil
        }

        components.path = identityPath
        components.query = nil
        components.fragment = nil
        return components.url
    }

    static func normalizedIdentity(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else { return nil }
        return uuid.uuidString.lowercased()
    }

    static func fetchIdentity(from endpoint: URL) async throws -> String {
        guard let url = identityURL(for: endpoint) else {
            throw RemoteEnvironmentVerificationError.invalidEndpoint
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15

        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw RemoteEnvironmentVerificationError.invalidResponse
        }

        guard data.count <= 128 else {
            throw RemoteEnvironmentVerificationError.identityTooLarge
        }

        guard let raw = String(data: data, encoding: .utf8),
              let identity = normalizedIdentity(raw) else {
            throw RemoteEnvironmentVerificationError.invalidIdentity
        }

        return identity
    }
}
