import beautify from "js-beautify";
import { minify as minifyHTML } from "html-minifier-terser";
import CleanCSS from "clean-css";
import { minify as minifyJS } from "terser";
import xmlFormat from "xml-formatter";
import yaml from "js-yaml";
import { format as formatSQL } from "sql-formatter";
import MarkdownIt from "markdown-it";
import he from "he";
import { diff_match_patch } from "diff-match-patch";
import JSON5 from "json5";

const md = new MarkdownIt({
  html: false,
  linkify: true,
  typographer: true
});

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", chunk => data += chunk);
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

function normalizeJSON(input) {
  return typeof input === "string" ? input : "";
}

function result(output, metadata = {}) {
  return { ok: true, output, metadata };
}

function toCamelAttribute(name) {
  const map = {
    "class": "className",
    "for": "htmlFor",
    "tabindex": "tabIndex",
    "readonly": "readOnly",
    "maxlength": "maxLength",
    "cellpadding": "cellPadding",
    "cellspacing": "cellSpacing",
    "colspan": "colSpan",
    "rowspan": "rowSpan",
    "stroke-width": "strokeWidth",
    "stroke-linecap": "strokeLinecap",
    "stroke-linejoin": "strokeLinejoin",
    "fill-rule": "fillRule",
    "clip-rule": "clipRule",
    "viewbox": "viewBox"
  };
  const lower = name.toLowerCase();
  if (map[lower]) return map[lower];
  return name.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
}

function htmlToJSX(input, componentName = "GeneratedComponent") {
  const body = input
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/\s([a-zA-Z_:][-a-zA-Z0-9_:.]*)(=)/g, (_, name, equals) => ` ${toCamelAttribute(name)}${equals}`)
    .replace(/\s([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?=(\s|>|\/>))/g, (_, name) => ` ${toCamelAttribute(name)}`)
    .replace(/="([^"]*)"/g, (_, value) => `="${value.replace(/"/g, "&quot;")}"`);
  return [
    `export default function ${componentName}() {`,
    "  return (",
    ...body.split("\n").map(line => `    ${line}`),
    "  );",
    "}"
  ].join("\n");
}

function parseJSON5(input) {
  return JSON5.parse(input);
}

function stripJSONComments(input) {
  let output = "";
  let inString = false;
  let quote = "";
  for (let i = 0; i < input.length; i++) {
    const char = input[i];
    const next = input[i + 1];
    if (inString) {
      output += char;
      if (char === "\\") {
        output += input[++i] || "";
      } else if (char === quote) {
        inString = false;
      }
      continue;
    }
    if (char === "\"" || char === "'") {
      inString = true;
      quote = char;
      output += char;
      continue;
    }
    if (char === "/" && next === "/") {
      while (i < input.length && input[i] !== "\n") i++;
      output += "\n";
      continue;
    }
    if (char === "/" && next === "*") {
      i += 2;
      while (i < input.length && !(input[i] === "*" && input[i + 1] === "/")) i++;
      i++;
      continue;
    }
    output += char;
  }
  return output;
}

function repairJSON(input) {
  return stripJSONComments(input)
    .replace(/\bNone\b/g, "null")
    .replace(/\bTrue\b/g, "true")
    .replace(/\bFalse\b/g, "false")
    .replace(/([{,]\s*)([A-Za-z_$][\w$-]*)(\s*:)/g, '$1"$2"$3')
    .replace(/,\s*([}\]])/g, "$1");
}

function sortKeysDeep(value) {
  if (Array.isArray(value)) return value.map(sortKeysDeep);
  if (!value || typeof value !== "object") return value;
  return Object.keys(value).sort().reduce((result, key) => {
    result[key] = sortKeysDeep(value[key]);
    return result;
  }, {});
}

function rawJSONTokens(input) {
  const tokens = [];
  for (let i = 0; i < input.length; i++) {
    const char = input[i];
    if (/\s/.test(char)) continue;
    if ("{}[]:,".includes(char)) {
      tokens.push(char);
      continue;
    }
    if (char === "\"") {
      let value = char;
      i++;
      while (i < input.length) {
        value += input[i];
        if (input[i] === "\\") {
          i++;
          value += input[i] || "";
        } else if (input[i] === "\"") {
          break;
        }
        i++;
      }
      tokens.push(value);
      continue;
    }
    let value = char;
    while (i + 1 < input.length && !/\s/.test(input[i + 1]) && !"{}[]:,".includes(input[i + 1])) {
      value += input[++i];
    }
    tokens.push(value);
  }
  return tokens;
}

function jsonWhitespace(options) {
  if (options.indentStyle === "tab") return "\t";
  if (options.indentStyle === "4spaces") return 4;
  return Number(options.indent || 2);
}

function formatRawJSON(input, indentUnit, minify = false) {
  JSON.parse(input);
  const tokens = rawJSONTokens(input);
  if (minify) return tokens.join("");
  let level = 0;
  let output = "";
  const newline = () => "\n" + indentUnit.repeat(level);
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    switch (token) {
      case "{":
      case "[":
        output += token;
        if (tokens[i + 1] !== "}" && tokens[i + 1] !== "]") {
          level++;
          output += newline();
        }
        break;
      case "}":
      case "]":
        if (tokens[i - 1] !== "{" && tokens[i - 1] !== "[") {
          level--;
          output += newline();
        }
        output += token;
        break;
      case ":":
        output += ": ";
        break;
      case ",":
        output += ",";
        output += newline();
        break;
      default:
        output += token;
    }
  }
  return output;
}

function formatJSON(input, options = {}, minify = false) {
  const whitespace = jsonWhitespace(options);
  const rawIndentUnit = typeof whitespace === "number" ? " ".repeat(whitespace) : whitespace;
  const autoRepair = Boolean(options.autoRepair);
  const allowJSON5 = Boolean(options.allowJSON5);
  const sortKeys = Boolean(options.sortKeys);
  const preserveRaw = Boolean(options.preserveRaw) && !autoRepair && !sortKeys;

  if (preserveRaw) {
    return result(formatRawJSON(input, rawIndentUnit, minify), { valid: true, preserved: true });
  }

  let parser = "json";
  let repaired = false;
  let source = input;
  let parsed;

  try {
    parsed = JSON.parse(source);
  } catch (strictError) {
    if (autoRepair) {
      source = repairJSON(input);
      repaired = source !== input;
      try {
        parsed = JSON.parse(source);
        parser = "json";
      } catch {
        parsed = parseJSON5(source);
        parser = "json5";
      }
    } else if (allowJSON5) {
      parsed = parseJSON5(input);
      parser = "json5";
    } else {
      throw strictError;
    }
  }

  if (sortKeys) parsed = sortKeysDeep(parsed);
  return result(JSON.stringify(parsed, null, minify ? 0 : whitespace), {
    valid: true,
    parser,
    repaired
  });
}

async function run(request) {
  const input = normalizeJSON(request.input);
  const options = request.options || {};
  switch (request.tool) {
    case "json": {
      return formatJSON(input, options, false);
    }
    case "json-minify": {
      return formatJSON(input, options, true);
    }
    case "json5": {
      const parsed = parseJSON5(input);
      return result(JSON.stringify(parsed, null, Number(options.indent || 2)), { valid: true });
    }
    case "yaml-to-json": {
      const parsed = yaml.load(input);
      return result(JSON.stringify(parsed, null, Number(options.indent || 2)));
    }
    case "json-to-yaml": {
      const parsed = JSON.parse(input);
      return result(yaml.dump(parsed, { noRefs: true, lineWidth: Number(options.lineWidth || 100) }));
    }
    case "html-beautify":
      return result(beautify.html(input, { indent_size: Number(options.indent || 2), wrap_line_length: 120 }));
    case "html-minify":
      return result(await minifyHTML(input, {
        collapseWhitespace: true,
        removeComments: true,
        minifyCSS: true,
        minifyJS: true
      }));
    case "css-beautify":
      return result(beautify.css(input, { indent_size: Number(options.indent || 2) }));
    case "css-minify": {
      const minified = new CleanCSS({ level: 2 }).minify(input);
      if (minified.errors?.length) throw new Error(minified.errors.join("\n"));
      return result(minified.styles, { warnings: minified.warnings || [] });
    }
    case "js-beautify":
      return result(beautify.js(input, { indent_size: Number(options.indent || 2) }));
    case "js-minify": {
      const minified = await minifyJS(input, { module: Boolean(options.module) });
      if (!minified.code) throw new Error("Terser produced no output.");
      return result(minified.code);
    }
    case "xml-beautify":
      return result(xmlFormat(input, { indentation: " ".repeat(Number(options.indent || 2)), collapseContent: false }));
    case "xml-minify":
      return result(input.replace(/>\s+</g, "><").trim());
    case "sql-format":
      return result(formatSQL(input, {
        language: options.language || "sql",
        tabWidth: Number(options.indent || 2),
        keywordCase: options.keywordCase || "upper"
      }));
    case "markdown-preview":
      return result(md.render(input));
    case "html-entities-encode":
      return result(he.encode(input, { useNamedReferences: true }));
    case "html-entities-decode":
      return result(he.decode(input));
    case "text-diff": {
      const dmp = new diff_match_patch();
      const diffs = dmp.diff_main(input, String(options.secondaryInput || ""));
      dmp.diff_cleanupSemantic(diffs);
      const output = diffs.map(([kind, text]) => {
        const prefix = kind === 1 ? "+ " : kind === -1 ? "- " : "  ";
        return text.split(/\n/).map(line => prefix + line).join("\n");
      }).join("");
      return result(output, { diffCount: diffs.length });
    }
    case "html-to-jsx": {
      return result(htmlToJSX(input, String(options.componentName || "GeneratedComponent")));
    }
    default:
      throw new Error(`Unknown runtime tool: ${request.tool}`);
  }
}

async function main() {
  try {
    const raw = await readStdin();
    const request = raw.trim().length ? JSON.parse(raw) : {};
    const response = await run(request);
    process.stdout.write(JSON.stringify(response));
  } catch (error) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: error?.message || String(error),
      stack: error?.stack || ""
    }));
    process.exitCode = 1;
  }
}

main();
