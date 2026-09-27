import SwiftUI

@main
struct ToolkitTestApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Where the app's API lives. The UI tests start the app with
/// DOCKAI_TEST_SERVER set to their mock server; a Release build ignores it,
/// and CI refuses to upload one that contains the name at all.
enum Server {
    static var base: URL {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["DOCKAI_TEST_SERVER"], let u = URL(string: s) { return u }
        #endif
        return URL(string: "https://example.com")!
    }
}

struct ContentView: View {
    @State private var items: [String] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("error-banner")
                }
                ForEach(items, id: \.self) { Text($0) }
            }
            .navigationTitle("ToolkitTest")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: Server.base.appending(path: "items"))
            items = try JSONDecoder().decode([String].self, from: data)
            error = nil
        } catch { self.error = "Could not load: \(error.localizedDescription)" }
    }
}
