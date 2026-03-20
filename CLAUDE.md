# Reclaude — Project Context

## What is this?

**Reclaude** ("re-call Claude") is a native macOS 26 SwiftUI app that lets you browse, search, and resume Claude Code terminal conversations. It reads JSONL files directly from `~/.claude/projects/` — no database, no server, no network calls.

**Repo:** https://github.com/shashwattrili/reclaude
**Current version:** 0.1.1

## Tech Stack

- **Swift 6.2**, **SwiftUI**, targeting **macOS 26** (Liquid Glass)
- **Swift Package Manager** — no Xcode project, build with `swift build`
- **MarkdownUI** (gonzalezreal/swift-markdown-ui) — GitHub Flavored Markdown rendering
- **FSEventStream** — recursive filesystem watching for live updates
- **NSAppleScript** — Terminal.app integration for resuming sessions
- App Sandbox **disabled** (needs `~/.claude/` access)

## Architecture

```
Reclaude/
├── ReclaudeApp.swift              # @main, WindowGroup, .commands, keyboard shortcuts
├── Models/
│   ├── ConversationMessage.swift  # JSONL line model — polymorphic Codable (string vs [ContentBlock])
│   ├── Conversation.swift         # Lightweight metadata, displayName prefers firstUserMessage
│   └── Project.swift              # Groups conversations by project directory
├── Services/
│   ├── ClaudeDirectoryScanner.swift  # Scans ~/.claude/projects/*/*.jsonl, builds [Project]
│   ├── JSONLParser.swift             # parseMetadata (32KB/50 lines) and parseAll, extractSearchableText
│   ├── FileWatcher.swift             # FSEventStream wrapper, 2s debounce, passRetained prevent dangling
│   └── TerminalLauncher.swift        # AppleScript to open Terminal with `claude --resume <id>`
├── Stores/
│   └── ConversationStore.swift    # @Observable — projects, selection, search, background content index
├── Views/
│   ├── ContentView.swift          # NavigationSplitView + .searchable(placement: .sidebar)
│   ├── Sidebar/
│   │   ├── SidebarView.swift      # Toolbar picker (Recent/By Project), navigation title
│   │   ├── RecentListView.swift   # Flat chronological list
│   │   ├── ProjectGroupListView.swift  # DisclosureGroup per project, expand/collapse
│   │   └── ConversationRowView.swift   # Title (first message), slug caption, context menu
│   └── Detail/
│       ├── ConversationDetailView.swift  # .navigationTitle, toolbar resume button, LazyVStack messages
│       ├── MessageBubbleView.swift       # User (lavender) and Claude (peach) bubbles
│       ├── CodeBlockView.swift           # Splits text into prose (→MarkdownUI) and code blocks (themed)
│       ├── MarkdownText.swift            # Legacy custom parser (no longer used by MessageBubbleView)
│       ├── ToolCallSummaryView.swift     # Compact capsule pill with tool name
│       └── EmptyStateView.swift          # "Select a Conversation" placeholder
└── Utilities/
    ├── ClaudeTheme.swift          # 5 Claude brand colors: peach, lightPeach, blush, pink, lavender
    ├── PathDecoder.swift          # "-Users-foo-bar" → "/Users/foo/bar"
    └── DateFormatting.swift       # Static ISO8601, relative, short formatters
```

## Key Design Decisions

- **Conversation titles** show the first user message (truncated to 60 chars), not slugs or UUIDs. Slug shown as peach-colored caption when available.
- **Search** is full-text: a background index (`contentIndex`) parses all JSONL files on launch, capped at 50KB per conversation. Also matches slug and session ID.
- **Markdown** uses MarkdownUI for prose sections. Code blocks are extracted first via regex (triple-backtick) and rendered with Claude's themed `CodeBlockView` (blush background, peach language labels).
- **Colors** follow Claude's brand: peach (#f4c28e), lightPeach (#f4c7a8), blush (#f4ccc2), pink (#f4d1dc), lavender (#f4d6f6). Defined in `ClaudeTheme.swift`.
- **State management** uses `@Observable` (Observation framework). `ConversationStore` is the single source of truth.
- **No SQLite/Core Data** — reads JSONL directly. Metadata extracted from first 32KB of each file.

## Claude Code JSONL Format

Each conversation is a `.jsonl` file in `~/.claude/projects/{encoded-path}/{sessionId}.jsonl`. Key message types:
- `type: "user"` — `message.content` is a plain `String`
- `type: "assistant"` — `message.content` is `[ContentBlock]` (text, thinking, tool_use)
- `type: "progress"`, `"file-history-snapshot"`, `"system"` — skipped in display
- User messages with only `tool_result` blocks are auto-generated and hidden
- Fields: `uuid`, `parentUuid`, `timestamp` (ISO 8601), `sessionId`, `slug`, `cwd`, `gitBranch`, `message.usage` (token counts)

## Build & Install

```bash
swift build -c release                    # Build
./scripts/build-app.sh                    # Create .app bundle + install prompt
create-dmg ... dist/Reclaude.dmg .build/Reclaude.app  # Package DMG
```

## Conventions

- Keep colors in `ClaudeTheme.swift`, never hardcode hex in views
- Use `DateFormatting` static methods, not inline formatter creation
- `ConversationStore` handles all data flow — views read from it via `@Environment`
- Views use `@Bindable var store = store` pattern inside `body` for bindings from `@Environment`
- No unit tests yet
