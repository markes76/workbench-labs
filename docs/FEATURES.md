# Workbench Labs Feature Guide

Workbench Labs is a native macOS developer workbench for local, offline utility tasks. The app keeps everyday conversions, inspectors, formatters, generators, PDF tools, and media tools in one searchable interface.

## Shared Workflows

- Searchable grouped sidebar for quickly finding tools.
- Clipboard button on text tools to paste current clipboard content into the active input.
- Smart clipboard inspection hooks for common developer formats such as JSON, JWTs, Base64, UUIDs, timestamps, query strings, encoded URLs, and HTML entities.
- Copy output and use output as input flows for chaining tools together.
- File open and drag/drop workflows for file-backed tools such as PDF, image, video, and QR reading.
- Native menu bar access and macOS Services integration for local inspection workflows.
- Per-tool options with defaults stored locally.
- Local-first execution. The normal tool path does not require a hosted service.
- Bundled JavaScript runtime for mature text formatters and converters, with Swift-native engines where practical.

## Inspect & Test

### Unix Timestamp Converter

Converts Unix seconds, Unix milliseconds, and ISO 8601 dates into local time, UTC, relative time, Unix time, milliseconds, day of year, week of year, leap-year status, and common local date formats.

Key features:
- Now, clipboard, clear, and copy controls.
- Input kind selector for seconds, milliseconds, and ISO 8601.
- Mathematical operators for quick timestamp arithmetic.
- Additional timezone rows for comparing the same instant across timezones.

### RegExp Tester

Tests a regular expression against input text and lists matches and capture groups.

Key features:
- Pattern field with sample email matcher.
- Case-insensitive option.
- Match count metadata.
- Secondary input support for pattern-oriented workflows.

### JWT Debugger

Decodes JSON Web Tokens and formats the header and payload as JSON.

Key features:
- Validates the three-part JWT shape.
- Decodes Base64URL header, payload, and signature segments.
- Shows algorithm and signature byte count.
- Verifies HS256, HS384, and HS512 signatures when an HMAC secret is provided.
- Keeps secrets in the active session only.

### HTML Preview

Renders HTML locally in a WebView preview.

Key features:
- JavaScript disabled by default.
- Navigation blocked by default.
- External requests blocked by default.
- Settings can explicitly allow JavaScript, navigation, or external requests for trusted content.

### Text Diff Checker

Compares two text blocks and produces a semantic diff.

Key features:
- Original and changed text inputs.
- JS-backed diff engine.
- Output suitable for reviewing text changes and copy/paste deltas.

### Markdown Preview

Renders Markdown to safe local HTML.

Key features:
- Markdown input and preview output.
- Local rendering through the bundled runtime.
- Useful for README snippets, release notes, and documentation drafts.

### String Inspector

Inspects raw strings for size, encoding, and escaped forms.

Key features:
- Character count, Unicode scalar count, UTF-8 byte count, UTF-16 unit count, and line count.
- Escaped string output.
- Unicode scalar listing.

### Secret Scanner & Redactor

Finds and optionally redacts tokens, private keys, credentials, and secret-looking config values.

Key features:
- Scan mode for a findings report.
- Redact mode for safe sharing.
- Patterns for API keys, bearer tokens, private keys, database URLs, and similar secrets.
- Diagnostics and confidence metadata.

## Format & Convert

### JSON Formatter & Validator

Validates, formats, repairs, minifies, and normalizes JSON.

Key features:
- Format and minify operations.
- Clipboard, sample, clear, and continuous mode controls.
- Auto-detect valid JSON.
- Optional JSON5-style comments and trailing commas.
- Auto repair for common invalid JSON issues.
- Sort keys option.
- Preserve encoded strings and big numbers option when compatible.
- Indent selector for 2 spaces, 4 spaces, 1 tab, and minified-style output.

### HTML Beautifier & Minifier

Beautifies or minifies HTML, including embedded CSS and JavaScript handling through the bundled formatter runtime.

Key features:
- Beautify and minify operations.
- Configurable indentation.
- Useful for cleaning HTML fragments before preview or JSX conversion.

### CSS Beautifier & Minifier

Formats or compresses CSS.

Key features:
- Beautify and minify operations.
- Configurable indentation.
- Keeps CSS transform work local.

### JavaScript Beautifier & Minifier

Formats or compresses JavaScript.

Key features:
- Beautify and minify operations.
- Configurable indentation.
- JS minification through the bundled runtime.

### XML Beautifier & Minifier

Formats or compacts XML.

Key features:
- Beautify and minify operations.
- Configurable indentation.
- XML syntax error reporting from the formatter runtime.

### YAML to JSON Converter

Converts YAML documents to formatted JSON.

Key features:
- YAML parsing through the bundled runtime.
- Configurable JSON indentation.
- Useful for config normalization and comparison.

### JSON to YAML Converter

Converts JSON documents to YAML.

Key features:
- JSON parsing and YAML serialization.
- Clean output for config files and deployment snippets.

### HTML/SVG to JSX Converter

Converts HTML or SVG markup into JSX.

Key features:
- Handles HTML and SVG input.
- Component name option.
- Useful for turning copied markup into React components.

### SQL Formatter

Formats SQL across common dialects.

Key features:
- SQL, PostgreSQL, MySQL, and SQLite dialect options.
- Keyword case control for upper, lower, or preserve.
- Configurable indentation.

### Number Base Converter

Converts integers between binary, octal, decimal, and hexadecimal.

Key features:
- Auto-detects `0b`, `0o`, and `0x` prefixes.
- Manual source base selector.
- Outputs all major bases together.

### String Case Converter

Converts words and identifiers across common programming case styles.

Key features:
- camelCase, PascalCase, snake_case, kebab-case, CONSTANT_CASE, and Title Case.
- All mode for comparing every result at once.

## Developer

### JSON Schema Validator

Validates JSON documents against JSON Schema locally with bundled AJV.

Key features:
- Side-by-side JSON document and JSON Schema editors.
- Uses the offline bundled runtime after dependencies are vendored.
- Reports valid documents with validation metadata.
- Lists invalid document errors with JSON instance paths and schema paths.
- Optional strict schema mode for tighter schema authoring checks.

### .env Inspector & Comparator

Parses, compares, and redacts `.env` files without exposing secret values by default.

Key features:
- Inspect mode lists keys, duplicate keys, invalid lines, and secret-looking entries.
- Compare mode reports added, removed, changed, missing, and unchanged keys across two `.env` blocks.
- Redact mode preserves key names and comments while replacing values with `<redacted>`.
- Values are hidden by default; optional show-values mode is available for trusted local review.

## Encode & Decode

### URL Encoder & Decoder

Percent-encodes and decodes URL components.

Key features:
- Encode and decode modes.
- Keeps reserved URL structure characters out of component-encoding output.
- Useful for query values, redirect URLs, and copied URL fragments.

### Base64 String Encode/Decode

Encodes and decodes standard or URL-safe Base64 text.

Key features:
- Encode and decode modes.
- Auto-detect UTF-8 Base64.
- Optional data URL prefix stripping.
- Optional trailing null byte removal.
- Optional URL-safe alphabet output.
- Correctly treats encode mode as encoding the current input, even if the current input is already Base64 text.

### Query String & URL Parser

Parses URLs and query strings into structured JSON.

Key features:
- Accepts full URLs or raw query strings.
- Extracts scheme, host, path, fragment, and query items.
- Decodes percent-encoded query values.

### HTML Entity Encoder & Decoder

Encodes and decodes named and numeric HTML entities.

Key features:
- Encode and decode modes.
- Handles text containing HTML-sensitive characters.
- Useful when moving text between markup and plain text contexts.

### Backslash Escaper & Unescaper

Escapes and unescapes common string literal sequences.

Key features:
- Escape and unescape modes.
- Handles newline, tab, quote, backslash, and common control sequences.
- Useful for logs, JSON-like snippets, and source-code string literals.

## Generate & Crypto

### UUID Generator & Decoder

Generates UUIDs or inspects an existing UUID.

Key features:
- Generate multiple UUIDs at once.
- Decode UUID version and variant.
- Outputs normalized lowercase UUID, uppercase UUID, and URN form.

### Lorem Ipsum Generator

Generates placeholder words, sentences, or paragraphs.

Key features:
- Words, sentences, and paragraphs modes.
- Count option.
- Optional seed words for custom placeholder vocabulary.

### QR Code Reader & Generator

Generates QR codes from text or reads QR codes from image files.

Key features:
- Generate mode outputs a PNG image.
- Read mode accepts an image file path.
- Copy/save image workflows from the app output surface.

### Hash Generator

Generates hashes for text input.

Key features:
- MD5, SHA-1, SHA-256, SHA-384, and SHA-512.
- All mode to produce every supported digest at once.
- Swift-native hashing through CryptoKit where available.

## PDF & Documents

### PDF Toolkit

Inspects, extracts text, scrubs metadata, merges, splits, and edits PDF pages locally.

Key features:
- Add or drop PDF files.
- Inspect PDF page count, document properties, and metadata fields including title, author, subject, creator, producer, keywords, and dates.
- Extract selectable text.
- Scrub selected metadata fields into a new PDF while preserving the original file.
- Merge multiple PDFs.
- Split all pages or selected page ranges such as `1-2, 5, 8`.
- Extract selected pages into one PDF.
- Delete selected pages while preserving the original file.
- Reorder pages with an explicit page sequence such as `3,1,2`.
- Rotate all pages or selected page ranges by 90, 180, or 270 degrees.
- Append pages from additional PDFs into a new file.
- Output files default to the source PDF folder unless an output location is provided.
- Reveal generated files in Finder.

### PDF OCR Text Extractor

Extracts text from scanned or image-based PDFs locally with Apple Vision or local Tesseract for Hebrew.

Key features:
- Accepts one PDF file path via paste, file open, or drag/drop.
- OCR runs locally on rendered PDF pages without uploading documents.
- Language selector supports English, Hebrew, and English + Hebrew.
- English OCR uses Apple Vision on macOS.
- Hebrew and English + Hebrew OCR use local Tesseract with Hebrew language data (`brew install tesseract tesseract-lang`).
- Page selector supports `all`, individual pages, and ranges such as `1,3-5`.
- Output is grouped by page and includes confidence summaries where the OCR engine provides confidence.
- Metadata reports processed page count, recognized text line count, OCR engine, selected recognition languages, and average confidence when available.

## Image & Video

### Image Converter

Inspects and converts image files locally with macOS ImageIO.

Key features:
- Inspect image dimensions, file size, type, and available metadata.
- Convert to PNG, JPEG, HEIC, TIFF, or GIF.
- Quality option for lossy formats.
- Output defaults beside the source image unless a file path is provided.

### Batch Image Resizer & Compressor

Processes multiple image files locally for resize, format conversion, compression, and metadata stripping.

Key features:
- Add or drop multiple image files.
- Resize by target width, target height, maximum dimension, or scale percentage.
- Output to PNG, JPEG, HEIC, TIFF, or the original source format when supported.
- Quality control for JPEG and HEIC output.
- Optional metadata stripping.
- Output defaults beside each source image unless an output folder is selected.
- Collision-safe output names avoid overwriting existing files.
- Reveal generated files in Finder.

### Image Metadata Inspector

Inspects image metadata locally and writes safer sharing copies with GPS location data removed.

Key features:
- Inspect image dimensions, frame count, DPI, color model, and color profile.
- Detect GPS location metadata and report latitude/longitude when present.
- Flag images that carry geolocation metadata as a privacy risk.
- Scrub GPS location metadata by default without changing the original file.
- Optional camera metadata, descriptive metadata, or full metadata removal.
- Output defaults beside each source image unless an output folder is selected.
- Collision-safe output names avoid overwriting existing files.
- Reveal generated scrubbed images in Finder.

### Video Converter

Inspects and converts video files locally with `ffmpeg` and `ffprobe` when installed.

Key features:
- Inspect video streams, metadata, duration, and codecs.
- Convert to MP4, MOV, WebM, or GIF.
- Trim clips with optional start and end time controls.
- Extract MP3, WAV, or AAC audio.
- Generate JPG or PNG thumbnails.
- Output defaults beside the source video unless a file path is provided.
- Collision-safe output names avoid overwriting existing files.
- Uses local binaries and does not upload media.

## Roadmap

The current roadmap is maintained in [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md). Planned areas include certificate inspection, SQLite browsing, HTTP request tooling, cURL import/export, OpenAPI exploration, archive inspection, cron expression explanation, and dependency lockfile inspection.
