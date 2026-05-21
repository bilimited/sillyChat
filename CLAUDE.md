# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Run / Test

```bash
# Get dependencies
flutter pub get

# Run code generation (freezed, json_serializable)
flutter pub run build_runner build

# Analyze
flutter analyze

# Run tests (only a placeholder widget test exists)
flutter test

# Build Android APK (release, arm64 only)
flutter build apk --release --target-platform android-arm64

# Build Windows release
flutter build windows --release
```

## Project Overview

SillyChat is a Flutter-based AI chat app inspired by NextChat and SillyTavern. Targets Android (primary) and Windows/Linux/macOS. Uses Material 3.

- Flutter 3.35.5, Dart SDK ^3.5.4
- Package name: `flutter_example` (legacy — do not rename)
- Version: 1.18.0

## Architecture

**State management**: GetX (`get: ^4.7.2`) with observable reactive variables (`.obs` / `RxList` / `RxMap`) and `GetBuilder` widgets.

**Persistence**: File-based JSON storage in a "vault" directory (`{appDocDir}/SillyChat/{vaultName}/`). Supports multiple vaults with WebDAV cloud sync. Each chat is a single `.chat` JSON file. No database — manual JSON serialization everywhere.

### Directory Layout

```
lib/
  main.dart                  # App entry point, controller init, theme setup
  chat-app/
    constants.dart           # App-wide constants
    events.dart              # Simple event classes (FileDeleted, FileCreated, etc.)
    themes.dart              # Theme data
    main_page.dart           # Desktop layout (sidebar + page view)
    mobile_main_page.dart    # Mobile layout (bottom nav)
    models/                  # Data models — manual toJson/fromJson
    providers/               # GetX controllers (BaseController pattern)
    pages/                   # Full-screen route pages
      character/             # Character CRUD, gallery, contact list
      chat/                  # Chat detail, message editing, search, file manager
      chat_options/          # Chat option presets
      common/                # Category management
      lorebooks/             # World book / lorebook editing
      other/                 # API management, prompts, onboarding
      regex/                 # Regex rule editing
      settings/              # Settings, import from SillyTavern, appearance
      story/                 # Story/group chat management
    widgets/                 # Reusable UI components
      chat/                  # Message bubbles, input area, think widget
      common/                # Shared form widgets (chips, switches, avatars)
      webview/               # WebView-based components (relation map, message rendering)
    utils/
      AIHandler.dart         # Dio HTTP client, SSE stream parsing, background task mgmt
      promptBuilder.dart     # Builds LLM message list: lorebook activation → prompt insertion → format
      promptFormatter.dart   # Macro/variable substitution in prompts
      LoreBookUtil.dart      # World book activation logic
      FileUtils.dart         # File system helpers
      init_app.dart          # First-run data initialization
      service_handlers/      # LLM provider adapters (see below)
      sillyTavern/           # SillyTavern import (characters, lorebooks, regex, config)
      entitys/               # LLMMessage, RequestOptions, ChatAIState
      markdown/              # Custom LaTeX markdown extensions
```

### Controller Initialization Pattern

All controllers extend `BaseController` (at `lib/chat-app/providers/base_controller.dart`), which uses a `Completer<void>` for async init. Controllers call `markReady()` after `onInit` completes. `SillyChatApp.waitAllReadyAndNotify()` awaits all controllers before showing the UI.

Controllers register with `Get.put()` in `SillyChatApp`'s constructor. Order matters — `SettingController` and `VaultSettingController` must be ready first since others depend on vault path info.

### Service Handler Pattern

`Servicehandler` (abstract class at `lib/chat-app/utils/service_handlers/ServiceHandler.dart`) defines the interface for each LLM provider. `Servicehandlerfactory.getHandler(ServiceType)` returns the correct implementation. Each handler knows its base URL, default model list, and how to format requests/parse responses.

Supported providers: OpenAI, Google/Gemini, DeepSeek, SiliconFlow, Kimi, and custom OpenAI-compatible endpoints.

`Aihandler` manages the shared `Dio` HTTP client (with HTTP/2 adapter), SSE streaming via `parseSseStream()`, and Android background execution (`FlutterBackground`). It handles cancellation via `dio.CancelToken`.

### Prompt Building Pipeline (`promptBuilder.dart`)

`Promptbuilder.getLLMMessageList()` constructs the LLM message array:
1. Lorebook/world book activation (scan messages for matching keys)
2. Insert activated lorebook entries into prompt templates
3. Process macros (`{{char}}`, `{{user}}`, etc.) and user message substitution
4. Separate "in-chat" prompts — inserted at specified depth within message history
5. Insert @D lorebook entries at specified depth
6. Format main content (if enabled)
7. Merge adjacent messages with the same role

### Chat File Structure

Chats are individual `.chat` JSON files stored in `{vaultPath}/chats/roles/{charId}/` or `{vaultPath}/chats/stories/{storyId}/`. Chat metadata is indexed in `chat_index.json` for listing. A `recent_chat.json` file tracks the 50 most recent chats (one per parent directory).

### WebView Components

The app uses `flutter_inappwebview` for HTML-rendered content: message display (markdown with custom CSS), the relationship graph visualization (D3.js-based), and a status bar. WebView assets live in `assets/webview/`.

### SillyTavern Compatibility

Import supports character cards (PNG/JSON), world books, regex, and presets from SillyTavern format. The import code lives in `lib/chat-app/utils/sillyTavern/`. Compatibility is experimental — the project doesn't aim for full ST feature parity.

## Important Conventions

- **Do not rename the package** from `flutter_example` — it's a legacy name that would break imports everywhere.
- The codebase uses **hand-written JSON serialization** throughout. Despite having `freezed_annotation`, `json_annotation`, and `build_runner` in dev dependencies, most models use manual `toJson()`/`fromJson()` — don't introduce code-gen serialization without a clear plan.
- Timestamps as IDs: integer IDs are typically `DateTime.now().microsecondsSinceEpoch`, not UUIDs. The `uuid` package is available but rarely used.
- Desktop detection is hardcoded to `false` in `SillyChatApp.isDesktop()` — the app currently runs in mobile layout on all platforms.
- Android release builds should use `--target-platform android-arm64` to keep APK size down.
