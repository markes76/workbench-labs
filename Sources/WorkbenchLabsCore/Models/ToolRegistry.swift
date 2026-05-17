import Foundation

public enum ToolRegistry {
  public static let all: [ToolDefinition] = [
    ToolDefinition(
      id: .unixTimestamp,
      title: "Unix Timestamp Converter",
      subtitle: "Convert Unix seconds, milliseconds, ISO 8601 dates, and timestamp math.",
      category: .inspect,
      systemImage: "clock",
      inputPlaceholder: "Paste a timestamp or date string...",
      sampleInput: "1715356800",
      options: [
        ToolOption(key: "inputKind", label: "Input", kind: .picker, defaultValue: UnixTimeInputKind.unixSeconds.rawValue, choices: UnixTimeInputKind.allCases.map {
          .init($0.rawValue, $0.title)
        })
      ]
    ),
    ToolDefinition(
      id: .regexTester,
      title: "RegExp Tester",
      subtitle: "Test a regular expression against text and inspect matches.",
      category: .inspect,
      systemImage: "text.magnifyingglass",
      inputPlaceholder: "Paste the text to search...",
      sampleInput: "user@example.com\nsupport@example.org",
      capabilities: [.textInput, .secondaryInput],
      options: [
        ToolOption(key: "pattern", label: "Pattern", kind: .text, defaultValue: #"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}"#),
        ToolOption(key: "caseInsensitive", label: "Case insensitive", kind: .boolean, defaultValue: "false")
      ]
    ),
    ToolDefinition(
      id: .jwtDebugger,
      title: "JWT Debugger",
      subtitle: "Decode JSON Web Tokens and verify HS256/HS384/HS512 signatures.",
      category: .security,
      systemImage: "key.viewfinder",
      inputPlaceholder: "Paste a JWT...",
      sampleInput: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkRldiBXb3JrYmVuY2giLCJpYXQiOjE1MTYyMzkwMjJ9.invalid",
      options: [
        ToolOption(key: "secret", label: "HMAC secret", kind: .secureText, defaultValue: "")
      ]
    ),
    ToolDefinition(
      id: .htmlPreview,
      title: "HTML Preview",
      subtitle: "Render HTML locally with locked-down WebView defaults.",
      category: .inspect,
      systemImage: "safari",
      inputPlaceholder: "Paste HTML...",
      primaryActionTitle: "Preview",
      sampleInput: "<h1>Hello</h1><p>Rendered locally.</p>",
      capabilities: [.textInput, .htmlPreview],
      options: [
        ToolOption(key: "allowJavaScript", label: "Allow JavaScript", kind: .boolean, defaultValue: "false"),
        ToolOption(key: "allowNavigation", label: "Allow navigation", kind: .boolean, defaultValue: "false"),
        ToolOption(key: "allowExternalRequests", label: "Allow external requests", kind: .boolean, defaultValue: "false")
      ]
    ),
    ToolDefinition(
      id: .textDiff,
      title: "Text Diff Checker",
      subtitle: "Compare two text blocks with semantic cleanup.",
      category: .inspect,
      systemImage: "arrow.left.arrow.right",
      inputPlaceholder: "Original text...",
      sampleInput: "The quick brown fox\njumps over the lazy dog.",
      capabilities: [.textInput, .secondaryInput],
      options: [
        ToolOption(key: "secondaryInput", label: "Changed text", kind: .text, defaultValue: "The quick red fox\njumps over a lazy dog.")
      ]
    ),
    ToolDefinition(
      id: .markdownPreview,
      title: "Markdown Preview",
      subtitle: "Render Markdown to safe local HTML.",
      category: .inspect,
      systemImage: "doc.richtext",
      inputPlaceholder: "Paste Markdown...",
      primaryActionTitle: "Preview",
      sampleInput: "# Workbench Labs\n\n- Native macOS\n- Local tools",
      capabilities: [.textInput, .htmlPreview]
    ),
    ToolDefinition(
      id: .stringInspector,
      title: "String Inspector",
      subtitle: "Inspect length, bytes, lines, code points, and escaped forms.",
      category: .inspect,
      systemImage: "character.cursor.ibeam",
      inputPlaceholder: "Paste a string...",
      sampleInput: "Hello, 世界\n"
    ),
    ToolDefinition(
      id: .secretScanner,
      title: "Secret Scanner & Redactor",
      subtitle: "Find and redact tokens, private keys, credentials, and secret-looking config values.",
      category: .security,
      systemImage: "shield.lefthalf.filled.badge.checkmark",
      inputPlaceholder: "Paste logs, headers, .env files, stack traces, or config...",
      primaryActionTitle: "Scan",
      sampleInput: "API_KEY=EXAMPLE_API_KEY_DO_NOT_USE\nAuthorization: Bearer EXAMPLE_TOKEN_DO_NOT_USE\nDATABASE_URL=postgres://user:password@example.com/app",
      options: [
        operationOption([("scan", "Scan"), ("redact", "Redact")], defaultValue: "scan")
      ]
    ),
    ToolDefinition(
      id: .jsonFormatter,
      title: "JSON Formatter & Validator",
      subtitle: "Validate, format, minify, and normalize JSON.",
      category: .format,
      systemImage: "curlybraces.square",
      inputPlaceholder: "Paste JSON...",
      sampleInput: #"{"name":"WorkbenchLabs","tools":[1,2,3]}"#,
      options: [
        operationOption([("format", "Format"), ("minify", "Minify")]),
        ToolOption(key: "inputMode", label: "Mode", kind: .picker, defaultValue: "json", choices: [
          .init("json", "JSON")
        ]),
        ToolOption(key: "autoDetect", label: "Auto detect valid JSON", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "allowJSON5", label: "Allow comments and trailing commas", kind: .boolean, defaultValue: "false"),
        ToolOption(key: "autoRepair", label: "Auto repair invalid JSON", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "continuous", label: "Continuous Mode", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "sortKeys", label: "Sort keys", kind: .boolean, defaultValue: "false"),
        ToolOption(key: "preserveRaw", label: "Preserve encoded strings and big numbers", kind: .boolean, defaultValue: "false"),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .htmlFormatter,
      title: "HTML Beautifier & Minifier",
      subtitle: "Beautify or minify HTML with embedded CSS/JS handling.",
      category: .format,
      systemImage: "chevron.left.forwardslash.chevron.right",
      inputPlaceholder: "Paste HTML...",
      sampleInput: "<div><h1>Hello</h1><p>World</p></div>",
      options: [
        operationOption([("beautify", "Beautify"), ("minify", "Minify")]),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .cssFormatter,
      title: "CSS Beautifier & Minifier",
      subtitle: "Format or compress CSS.",
      category: .format,
      systemImage: "paintbrush",
      inputPlaceholder: "Paste CSS...",
      sampleInput: "body{color:#222}.button{display:flex;gap:8px}",
      options: [
        operationOption([("beautify", "Beautify"), ("minify", "Minify")]),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .javascriptFormatter,
      title: "JavaScript Beautifier & Minifier",
      subtitle: "Format or compress JavaScript.",
      category: .format,
      systemImage: "curlybraces",
      inputPlaceholder: "Paste JavaScript...",
      sampleInput: "function hello(name){return `Hello ${name}`}",
      options: [
        operationOption([("beautify", "Beautify"), ("minify", "Minify")]),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .xmlFormatter,
      title: "XML Beautifier & Minifier",
      subtitle: "Format or compact XML.",
      category: .format,
      systemImage: "doc.badge.gearshape",
      inputPlaceholder: "Paste XML...",
      sampleInput: "<root><item id=\"1\">Value</item></root>",
      options: [
        operationOption([("beautify", "Beautify"), ("minify", "Minify")]),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .yamlToJson,
      title: "YAML to JSON Converter",
      subtitle: "Convert YAML documents to formatted JSON.",
      category: .format,
      systemImage: "arrow.triangle.branch",
      inputPlaceholder: "Paste YAML...",
      sampleInput: "name: WorkbenchLabs\ntools:\n  - json\n  - yaml",
      options: [indentOption()]
    ),
    ToolDefinition(
      id: .jsonToYaml,
      title: "JSON to YAML Converter",
      subtitle: "Convert JSON documents to YAML.",
      category: .format,
      systemImage: "arrow.triangle.merge",
      inputPlaceholder: "Paste JSON...",
      sampleInput: #"{"name":"WorkbenchLabs","tools":["json","yaml"]}"#
    ),
    ToolDefinition(
      id: .htmlToJSX,
      title: "HTML/SVG to JSX Converter",
      subtitle: "Convert HTML or SVG markup into JSX.",
      category: .format,
      systemImage: "swift",
      inputPlaceholder: "Paste HTML or SVG...",
      sampleInput: #"<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>"#,
      options: [
        ToolOption(key: "componentName", label: "Component name", kind: .text, defaultValue: "GeneratedComponent")
      ]
    ),
    ToolDefinition(
      id: .sqlFormatter,
      title: "SQL Formatter",
      subtitle: "Format SQL for multiple dialects.",
      category: .format,
      systemImage: "tablecells",
      inputPlaceholder: "Paste SQL...",
      sampleInput: "select id,name from users where active=1 order by name",
      options: [
        ToolOption(key: "language", label: "Dialect", kind: .picker, defaultValue: "sql", choices: [
          .init("sql", "SQL"), .init("postgresql", "PostgreSQL"), .init("mysql", "MySQL"), .init("sqlite", "SQLite")
        ]),
        ToolOption(key: "keywordCase", label: "Keyword case", kind: .picker, defaultValue: "upper", choices: [
          .init("upper", "UPPER"), .init("lower", "lower"), .init("preserve", "Preserve")
        ]),
        indentOption()
      ]
    ),
    ToolDefinition(
      id: .numberBase,
      title: "Number Base Converter",
      subtitle: "Convert integers between binary, octal, decimal, and hex.",
      category: .format,
      systemImage: "number",
      inputPlaceholder: "Paste a number...",
      sampleInput: "0x2A",
      options: [
        ToolOption(key: "sourceBase", label: "Source base", kind: .picker, defaultValue: "auto", choices: [
          .init("auto", "Auto"), .init("2", "Binary"), .init("8", "Octal"), .init("10", "Decimal"), .init("16", "Hex")
        ])
      ]
    ),
    ToolDefinition(
      id: .stringCase,
      title: "String Case Converter",
      subtitle: "Convert between camel, pascal, snake, kebab, title, and constant case.",
      category: .format,
      systemImage: "textformat.abc",
      inputPlaceholder: "Paste words or identifiers...",
      sampleInput: "hello world_example",
      options: [
        operationOption([
          ("all", "All"), ("camel", "camelCase"), ("pascal", "PascalCase"), ("snake", "snake_case"),
          ("kebab", "kebab-case"), ("constant", "CONSTANT_CASE"), ("title", "Title Case")
        ], defaultValue: "all")
      ]
    ),
    ToolDefinition(
      id: .urlCodec,
      title: "URL Encoder & Decoder",
      subtitle: "Percent-encode and decode URL components.",
      category: .apiNetwork,
      systemImage: "link",
      inputPlaceholder: "Paste URL text...",
      sampleInput: "hello world?x=1&y=two words",
      options: [operationOption([("encode", "Encode"), ("decode", "Decode")])]
    ),
    ToolDefinition(
      id: .base64Codec,
      title: "Base64 String Encode/Decode",
      subtitle: "Encode and decode standard or URL-safe Base64.",
      category: .encode,
      systemImage: "textformat.123",
      inputPlaceholder: "Paste text or Base64...",
      sampleInput: "WorkbenchLabs",
      options: [
        operationOption([("encode", "Encode"), ("decode", "Decode")]),
        ToolOption(key: "autoDetectUTF8", label: "Auto detect UTF-8 Base64", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "stripDataURLPrefix", label: "Remove data URL prefix", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "removeTrailingNullByte", label: "Remove trailing null byte", kind: .boolean, defaultValue: "true"),
        ToolOption(key: "urlSafe", label: "URL-safe alphabet", kind: .boolean, defaultValue: "false")
      ]
    ),
    ToolDefinition(
      id: .queryParser,
      title: "Query String & URL Parser",
      subtitle: "Parse URLs and query strings into structured JSON.",
      category: .apiNetwork,
      systemImage: "list.bullet.rectangle",
      inputPlaceholder: "Paste a URL or query string...",
      sampleInput: "https://example.com/search?q=dev%20tools&page=1"
    ),
    ToolDefinition(
      id: .htmlEntities,
      title: "HTML Entity Encoder & Decoder",
      subtitle: "Encode and decode named and numeric HTML entities.",
      category: .encode,
      systemImage: "ampersand",
      inputPlaceholder: "Paste text...",
      sampleInput: "<div class=\"note\">Tom & Jerry</div>",
      options: [operationOption([("encode", "Encode"), ("decode", "Decode")])]
    ),
    ToolDefinition(
      id: .backslashCodec,
      title: "Backslash Escaper & Unescaper",
      subtitle: "Escape and unescape common string literal sequences.",
      category: .encode,
      systemImage: "backslash",
      inputPlaceholder: "Paste text...",
      sampleInput: "Line one\nLine two\tTabbed",
      options: [operationOption([("escape", "Escape"), ("unescape", "Unescape")])]
    ),
    ToolDefinition(
      id: .uuidTool,
      title: "UUID Generator & Decoder",
      subtitle: "Generate UUIDs and inspect version/variant fields.",
      category: .generate,
      systemImage: "tag",
      inputPlaceholder: "Paste a UUID to inspect, or leave empty to generate...",
      primaryActionTitle: "Generate / Decode",
      sampleInput: "550e8400-e29b-41d4-a716-446655440000",
      options: [
        ToolOption(key: "count", label: "Count", kind: .integer, defaultValue: "4", minimumValue: 1, maximumValue: 100)
      ]
    ),
    ToolDefinition(
      id: .loremIpsum,
      title: "Lorem Ipsum Generator",
      subtitle: "Generate placeholder words, sentences, or paragraphs.",
      category: .generate,
      systemImage: "paragraphsign",
      inputPlaceholder: "Optional seed words...",
      primaryActionTitle: "Generate",
      capabilities: [.generatedOutput],
      options: [
        operationOption([("paragraphs", "Paragraphs"), ("sentences", "Sentences"), ("words", "Words")], defaultValue: "paragraphs"),
        ToolOption(key: "count", label: "Count", kind: .integer, defaultValue: "3", minimumValue: 1, maximumValue: 100)
      ]
    ),
    ToolDefinition(
      id: .qrCode,
      title: "QR Code Reader & Generator",
      subtitle: "Generate QR codes from text or read QR codes from image files.",
      category: .generate,
      systemImage: "qrcode",
      inputPlaceholder: "Text to encode, or path to an image when reading...",
      primaryActionTitle: "Generate / Read",
      sampleInput: "https://example.com",
      capabilities: [.textInput, .imageOutput, .fileInput],
      options: [
        operationOption([("generate", "Generate"), ("read", "Read image path")])
      ]
    ),
    ToolDefinition(
      id: .hashGenerator,
      title: "Hash Generator",
      subtitle: "Generate MD5, SHA-1, SHA-256, SHA-384, and SHA-512 hashes.",
      category: .security,
      systemImage: "number.square",
      inputPlaceholder: "Paste text to hash...",
      sampleInput: "WorkbenchLabs",
      options: [
        ToolOption(key: "algorithm", label: "Algorithm", kind: .picker, defaultValue: "all", choices: [
          .init("all", "All"), .init("md5", "MD5"), .init("sha1", "SHA-1"),
          .init("sha256", "SHA-256"), .init("sha384", "SHA-384"), .init("sha512", "SHA-512")
        ])
      ]
    ),
    ToolDefinition(
      id: .pdfToolkit,
      title: "PDF Toolkit",
      subtitle: "Inspect, extract text, merge, and split PDFs locally.",
      category: .document,
      systemImage: "doc.richtext",
      inputPlaceholder: "Paste one PDF path per line, or drop PDF files...",
      primaryActionTitle: "Process PDF",
      sampleInput: "",
      capabilities: [.textInput, .fileInput],
      options: [
        operationOption([
          ("inspect", "Inspect"),
          ("extractText", "Extract Text"),
          ("merge", "Merge"),
          ("split", "Split Pages")
        ]),
        ToolOption(key: "pages", label: "Pages", kind: .text, defaultValue: "all"),
        ToolOption(key: "outputPath", label: "Output file", kind: .text, defaultValue: ""),
        ToolOption(key: "outputDirectory", label: "Output folder", kind: .text, defaultValue: "")
      ]
    ),
    ToolDefinition(
      id: .imageConverter,
      title: "Image Converter",
      subtitle: "Inspect and convert images locally with macOS ImageIO.",
      category: .media,
      systemImage: "photo",
      inputPlaceholder: "Paste or drop an image file path...",
      primaryActionTitle: "Process Image",
      sampleInput: "",
      capabilities: [.textInput, .fileInput],
      options: [
        operationOption([("inspect", "Inspect"), ("convert", "Convert")]),
        ToolOption(key: "outputFormat", label: "Format", kind: .picker, defaultValue: "png", choices: [
          .init("png", "PNG"), .init("jpeg", "JPEG"), .init("heic", "HEIC"), .init("tiff", "TIFF"), .init("gif", "GIF")
        ]),
        ToolOption(key: "quality", label: "Quality", kind: .integer, defaultValue: "90", minimumValue: 1, maximumValue: 100),
        ToolOption(key: "outputPath", label: "Output file", kind: .text, defaultValue: "")
      ]
    ),
    ToolDefinition(
      id: .videoConverter,
      title: "Video Converter",
      subtitle: "Inspect and transcode video locally with ffmpeg when installed.",
      category: .media,
      systemImage: "film",
      inputPlaceholder: "Paste or drop a video file path...",
      primaryActionTitle: "Process Video",
      sampleInput: "",
      capabilities: [.textInput, .fileInput],
      options: [
        operationOption([("info", "Info"), ("convert", "Convert")]),
        ToolOption(key: "outputFormat", label: "Format", kind: .picker, defaultValue: "mp4", choices: [
          .init("mp4", "MP4"), .init("mov", "MOV"), .init("webm", "WebM"), .init("gif", "GIF"), .init("mp3", "MP3")
        ]),
        ToolOption(key: "outputPath", label: "Output file", kind: .text, defaultValue: "")
      ]
    )
  ]

  public static let byID: [ToolID: ToolDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

  public static func definition(for id: ToolID) -> ToolDefinition {
    byID[id] ?? all[0]
  }

  public static func grouped() -> [(ToolCategory, [ToolDefinition])] {
    ToolCategory.allCases.map { category in
      (category, all.filter { $0.category == category })
    }
  }

  private static func operationOption(
    _ values: [(String, String)],
    defaultValue: String? = nil
  ) -> ToolOption {
    ToolOption(
      key: "operation",
      label: "Operation",
      kind: .operation,
      defaultValue: defaultValue ?? values[0].0,
      choices: values.map { .init($0.0, $0.1) }
    )
  }

  private static func indentOption() -> ToolOption {
    ToolOption(key: "indent", label: "Indent", kind: .integer, defaultValue: "2", minimumValue: 0, maximumValue: 8)
  }
}
