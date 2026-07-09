#!/usr/bin/env node
"use strict";

const http = require("node:http");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const rootDir = path.resolve(__dirname, "..");
const publicDir = path.join(__dirname, "public");
const configPath = process.env.CODEX_DONE_CONFIG || path.join(os.homedir(), ".codex-done", "config.json");
const envPath = process.env.CODEX_DONE_ENV || path.join(os.homedir(), ".codex-done", "env");
const eventsPath = process.env.CODEX_DONE_EVENTS || path.join(os.homedir(), ".codex-done", "events.jsonl");
const notifyStatePath = process.env.CODEX_DONE_NOTIFY_STATE || path.join(os.homedir(), ".codex-done", "notify-state.json");
const cliPath = process.env.CODEX_DONE_CLI_PATH || path.join(rootDir, "codex-done");
const launchAgentPath = path.join(os.homedir(), "Library", "LaunchAgents", "local.codexdone.app.plist");
const appBundlePath = path.join(rootDir, "dist", "CodexDone.app");
const inheritedOpenAIKey = process.env.OPENAI_API_KEY || "";
let localOpenAIKeyOverride = false;

const defaultConfig = {
  version: 1,
  alert: {
    mode: "voice_and_sound",
    desktopNotification: true,
    mobilePush: true,
  },
  sound: {
    provider: "macos",
    name: "Ping",
    repeatCount: 1,
    customFilePath: null,
  },
  voice: {
    provider: "macos",
    language: "zh-CN",
    voiceName: null,
    rate: 180,
    messageTemplate: "{project}: {message}",
  },
  mobile: {
    provider: "ntfy",
    topic: "",
    title: "Codex 任务完成",
  },
  events: {
    taskCompleted: null,
    testPassed: null,
    testFailed: null,
    needsAttention: null,
  },
  queue: {
    mergeNotifications: true,
    batchDelaySeconds: 2,
    retentionCount: 200,
  },
  futureVoice: {
    provider: null,
    voiceId: null,
    genderPreference: null,
    style: null,
    cacheAudio: true,
  },
};

const contentTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
]);

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function mergeConfig(value) {
  const merged = clone(defaultConfig);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return merged;
  }

  for (const key of Object.keys(merged)) {
    if (value[key] && typeof value[key] === "object" && !Array.isArray(value[key]) && merged[key] && typeof merged[key] === "object") {
      merged[key] = { ...merged[key], ...value[key] };
    } else if (Object.prototype.hasOwnProperty.call(value, key)) {
      merged[key] = value[key];
    }
  }
  return normalizeConfig(merged);
}

function stringValue(value, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

function optionalString(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function booleanValue(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}

function integerValue(value, fallback, min, max) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}

function normalizeConfig(input) {
  const value = input && typeof input === "object" ? input : {};
  const alert = value.alert && typeof value.alert === "object" ? value.alert : {};
  const sound = value.sound && typeof value.sound === "object" ? value.sound : {};
  const voice = value.voice && typeof value.voice === "object" ? value.voice : {};
  const mobile = value.mobile && typeof value.mobile === "object" ? value.mobile : {};
  const events = value.events && typeof value.events === "object" ? value.events : {};
  const queue = value.queue && typeof value.queue === "object" ? value.queue : {};
  const futureVoice = value.futureVoice && typeof value.futureVoice === "object" ? value.futureVoice : {};

  const modes = new Set(["silent", "sound", "voice", "voice_and_sound"]);
  const mode = modes.has(alert.mode) ? alert.mode : defaultConfig.alert.mode;
  const normalizeEvent = (event) => {
    if (!event || typeof event !== "object" || Array.isArray(event)) {
      return null;
    }
    return {
      mode: modes.has(event.mode) ? event.mode : null,
      messageTemplate: optionalString(event.messageTemplate),
      soundName: optionalString(event.soundName),
    };
  };

  return {
    version: integerValue(value.version, 1, 1, 99),
    alert: {
      mode,
      desktopNotification: booleanValue(alert.desktopNotification, defaultConfig.alert.desktopNotification),
      mobilePush: booleanValue(alert.mobilePush, defaultConfig.alert.mobilePush),
    },
    sound: {
      provider: stringValue(sound.provider, "macos") || "macos",
      name: stringValue(sound.name, "Ping") || "Ping",
      repeatCount: integerValue(sound.repeatCount, 1, 1, 10),
      customFilePath: optionalString(sound.customFilePath),
    },
    voice: {
      provider: stringValue(voice.provider, "macos") || "macos",
      language: stringValue(voice.language, "zh-CN") || "zh-CN",
      voiceName: optionalString(voice.voiceName),
      rate: integerValue(voice.rate, 180, 80, 360),
      messageTemplate: stringValue(voice.messageTemplate, "{project}: {message}") || "{project}: {message}",
    },
    mobile: {
      provider: stringValue(mobile.provider, "ntfy") || "ntfy",
      topic: stringValue(mobile.topic, ""),
      title: stringValue(mobile.title, "Codex 任务完成") || "Codex 任务完成",
    },
    events: {
      taskCompleted: normalizeEvent(events.taskCompleted),
      testPassed: normalizeEvent(events.testPassed),
      testFailed: normalizeEvent(events.testFailed),
      needsAttention: normalizeEvent(events.needsAttention),
    },
    queue: {
      mergeNotifications: booleanValue(queue.mergeNotifications, true),
      batchDelaySeconds: integerValue(queue.batchDelaySeconds, 2, 0, 60),
      retentionCount: integerValue(queue.retentionCount, 200, 1, 5000),
    },
    futureVoice: {
      provider: optionalString(futureVoice.provider),
      voiceId: optionalString(futureVoice.voiceId),
      genderPreference: optionalString(futureVoice.genderPreference),
      style: optionalString(futureVoice.style),
      cacheAudio: booleanValue(futureVoice.cacheAudio, true),
    },
  };
}

async function loadConfig() {
  try {
    const raw = await fsp.readFile(configPath, "utf8");
    return {
      config: mergeConfig(JSON.parse(raw)),
      exists: true,
      loaded: true,
      error: null,
    };
  } catch (error) {
    return {
      config: clone(defaultConfig),
      exists: fs.existsSync(configPath),
      loaded: false,
      error: error.code === "ENOENT" ? null : error.message,
    };
  }
}

async function saveConfig(config) {
  const normalized = normalizeConfig(config);
  await fsp.mkdir(path.dirname(configPath), { recursive: true });
  const tempPath = `${configPath}.${process.pid}.tmp`;
  await fsp.writeFile(tempPath, `${JSON.stringify(normalized, null, 2)}\n`, "utf8");
  await fsp.rename(tempPath, configPath);
  return normalized;
}

function parseEnvValue(rawValue) {
  let value = String(rawValue || "").trim();
  if (!value) {
    return "";
  }
  const quote = value[0];
  if ((quote === "'" || quote === '"') && value.endsWith(quote)) {
    value = value.slice(1, -1);
  }
  if (quote === '"') {
    value = value.replaceAll('\\"', '"').replaceAll("\\\\", "\\");
  }
  if (quote === "'") {
    value = value.replaceAll("'\\''", "'");
  }
  return value;
}

function parseEnvText(text) {
  const values = {};
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) {
      continue;
    }
    values[match[1]] = parseEnvValue(match[2]);
  }
  return values;
}

async function readLocalEnv() {
  try {
    return parseEnvText(await fsp.readFile(envPath, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") {
      return {};
    }
    throw error;
  }
}

function quoteEnvValue(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function serializeEnv(values) {
  const lines = Object.keys(values)
    .filter((key) => /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) && values[key] !== null && values[key] !== undefined && String(values[key]) !== "")
    .sort()
    .map((key) => `${key}=${quoteEnvValue(values[key])}`);
  return lines.length > 0 ? `${lines.join("\n")}\n` : "";
}

async function writeLocalEnv(values) {
  await fsp.mkdir(path.dirname(envPath), { recursive: true });
  const body = serializeEnv(values);
  if (!body) {
    await fsp.rm(envPath, { force: true });
    return;
  }
  const tempPath = `${envPath}.${process.pid}.tmp`;
  await fsp.writeFile(tempPath, body, { encoding: "utf8", mode: 0o600 });
  await fsp.chmod(tempPath, 0o600);
  await fsp.rename(tempPath, envPath);
  await fsp.chmod(envPath, 0o600);
}

function maskSecret(value) {
  if (!value) {
    return "";
  }
  if (value.length <= 8) {
    return "••••";
  }
  return `${value.slice(0, 3)}…${value.slice(-4)}`;
}

async function openAIKeyStatus() {
  const localEnv = await readLocalEnv();
  const localKey = optionalString(localEnv.OPENAI_API_KEY);
  if (localOpenAIKeyOverride && localKey) {
    process.env.OPENAI_API_KEY = localKey;
  } else if (inheritedOpenAIKey) {
    process.env.OPENAI_API_KEY = inheritedOpenAIKey;
  } else if (localKey) {
    process.env.OPENAI_API_KEY = localKey;
  } else {
    delete process.env.OPENAI_API_KEY;
  }

  const source = localOpenAIKeyOverride && localKey
    ? "env-file"
    : inheritedOpenAIKey
      ? "environment"
      : localKey
        ? "env-file"
        : null;
  const currentKey = process.env.OPENAI_API_KEY || "";
  return {
    configured: Boolean(currentKey),
    source,
    envPath,
    masked: maskSecret(currentKey),
  };
}

function executableExists(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

async function pathExists(filePath) {
  try {
    await fsp.access(filePath, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function directoryWritableFor(filePath) {
  const directory = path.dirname(filePath);
  try {
    await fsp.mkdir(directory, { recursive: true });
    await fsp.access(directory, fs.constants.W_OK);
    return { ok: true, directory, error: null };
  } catch (error) {
    return { ok: false, directory, error: error.message };
  }
}

function healthCheck(id, label, status, summary, detail = "") {
  return { id, label, status, summary, detail };
}

function healthCounts(checks) {
  return checks.reduce((counts, check) => {
    counts[check.status] = (counts[check.status] || 0) + 1;
    return counts;
  }, { pass: 0, warn: 0, fail: 0 });
}

async function healthReport() {
  const configState = await loadConfig();
  const openAIKey = await openAIKeyStatus();
  const checks = [];
  const configDirectory = await directoryWritableFor(configPath);
  const eventsDirectory = await directoryWritableFor(eventsPath);
  const cliAvailable = executableExists(cliPath);
  const topicConfigured = Boolean(process.env.CODEX_NOTIFY_TOPIC || configState.config.mobile.topic);
  const futureProvider = configState.config.futureVoice.provider || "";

  checks.push(healthCheck(
    "cli",
    "codex-done 命令",
    cliAvailable ? "pass" : "fail",
    cliAvailable ? "可执行脚本可用" : "未找到可执行脚本",
    cliPath
  ));

  checks.push(healthCheck(
    "config",
    "配置文件",
    configState.error ? "fail" : configState.exists ? "pass" : "warn",
    configState.error
      ? "配置文件读取失败"
      : configState.exists
        ? "配置文件已加载"
        : "尚未创建配置文件，当前使用默认配置",
    configState.error || configPath
  ));

  checks.push(healthCheck(
    "config-directory",
    "配置目录",
    configDirectory.ok ? "pass" : "fail",
    configDirectory.ok ? "配置目录可写" : "配置目录不可写",
    configDirectory.error || configDirectory.directory
  ));

  checks.push(healthCheck(
    "say",
    "macOS say",
    executableExists("/usr/bin/say") ? "pass" : "fail",
    executableExists("/usr/bin/say") ? "本机语音命令可用" : "缺少 /usr/bin/say",
    "/usr/bin/say"
  ));

  checks.push(healthCheck(
    "osascript",
    "桌面通知",
    executableExists("/usr/bin/osascript") ? "pass" : "fail",
    executableExists("/usr/bin/osascript") ? "通知中心脚本命令可用" : "缺少 /usr/bin/osascript",
    "/usr/bin/osascript"
  ));

  checks.push(healthCheck(
    "afplay",
    "提示音播放",
    executableExists("/usr/bin/afplay") ? "pass" : "fail",
    executableExists("/usr/bin/afplay") ? "提示音播放命令可用" : "缺少 /usr/bin/afplay",
    "/usr/bin/afplay"
  ));

  checks.push(healthCheck(
    "events",
    "事件日志",
    eventsDirectory.ok ? "pass" : "fail",
    eventsDirectory.ok ? "事件日志目录可写" : "事件日志目录不可写",
    eventsDirectory.error || eventsPath
  ));

  checks.push(healthCheck(
    "ntfy",
    "手机推送 ntfy",
    configState.config.alert.mobilePush
      ? topicConfigured ? "pass" : "warn"
      : "warn",
    configState.config.alert.mobilePush
      ? topicConfigured ? "手机推送 Topic 已配置" : "手机推送已开启，但还没有 Topic"
      : "手机推送已关闭",
    configState.config.mobile.topic || process.env.CODEX_NOTIFY_TOPIC || "CODEX_NOTIFY_TOPIC / mobile.topic"
  ));

  const curlAvailable = executableExists("/usr/bin/curl");
  checks.push(healthCheck(
    "curl",
    "手机推送网络命令",
    curlAvailable ? "pass" : configState.config.alert.mobilePush && topicConfigured ? "fail" : "warn",
    curlAvailable
      ? "curl 可用，可发送 ntfy 请求"
      : "缺少 curl，手机推送将无法发送",
    "/usr/bin/curl"
  ));

  checks.push(healthCheck(
    "future-voice",
    "真人语音服务商",
    futureProvider === "openai"
      ? openAIKey.configured ? "pass" : "fail"
      : futureProvider ? "warn" : "pass",
    futureProvider === "openai"
      ? openAIKey.configured ? "OpenAI TTS 已具备 Key" : "已选择 OpenAI TTS，但还缺 API Key"
      : futureProvider
        ? "该服务商已保存为预留配置，当前 CLI 会回退到 macOS say"
        : "当前使用 macOS say，不需要云端 Key",
    futureProvider === "openai" ? envPath : (futureProvider || "macOS say")
  ));

  checks.push(healthCheck(
    "launch-agent",
    "开机启动",
    await pathExists(launchAgentPath) ? "pass" : "warn",
    await pathExists(launchAgentPath) ? "LaunchAgent 已安装" : "尚未安装 LaunchAgent，需手动启动 App",
    launchAgentPath
  ));

  checks.push(healthCheck(
    "app-bundle",
    "macOS App 包",
    await pathExists(appBundlePath) ? "pass" : "warn",
    await pathExists(appBundlePath) ? "dist 中已有 CodexDone.app" : "尚未构建 dist/CodexDone.app",
    appBundlePath
  ));

  checks.push(healthCheck(
    "web-preview",
    "Web Preview",
    "pass",
    "调试面板服务正在运行",
    `pid ${process.pid} · ${process.version}`
  ));

  const counts = healthCounts(checks);
  return {
    generatedAt: new Date().toISOString(),
    status: counts.fail > 0 ? "fail" : counts.warn > 0 ? "warn" : "pass",
    counts,
    checks,
  };
}

async function saveOpenAIKey(apiKey) {
  const trimmed = stringValue(apiKey, "").trim();
  if (!trimmed) {
    throw new Error("API Key 不能为空");
  }
  if (/[\r\n]/.test(trimmed)) {
    throw new Error("API Key 不能包含换行");
  }
  const values = await readLocalEnv();
  values.OPENAI_API_KEY = trimmed;
  await writeLocalEnv(values);
  process.env.OPENAI_API_KEY = trimmed;
  localOpenAIKeyOverride = true;
  return openAIKeyStatus();
}

async function clearOpenAIKey() {
  const values = await readLocalEnv();
  delete values.OPENAI_API_KEY;
  await writeLocalEnv(values);
  localOpenAIKeyOverride = false;
  if (inheritedOpenAIKey) {
    process.env.OPENAI_API_KEY = inheritedOpenAIKey;
  } else {
    delete process.env.OPENAI_API_KEY;
  }
  return openAIKeyStatus();
}

function jsonResponse(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function textResponse(res, statusCode, body, contentType = "text/plain; charset=utf-8") {
  res.writeHead(statusCode, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error("Request body is too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!body.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", reject);
  });
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: options.cwd || rootDir,
      env: {
        ...process.env,
        CODEX_DONE_CONFIG: configPath,
        CODEX_DONE_ENV: envPath,
        CODEX_DONE_EVENTS: eventsPath,
        CODEX_DONE_NOTIFY_STATE: notifyStatePath,
        ...(options.env || {}),
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const timeoutMs = options.timeoutMs || 30000;
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ ok: false, code: null, stdout, stderr: error.message, timedOut });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ ok: code === 0 && !timedOut, code, stdout, stderr, timedOut });
    });
  });
}

async function loadEvents(limit = 50) {
  try {
    const raw = await fsp.readFile(eventsPath, "utf8");
    const events = raw
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter((event) => event && typeof event === "object")
      .slice(-limit)
      .reverse();
    return {
      path: eventsPath,
      events,
      exists: true,
    };
  } catch (error) {
    if (error.code === "ENOENT") {
      return {
        path: eventsPath,
        events: [],
        exists: false,
      };
    }
    throw error;
  }
}

async function clearEvents() {
  await Promise.all([
    fsp.rm(eventsPath, { force: true }),
    fsp.rm(notifyStatePath, { force: true }),
  ]);
  return loadEvents();
}

function parseSayVoices(text) {
  return text
    .split(/\r?\n/)
    .map((line) => {
      const [leftPart, samplePart = ""] = line.split(/#(.+)/, 2);
      const left = (leftPart || "").trim();
      const match = left.match(/^(.+?)\s+([A-Za-z]{2,3}_[A-Za-z0-9]+)$/);
      if (!match) {
        return null;
      }
      return {
        name: match[1].trim(),
        languageCode: match[2].replace("_", "-"),
        sample: samplePart.trim(),
      };
    })
    .filter(Boolean);
}

async function availableVoices() {
  const result = await runProcess("/usr/bin/say", ["-v", "?"], { timeoutMs: 8000 });
  if (!result.ok) {
    return [];
  }
  return parseSayVoices(result.stdout);
}

async function availableSounds() {
  const directories = [
    path.join(os.homedir(), "Library", "Sounds"),
    "/System/Library/Sounds",
    "/Library/Sounds",
  ];
  const supportedExtensions = new Set([".aif", ".aiff", ".caf", ".mp3", ".wav"]);
  const seen = new Set();
  const sounds = [];

  for (const directory of directories) {
    let entries = [];
    try {
      entries = await fsp.readdir(directory, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (!entry.isFile()) {
        continue;
      }
      const extension = path.extname(entry.name).toLowerCase();
      if (!supportedExtensions.has(extension)) {
        continue;
      }
      const name = path.basename(entry.name, extension);
      if (seen.has(name)) {
        continue;
      }
      seen.add(name);
      sounds.push({
        name,
        path: path.join(directory, entry.name),
      });
    }
  }

  return sounds.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
}

async function resolveSoundPath(name, customFilePath) {
  if (customFilePath && fs.existsSync(customFilePath)) {
    return customFilePath;
  }
  const sounds = await availableSounds();
  return sounds.find((sound) => sound.name === name)?.path
    || sounds.find((sound) => sound.name === "Ping")?.path
    || "/System/Library/Sounds/Ping.aiff";
}

function codexRule() {
  return "每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `codex-done` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。普通完成使用默认事件；测试通过可用 `--event testPassed`，测试失败可用 `--event testFailed`，需要我处理时可用 `--event needsAttention`。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。";
}

async function serveStatic(req, res, pathname) {
  const normalizedPath = pathname === "/" ? "/index.html" : pathname;
  const filePath = path.resolve(publicDir, `.${normalizedPath}`);
  if (!filePath.startsWith(publicDir)) {
    textResponse(res, 403, "Forbidden");
    return;
  }
  try {
    const body = await fsp.readFile(filePath);
    const extension = path.extname(filePath);
    res.writeHead(200, {
      "Content-Type": contentTypes.get(extension) || "application/octet-stream",
      "Content-Length": body.length,
      "Cache-Control": "no-store",
    });
    res.end(body);
  } catch (error) {
    if (error.code === "ENOENT") {
      textResponse(res, 404, "Not found");
    } else {
      textResponse(res, 500, error.message);
    }
  }
}

async function handleApi(req, res, pathname) {
  try {
    if (req.method === "GET" && pathname === "/api/status") {
      const configState = await loadConfig();
      const openAIKey = await openAIKeyStatus();
      jsonResponse(res, 200, {
        configPath,
        cliPath,
        cliAvailable: fs.existsSync(cliPath),
        configExists: configState.exists,
        configLoaded: configState.loaded,
        configError: configState.error,
        openAIKeyConfigured: openAIKey.configured,
        openAIKeySource: openAIKey.source,
        openAIKeyMasked: openAIKey.masked,
        openAIKeyPath: envPath,
        eventsPath,
        notifyStatePath,
        ntfyTopicConfigured: Boolean(process.env.CODEX_NOTIFY_TOPIC || configState.config.mobile.topic),
        platform: process.platform,
        nodeVersion: process.version,
      });
      return;
    }

    if (req.method === "POST" && pathname === "/api/quit") {
      jsonResponse(res, 200, {
        ok: true,
        message: "CodexDone Web Preview is shutting down",
      });
      setTimeout(() => {
        process.exit(0);
      }, 150);
      return;
    }

    if (req.method === "GET" && pathname === "/api/health") {
      jsonResponse(res, 200, await healthReport());
      return;
    }

    if (req.method === "GET" && pathname === "/api/config") {
      const configState = await loadConfig();
      jsonResponse(res, 200, {
        ...configState,
        path: configPath,
      });
      return;
    }

    if ((req.method === "POST" || req.method === "PUT") && pathname === "/api/config") {
      const body = await readJson(req);
      const savedConfig = await saveConfig(body.config || body);
      jsonResponse(res, 200, {
        ok: true,
        config: savedConfig,
        path: configPath,
      });
      return;
    }

    if (req.method === "GET" && pathname === "/api/voices") {
      jsonResponse(res, 200, { voices: await availableVoices() });
      return;
    }

    if (req.method === "GET" && pathname === "/api/sounds") {
      jsonResponse(res, 200, { sounds: await availableSounds() });
      return;
    }

    if (req.method === "GET" && pathname === "/api/codex-rule") {
      jsonResponse(res, 200, { rule: codexRule() });
      return;
    }

    if (req.method === "GET" && pathname === "/api/events") {
      const limit = integerValue(new URL(req.url, "http://localhost").searchParams.get("limit"), 50, 1, 200);
      jsonResponse(res, 200, await loadEvents(limit));
      return;
    }

    if (req.method === "DELETE" && pathname === "/api/events") {
      jsonResponse(res, 200, await clearEvents());
      return;
    }

    if (req.method === "GET" && pathname === "/api/openai-key") {
      jsonResponse(res, 200, await openAIKeyStatus());
      return;
    }

    if (req.method === "POST" && pathname === "/api/openai-key") {
      const body = await readJson(req);
      jsonResponse(res, 200, await saveOpenAIKey(body.apiKey));
      return;
    }

    if (req.method === "DELETE" && pathname === "/api/openai-key") {
      jsonResponse(res, 200, await clearOpenAIKey());
      return;
    }

    if (req.method === "POST" && pathname === "/api/test") {
      const body = await readJson(req);
      const message = stringValue(body.message, "CodexDone Web Preview 测试提醒") || "CodexDone Web Preview 测试提醒";
      const eventType = optionalString(body.eventType);
      await openAIKeyStatus();
      const args = eventType ? ["--event", eventType, message] : [message];
      const result = await runProcess(cliPath, args, { timeoutMs: 70000 });
      jsonResponse(res, result.ok ? 200 : 500, result);
      return;
    }

    if (req.method === "POST" && pathname === "/api/preview-voice") {
      const body = await readJson(req);
      const message = stringValue(body.message, "这是 CodexDone Web Preview 语音试听") || "这是 CodexDone Web Preview 语音试听";
      const rate = integerValue(body.rate, 180, 80, 360);
      const voiceName = optionalString(body.voiceName);
      const args = voiceName ? ["-v", voiceName, "-r", String(rate), message] : ["-r", String(rate), message];
      const result = await runProcess("/usr/bin/say", args, { timeoutMs: 30000 });
      jsonResponse(res, result.ok ? 200 : 500, result);
      return;
    }

    if (req.method === "POST" && pathname === "/api/preview-sound") {
      const body = await readJson(req);
      const soundPath = await resolveSoundPath(stringValue(body.name, "Ping"), optionalString(body.customFilePath));
      const repeatCount = integerValue(body.repeatCount, 1, 1, 10);
      let lastResult = { ok: true, code: 0, stdout: "", stderr: "", timedOut: false };
      for (let index = 0; index < repeatCount; index += 1) {
        lastResult = await runProcess("/usr/bin/afplay", [soundPath], { timeoutMs: 20000 });
        if (!lastResult.ok) {
          break;
        }
      }
      jsonResponse(res, lastResult.ok ? 200 : 500, {
        ...lastResult,
        soundPath,
      });
      return;
    }

    jsonResponse(res, 404, { error: "Unknown API endpoint" });
  } catch (error) {
    jsonResponse(res, 500, { error: error.message });
  }
}

function createServer() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url.pathname);
      return;
    }
    await serveStatic(req, res, url.pathname);
  });
}

function listenWithFallback(server, preferredPort, attempts = 20) {
  return new Promise((resolve, reject) => {
    let port = preferredPort;

    const tryListen = () => {
      server.once("error", (error) => {
        if (error.code === "EADDRINUSE" && attempts > 0) {
          attempts -= 1;
          port += 1;
          tryListen();
          return;
        }
        reject(error);
      });
      server.listen(port, "127.0.0.1", () => {
        resolve(port);
      });
    };

    tryListen();
  });
}

async function main() {
  const preferredPort = integerValue(process.env.CODEX_DONE_WEB_PORT, 51429, 1024, 65535);
  const server = createServer();
  const port = await listenWithFallback(server, preferredPort);
  process.stdout.write(`CodexDone Web Preview running at http://127.0.0.1:${port}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exit(1);
});
