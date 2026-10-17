import OSLog
import SwiftUI

@main
struct TragApp: App {
    private let store: TransactionStore

    init() {
        do {
            store = TransactionStore(container: try TransactionStore.makeContainer())
        } catch {
            // The on-disk store couldn't open (e.g. a broken migration). Keep the app usable for this session.
            Log.storage.fault("Persistent store unavailable, using memory: \(String(describing: error), privacy: .public)")
            do {
                store = TransactionStore(container: try TransactionStore.makeContainer(inMemory: true))
            } catch {
                fatalError("Couldn't create even an in-memory store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
