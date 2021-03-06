import Foundation
import Starscream

/// Information for connecting to the server
public struct HAConnectionInfo: Equatable {
    /// Create a connection info
    ///
    /// URLs are in the form of: https://url-to-hass:8123 and /api/websocket will be appended.
    ///
    /// - Parameter url: The url to connect to
    public init(url: URL) {
        self.init(url: url, engine: nil)
    }

    /// Internally create a connection info with engine
    internal init(url: URL, engine: Engine?) {
        self.url = Self.sanitize(url)
        self.engine = engine
    }

    /// The base URL for the WebSocket connection
    public var url: URL
    /// The URL used to connect to the WebSocket API
    public var webSocketURL: URL {
        url.appendingPathComponent("api/websocket")
    }

    /// Used for dependency injection in tests
    internal var engine: Engine?

    /// Should this connection info take over an existing connection?
    ///
    /// - Parameter webSocket: The WebSocket to test
    /// - Returns: true if the connection should be replaced, false otherwise
    internal func shouldReplace(_ webSocket: WebSocket) -> Bool {
        webSocket.request.url.map(Self.sanitize) != Self.sanitize(url)
    }

    /// Create a new WebSocket connection
    /// - Returns: The newly-created WebSocket connection
    internal func webSocket() -> WebSocket {
        let request = URLRequest(url: webSocketURL)
        let webSocket: WebSocket

        if let engine = engine {
            webSocket = WebSocket(request: request, engine: engine)
        } else {
            // prefer URLSession's implementation [since we plan to move to it eventually]
            // additionally, the custom engine seems to have difficulty with e.g. connection refused, where it will
            // not fire a failure -- the underlying tls transport sticks at 'waiting' which feels like an apple bug
            webSocket = WebSocket(request: request, useCustomEngine: false)
        }

        return webSocket
    }

    /// Clean up the given URL
    /// - Parameter url: The raw URL
    /// - Returns: A URL with common issues removed
    private static func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        for substring in [
            "/api/websocket",
            "/api",
        ] {
            if let range = components.path.range(of: substring) {
                components.path.removeSubrange(range)
            }
        }

        // We expect no extra trailing / in the
        while components.path.hasSuffix("/") {
            // remove any trailing /
            components.path.removeLast()
        }

        return components.url!
    }

    public static func == (lhs: HAConnectionInfo, rhs: HAConnectionInfo) -> Bool {
        lhs.url == rhs.url
    }
}
