<p align="center">
  <img src="Reclaude/Resources/AppIcon.png" width="128" height="128" alt="Reclaude icon">
</p>

<h1 align="center">Reclaude</h1>

<p align="center">
  <em>Re-call Claude. Browse, search, and resume your Claude Code conversations.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-black?style=flat-square" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/Liquid%20Glass-enabled-blueviolet?style=flat-square" alt="Liquid Glass">
  <a href="../../releases"><img src="https://img.shields.io/github/v/release/shashwattrili/reclaude?style=flat-square&color=f4c28e&label=release" alt="Release"></a>
</p>

---

A native macOS app that reads your [Claude Code](https://claude.ai/claude-code) chat history and lets you browse, search, and jump back into any conversation — across every project on your machine.

## Features

- **Browse all conversations** across every Claude Code project on your machine
- **Two sidebar views** — Recent (chronological) or By Project (collapsible groups)
- **Native search** — Cmd+F to filter by conversation name, project, or message content
- **Full chat viewer** — user and Claude messages styled with Claude's brand colors
- **Markdown rendering** — bold, italic, tables, lists, blockquotes, links via [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)
- **Code blocks** — detected and rendered in monospace with language labels and themed backgrounds
- **Tool calls** — displayed as compact pills showing the tool name
- **Full-text search** — finds keywords anywhere in conversation history, not just titles
- **Resume in Terminal** — one click to reopen any conversation with `claude --resume`
- **Context menus** — right-click to resume, copy session ID, or reveal the JSONL file in Finder
- **Live updates** — new conversations appear automatically via filesystem watching
- **Keyboard-first** — full menu bar with Cmd+1/2, Cmd+R, Cmd+Shift+R
- **Liquid Glass** — macOS 26 glass effects on message bubbles, code blocks, and tool pills
- **Claude's palette** — warm peach-to-lavender color scheme matching Claude's brand

## Install

### Download DMG

Grab the latest `Reclaude.dmg` from [Releases](../../releases), open it, and drag Reclaude to Applications.

Since the app is not notarized, you'll need to clear the quarantine flag:

```bash
xattr -cr /Applications/Reclaude.app
```

### Build from source

Requires Xcode Command Line Tools and macOS 26+.

```bash
git clone https://github.com/shashwattrili/reclaude.git
cd reclaude
swift build -c release
./scripts/build-app.sh
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+F** | Focus search |
| **Cmd+1** | Recent view |
| **Cmd+2** | By Project view |
| **Cmd+R** | Refresh conversations |
| **Cmd+Shift+R** | Resume selected conversation in Terminal |

## How it works

Claude Code stores every conversation as a JSONL file in `~/.claude/projects/`. Each line is a JSON object — user messages, assistant responses, tool calls, thinking blocks, and metadata.

Reclaude scans that directory, parses the first few lines of each file for metadata (session ID, slug, timestamps, first message preview), and presents them in a native SwiftUI interface. Full message history is loaded on-demand when you select a conversation.

```
~/.claude/projects/
├── -Users-you-Work-project-a/
│   ├── abc123.jsonl          ← one conversation
│   └── def456.jsonl          ← another conversation
├── -Users-you-Work-project-b/
│   └── ghi789.jsonl
└── ...
```

No database. No server. No network calls. Just reads files from disk.

## Project Structure

```
Reclaude/
├── ReclaudeApp.swift              # App entry point, menu commands, keyboard shortcuts
├── Models/
│   ├── ConversationMessage.swift  # JSONL line model (polymorphic content decoding)
│   ├── Conversation.swift         # Conversation metadata
│   └── Project.swift              # Project grouping
├── Services/
│   ├── ClaudeDirectoryScanner.swift  # Scans ~/.claude/projects/
│   ├── JSONLParser.swift             # Parses JSONL with metadata-only fast path
│   ├── FileWatcher.swift             # FSEventStream for live updates
│   └── TerminalLauncher.swift        # AppleScript to open Terminal with resume
├── Stores/
│   └── ConversationStore.swift    # @Observable state management
├── Views/
│   ├── ContentView.swift          # NavigationSplitView root
│   ├── Sidebar/                   # Recent list, project groups, conversation rows
│   └── Detail/                    # Chat viewer, message bubbles, code blocks
└── Utilities/
    ├── ClaudeTheme.swift          # Brand color palette
    ├── PathDecoder.swift          # Decodes directory names to paths
    └── DateFormatting.swift       # Relative/short date formatting
```

## Requirements

- **macOS 26** or later
- **Claude Code** installed and used at least once (so `~/.claude/` exists)
- **Swift 6.2+** (if building from source)

## License

MIT
