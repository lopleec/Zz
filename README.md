# Zz — macOS AI Desktop Assistant

An intelligent AI assistant that lives in your macOS status bar and can see and control your desktop.

## Features

- 🎯 **Global Hotkey** — Press `⌘+Shift+Space` to summon/dismiss the assistant
- 🖥️ **Screen Awareness** — Captures screenshots and reads UI via Accessibility API
- 🖱️ **Computer Control** — Simulates mouse clicks, keyboard input, scrolling, and dragging
- 🧠 **Multi-LLM Support** — Claude, OpenAI, Gemini, or custom (OpenAI-compatible) endpoints
- 📋 **Task Planning** — Auto-generates step-by-step plans for complex tasks
- ↩️ **Undo Support** — Undo the last AI-performed action
- ⚠️ **Safety Confirmations** — Prompts for approval before sensitive operations
- 💬 **Chat Interface** — Beautiful glassmorphism UI with image attachment support
- 📎 **Image Attachment** — Attach screenshots or images to your messages
- 🔄 **Background Operation** — Runs as a status bar app, no Dock icon

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+
- An API key for at least one LLM provider

## Quick Start

### Build & Run

```bash
cd Zz

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Build
xcodebuild build -project Zz.xcodeproj -scheme Zz \
  -configuration Debug -derivedDataPath .build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Run
open .build/Build/Products/Debug/Zz.app
```

### First Launch

1. The app appears in your **status bar** (sparkles icon ✨)
2. Press **⌘+Shift+Space** to open the chat panel
3. Click the **⚙️ gear icon** to open Settings
4. Enter your **API key** for your preferred provider
5. Grant **Accessibility** and **Screen Recording** permissions when prompted

## Permissions Required

| Permission | Why | How |
|-----------|-----|-----|
| **Accessibility** | Read UI elements, simulate mouse/keyboard | System Settings → Privacy & Security → Accessibility |
| **Screen Recording** | Capture screenshots for AI vision | System Settings → Privacy & Security → Screen Recording |

## Architecture

```
Zz/
├── Models/          # Data models (ChatMessage, TaskPlan, ToolAction, Settings)
├── Views/           # SwiftUI views (ChatView, FloatingPanel, etc.)
├── Services/        # System services (HotkeyManager, ScreenCapture, InputSimulator)
├── Agent/           # AI brain (LLM providers, AgentLoop, SystemPrompts)
└── Utilities/       # Helpers (ImageUtils, KeyCodes)
```

## Supported LLM Providers

| Provider | Computer Use | Notes |
|----------|-------------|-------|
| **Claude** (Anthropic) | ✅ Native | Best support via `computer_use` tool |
| **OpenAI** (GPT-4o) | ✅ Via function calling | Vision + function calling |
| **Gemini** (Google) | ✅ Via function calling | Vision + function calling |
| **Custom** | ✅ Via OpenAI-compatible API | Any compatible endpoint |

## How It Works

1. **You type a request** → "Open Safari and go to google.com"
2. **AI generates a plan** → Step 1: Take screenshot → Step 2: Click Spotlight → ...
3. **AI executes each step** → Screenshots → clicks → types → verifies
4. **You see progress** → Real-time plan updates with step status
5. **Task completes** → AI reports what was done

## Safety

- **Sensitive operations** (quit app, delete, destructive commands) trigger a confirmation dialog
- **Input control banner** warns when AI is controlling mouse/keyboard
- **Undo support** lets you reverse the last action
- **Iteration limit** prevents runaway API costs (default: 30 iterations)

## License

MIT
