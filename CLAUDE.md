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
│   ├── ClaudeDirectoryScanner.swift  # Sendable. scan(cache:) → ScanOutput (projects + searchIndex + per-file mod-date cache)
│   ├── JSONLParser.swift             # Sendable struct. parse(at:) one full pass → metadata+title+searchText; parseAll for detail
│   ├── FileWatcher.swift             # FSEventStream wrapper, 2s debounce, passRetained prevent dangling
│   ├── TerminalApp.swift             # enum of supported terminals, NSWorkspace install detection
│   └── TerminalLauncher.swift        # Launches a chosen TerminalApp (AppleScript for Terminal/iTerm, `open -n` for others)
├── Stores/
│   └── ConversationStore.swift    # @MainActor @Observable — projects, selection, tokenized ranked search, coalesced reload
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
│       ├── ToolCallView.swift            # Rich tool call: input summary, collapsible result, inline diff (replaces old pill)
│       ├── DiffView.swift                # LCS line diff for Edit/Write changes
│       ├── SessionSummaryView.swift      # ConversationInsights header: model, tokens, files changed (+/−), tasks, duration; FlowLayout chips
│       └── EmptyStateView.swift          # "Select a Conversation" placeholder
│   ├── Sidebar/CommandHistoryView.swift  # ViewMode.commands — global searchable/copyable Bash history, row→conversation
│   ├── ResumeButton.swift         # Split-button: primary resumes in default terminal, menu picks any installed
│   └── SettingsView.swift         # Cmd+, — default terminal picker (@AppStorage "defaultTerminal")
└── Utilities/
    ├── ClaudeTheme.swift          # 5 Claude brand colors: peach, lightPeach, blush, pink, lavender
    ├── PathDecoder.swift          # "-Users-foo-bar" → "/Users/foo/bar"
    └── DateFormatting.swift       # Static ISO8601, relative, short formatters
```

## Key Design Decisions

- **Conversation titles** prefer the real `custom-title`/`ai-title` line from the JSONL (these live ~80–130KB into the file, so they need a full read — not the old 32KB head). Fall back to first user message (60 chars), then slug, then id.
- **Concurrency**: `ConversationStore` is `@MainActor`; all file I/O runs in `Task.detached` over `Sendable` parser/scanner returning value types, assigned back on the main actor. Watcher reloads are **coalesced** (single in-flight + queued flag) so an active session's FSEvents storm can't race shared arrays/dicts. This is what fixed the crash-on-active-session bug.
- **Rich detail view**: `ToolUseBlock.input` is decoded into a generic `JSONValue`; tool calls render with an input summary + collapsible result (paired by `tool_use_id` from following user messages), file edits render as inline `DiffView`, thinking is collapsible. **Reading mode** (`@AppStorage "readingMode"`) hides tool/thinking noise. `ConversationInsights` (derived from loaded messages) drives the summary header. `commands`/`filesTouched` are collected at scan time (small) for the global Command History and file→sessions lookups.
- **Search** is full-text and tokenized: one full-file parse builds `contentIndex` (real user+assistant text only — no tool calls/results/thinking), keyed by conv id, cached by file mod-date for cheap rescans. Query is split into terms; **every term must match** (AND) across title/slug/id/path/content; results ranked by weighted score; matched rows show a highlighted snippet. (Old bug: single-substring match failed any multi-word query.)
- **Markdown** uses MarkdownUI for prose sections. Code blocks are extracted first via regex (triple-backtick) and rendered with Claude's themed `CodeBlockView` (blush background, peach language labels).
- **Colors** follow Claude's brand: peach (#f4c28e), lightPeach (#f4c7a8), blush (#f4ccc2), pink (#f4d1dc), lavender (#f4d6f6). Defined in `ClaudeTheme.swift`.
- **State management** uses `@Observable` (Observation framework). `ConversationStore` is the single source of truth.
- **No SQLite/Core Data** — reads JSONL directly. Metadata extracted from first 32KB of each file.

## Claude Code JSONL Format

Each conversation is a `.jsonl` file in `~/.claude/projects/{encoded-path}/{sessionId}.jsonl`. Key message types:
- `type: "user"` — `message.content` is a plain `String`
- `type: "assistant"` — `message.content` is `[ContentBlock]` (text, thinking, tool_use)
- `type: "ai-title"` (`aiTitle`) / `"custom-title"` (`customTitle`) — generated conversation titles, used as the display title
- `type: "progress"`, `"file-history-snapshot"`, `"system"`, `"attachment"`, `"last-prompt"`, `"mode"`, `"permission-mode"`, `"queue-operation"`, `"agent-name"`, `"pr-link"` — skipped in display
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
