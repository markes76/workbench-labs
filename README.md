<p align="center">
  <img src="docs/assets/brand/workbench-labs-logo.png" width="96" alt="Workbench Labs logo">
</p>

# Workbench Labs

Workbench Labs is an open-source native macOS developer utility workbench. It is local-first, built with SwiftUI and Swift Package Manager, and designed to bring everyday developer transforms, inspectors, file tools, and media/PDF utilities into one offline app.

## Highlights

- Native macOS app for macOS 14+
- Searchable tool sidebar, clipboard inspection, menu bar access, and macOS Services integration
- Swift-native tools for timestamps, Base64, URL/query parsing, hashes, UUIDs, QR codes, PDF page editing, multilingual PDF OCR, image conversion, image metadata scrubbing, video conversion, and more
- Bundled JavaScript runtime for mature formatters and converters such as JSON, HTML, CSS, JavaScript, XML, YAML, SQL, Markdown, diff, and HTML/SVG to JSX
- Local file workflows for PDF split/merge/page editing, metadata scrubbing, image conversion, batch image resizing, image GPS removal, and video/audio extraction
- No hosted service requirement for normal tool execution

## Screenshots

![Workbench Labs app overview](docs/assets/screenshots/app-overview.svg)

![JSON formatter and validator](docs/assets/screenshots/json-workbench.svg)

![PDF and media tools](docs/assets/screenshots/pdf-media-tools.svg)

## Complete Feature Inventory

Workbench Labs currently ships **37 local tools** across the app's searchable sidebar categories.

### Shared App Workflows

- Searchable grouped sidebar for quickly finding tools.
- Clipboard inspection, paste-from-clipboard buttons, copy output, and use-output-as-input flows.
- Smart clipboard routing for JSON, JWTs, Base64, UUIDs, timestamps, query strings, encoded URLs, and HTML entities.
- File open and drag/drop workflows for PDF, image, video, and QR-code files.
- Menu bar access, macOS Services integration, per-tool local settings, and local-first execution.
- Bundled offline JavaScript runtime for mature formatters, with Swift-native engines where practical.

### Inspect & Test

- **Unix Timestamp Converter**: converts Unix seconds, Unix milliseconds, ISO 8601 dates, and timestamp math into local time, UTC, relative time, Unix time, milliseconds, day/week/year fields, leap-year status, common local formats, and extra timezone rows.
- **RegExp Tester**: tests a regular expression against input text, supports case-insensitive matching, and reports matches and capture groups.
- **HTML Preview**: renders HTML locally in a locked-down WebView with JavaScript, navigation, and external requests disabled by default.
- **Text Diff Checker**: compares original and changed text blocks with a JS-backed semantic diff engine.
- **Markdown Preview**: renders Markdown to safe local HTML for documentation drafts and README snippets.
- **String Inspector**: reports character count, Unicode scalar count, UTF-8 bytes, UTF-16 units, line count, escaped output, and Unicode scalar details.

### Security

- **JWT Debugger**: decodes JWT header/payload/signature segments, formats JSON, shows algorithm/signature details, and verifies HS256, HS384, and HS512 signatures when a session-only HMAC secret is provided.
- **Secret Scanner & Redactor**: finds and optionally redacts API keys, bearer tokens, private keys, credentials, database URLs, and other secret-looking values.
- **Hash Generator**: generates MD5, SHA-1, SHA-256, SHA-384, and SHA-512 hashes, with an all-algorithms mode.

### Developer

- **JSON Schema Validator**: validates JSON documents against JSON Schema locally with bundled AJV, side-by-side document/schema editors, optional strict schema mode, and path-based validation errors.
- **.env Inspector & Comparator**: parses `.env` files, lists keys, duplicate keys, invalid lines, and secret-looking entries, compares two `.env` blocks, and redacts values while preserving key names.
- **Git Diff & Ignore Helper**: inspects repository status with read-only local git commands and tests `.gitignore` patterns, including wildcards, directory rules, anchored paths, and negated rules.

### Format & Convert

- **JSON Formatter & Validator**: validates, formats, repairs, minifies, sorts keys, supports JSON5 comments/trailing commas, preserves encoded strings/big numbers when compatible, and offers indentation controls.
- **HTML Beautifier & Minifier**: beautifies or minifies HTML, including embedded CSS and JavaScript handling through the bundled runtime.
- **CSS Beautifier & Minifier**: formats or compresses CSS with configurable indentation.
- **JavaScript Beautifier & Minifier**: formats or compresses JavaScript with configurable indentation.
- **XML Beautifier & Minifier**: formats or compacts XML and reports formatter syntax errors.
- **YAML to JSON Converter**: converts YAML documents to formatted JSON with configurable indentation.
- **JSON to YAML Converter**: converts JSON documents into YAML for configuration and deployment snippets.
- **HTML/SVG to JSX Converter**: converts copied HTML or SVG markup into JSX with a configurable component name.
- **SQL Formatter**: formats SQL for SQL, PostgreSQL, MySQL, and SQLite dialects with keyword-case and indentation controls.
- **Number Base Converter**: converts integers between binary, octal, decimal, and hexadecimal, with auto-detection for `0b`, `0o`, and `0x` prefixes.
- **String Case Converter**: converts words and identifiers to camelCase, PascalCase, snake_case, kebab-case, CONSTANT_CASE, and Title Case.

### API & Network

- **URL Encoder & Decoder**: percent-encodes and decodes URL components while preserving the expected URL structure behavior for component encoding.
- **Query String & URL Parser**: parses full URLs or raw query strings into structured JSON with scheme, host, path, fragment, and decoded query items.

### Encode & Decode

- **Base64 String Encode/Decode**: encodes and decodes standard or URL-safe Base64, auto-detects UTF-8 Base64, strips data URL prefixes, removes trailing null bytes, and keeps explicit encode mode deterministic.
- **HTML Entity Encoder & Decoder**: encodes and decodes named and numeric HTML entities for moving text between markup and plain text contexts.
- **Backslash Escaper & Unescaper**: escapes and unescapes common string literal sequences such as newlines, tabs, quotes, backslashes, and control characters.

### Generate & Crypto

- **UUID Generator & Decoder**: generates multiple UUIDs or inspects an existing UUID's version, variant, normalized lowercase form, uppercase form, and URN form.
- **Lorem Ipsum Generator**: generates placeholder words, sentences, or paragraphs, with count controls and optional seed words.
- **QR Code Reader & Generator**: generates QR code PNG output from text or reads QR codes from image file paths.

### PDF & Documents

- **PDF Toolkit**: inspects PDFs, extracts selectable text, scrubs metadata, merges PDFs, splits all or selected pages, extracts page ranges into one PDF, deletes pages, reorders pages, rotates pages, appends pages from other PDFs, writes output beside the source by default, and reveals generated files in Finder.
- **PDF OCR Text Extractor**: extracts text from scanned or image-based PDFs locally, supports English through Apple Vision and Hebrew or English+Hebrew through local Tesseract, supports page ranges, and reports processed pages, recognized lines, engine, languages, and confidence metadata.

### Image & Video

- **Image Converter**: inspects image dimensions, file size, type, and metadata, then converts to PNG, JPEG, HEIC, TIFF, or GIF with quality controls.
- **Batch Image Resizer & Compressor**: resizes multiple images by width, height, maximum dimension, or scale percentage, converts formats, controls quality, optionally strips metadata, and writes collision-safe outputs beside source images or into a selected folder.
- **Image Metadata Inspector**: inspects dimensions, frame count, DPI, color model, color profile, GPS metadata, privacy risk, and writes safer sharing copies with GPS metadata removed by default.
- **Video Converter**: inspects video streams, metadata, duration, and codecs, converts to MP4, MOV, WebM, or GIF, trims clips, extracts MP3/WAV/AAC audio, generates JPG/PNG thumbnails, and writes collision-safe outputs beside the source by default.

See the [complete feature guide](docs/FEATURES.md) for expanded workflow details and testing notes.

## Roadmap at a Glance

Planned future builds include certificate inspection, SQLite browsing, HTTP request tooling, cURL import/export, OpenAPI exploration, archive inspection, cron expression explanation, and dependency lockfile inspection.

See the full future roadmap in [docs/FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md).

## Change Tracking

User-facing tool releases are tracked in [CHANGELOG.md](CHANGELOG.md).

## Agentic Roadmap Workflow

The repository includes a human-gated GitHub Actions workflow for building roadmap features on separate branches. Each roadmap item gets a `feature/<id>` branch, a draft integration PR, and a GitHub issue. Agent work targets the feature branch; promotion to `main` happens only after a local macOS app review and explicit approval.

See [docs/AGENTIC_DEVELOPMENT.md](docs/AGENTIC_DEVELOPMENT.md) for the full loop.

## Brand Assets

The app logo and icon are available in [docs/assets/brand](docs/assets/brand).

## Install

### One-Command Release Install

This downloads the latest GitHub Release, copies `WorkbenchLabs.app` to `/Applications`, verifies the bundle, and opens it:

```sh
curl -fsSL https://raw.githubusercontent.com/markes76/workbench-labs/main/script/install_release.sh | bash
```

### Source Install

This builds the app, copies it to `/Applications/WorkbenchLabs.app`, verifies the bundle, and opens it:

```sh
git clone https://github.com/markes76/workbench-labs.git
cd workbench-labs
./script/install.sh
```

You can also double-click:

```text
Install Workbench Labs.command
```

### Build Without Installing

```sh
npm install
./script/build_and_run.sh --build
open dist/WorkbenchLabs.app
```

### Create a Release Zip

```sh
./script/package_release.sh
```

The zip is written to `dist/WorkbenchLabs-macos.zip` by default. Set `ZIP_BASENAME=...` to override the filename.

## Requirements

- macOS 14 or newer
- Xcode command line tools or a compatible Swift 6 toolchain
- Node.js and npm for rebuilding the bundled formatter runtime
- Optional: `tesseract` and `tesseract-lang` for Hebrew PDF OCR
- Optional: `ffmpeg` and `ffprobe` for video conversion, WebM/GIF output, and MP3 extraction

Install optional OCR and video tooling with Homebrew:

```sh
brew install tesseract tesseract-lang
brew install ffmpeg
```

## Development

```sh
npm install
npm run build:runtime
swift build
swift test
npm run test:runtime
npm audit --omit=dev
```

Run and verify the app bundle:

```sh
./script/build_and_run.sh --verify
```

Install the local build:

```sh
./script/install.sh
```

## Distribution Notes

The current app is locally signed for developer distribution. It is not notarized yet, so downloaded builds may require the usual macOS security confirmation. A Developer ID signed and notarized release flow is planned before broad non-developer distribution.

## License

Workbench Labs is open source under the [MIT License](LICENSE).
