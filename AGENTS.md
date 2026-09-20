# Living Folders

- Native SwiftUI macOS app; keep it window-only, without a menu-bar/status icon.
- Never make live Jev calls or run API-backed tests. Diego has locked the API budget. Inject `JevClassifier.Transport`; workspace tests must also supply a fake key provider and `preferences: nil`.
- Core tests: `swift test --filter LivingFoldersCoreTests`. App integration tests: `swift test --filter WorkspaceTests`. Full suite: `swift test`.
- Optional mock-only visual check: `LIVING_FOLDERS_TEST_SNAPSHOT=/tmp/living-folders-preview.png swift test --filter WorkspaceTests.testMockedWorkspaceSnapshot`. This renders native UI with injected scores; it does not verify Jev's real accuracy or latency.
- Build the app using `./build.sh`. Do not launch it with real credentials during verification.
- Folder watching uses FSEvents; scanning/classification is limited to visible top-level entries. Subfolders are single movable items, not recursively indexed content.
- A configured key is not proof of API health. The UI shows `Jev ready` only after a valid classification response. File contents and absolute paths are not sent to Jev.
- Preserve approval-only filesystem changes. Watcher updates invalidate previews; partial scoring cannot be approved. Shell moves are non-transactional: external changes during execution may still cause partial completion.
