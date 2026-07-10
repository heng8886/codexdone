"use strict";

const sections = [
  { id: "status", label: "状态" },
  { id: "health", label: "健康检查" },
  { id: "reminder", label: "提醒方式" },
  { id: "queue", label: "队列设置" },
  { id: "events", label: "事件策略" },
  { id: "voice", label: "语音内容" },
  { id: "mobile", label: "手机推送" },
  { id: "codex", label: "Codex 集成" },
];

const alertModes = [
  ["silent", "静音"],
  ["sound", "提示音"],
  ["voice", "语音"],
  ["voice_and_sound", "语音 + 提示音"],
];

const mobileProviders = [
  ["ntfy", "ntfy"],
  ["apple_messages", "Apple Messages / iMessage"],
];

const futureProviders = [
  ["", "macOS say（本机默认）"],
  ["openai", "OpenAI TTS"],
  ["elevenlabs", "ElevenLabs"],
  ["azure", "Azure Speech"],
  ["google", "Google Cloud TTS"],
  ["amazon_polly", "Amazon Polly"],
  ["edge_tts", "Edge TTS"],
  ["custom", "自定义 HTTP"],
];

const openAIVoices = ["marin", "cedar", "alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer", "verse"];
const genderOptions = [["", "不指定"], ["female", "女性"], ["male", "男性"], ["neutral", "中性"]];
const styleOptions = [["", "不指定"], ["natural", "自然"], ["warm", "温暖"], ["professional", "专业"], ["energetic", "有活力"], ["calm", "平静"]];
const eventDefinitions = [
  ["taskCompleted", "任务完成", "普通阶段完成或最终答复前的通知。"],
  ["testPassed", "测试通过", "测试或构建成功时的通知。"],
  ["testFailed", "测试失败", "需要明显提醒你查看失败原因。"],
  ["needsAttention", "需要处理", "任务暂停、需要你确认或人工介入。"],
];
const preferredLanguageOptions = [
  ["zh-CN", "中文（简体）"],
  ["zh-TW", "中文（繁体）"],
  ["zh-HK", "中文（香港）"],
  ["en-US", "English (US)"],
  ["en-GB", "English (UK)"],
  ["ja-JP", "日本語"],
  ["ko-KR", "한국어"],
  ["fr-FR", "Français"],
  ["de-DE", "Deutsch"],
  ["es-ES", "Español"],
  ["pt-BR", "Português"],
];

function voiceProviderLabel(value) {
  const normalized = value || "";
  return futureProviders.find(([provider]) => provider === normalized)?.[1] || normalized || "macOS say（本机默认）";
}

function voiceProviderStatus(provider, openAIKeyConfigured) {
  if (!provider) {
    return { ready: true, text: "当前使用 macOS say" };
  }
  if (provider === "openai") {
    return openAIKeyConfigured
      ? { ready: true, text: "OpenAI TTS 已可用" }
      : { ready: false, text: "还缺 OPENAI_API_KEY" };
  }
  return { ready: false, text: "预留配置，当前回退 macOS say" };
}

function voiceProviderGuide(provider) {
  if (!provider) {
    return [
      "使用上方 macOS say 语言、声音和语速配置。",
      "不需要 API Key，也不会调用云端语音服务。",
      "保存配置后运行一次完整提醒测试。",
    ];
  }
  if (provider === "openai") {
    return [
      "服务商选择 OpenAI TTS。",
      "选择一个 OpenAI 声音，例如 marin。",
      "在下方输入并保存 API Key。",
      "保存配置后运行一次完整提醒测试。",
    ];
  }
  return [
    `${voiceProviderLabel(provider)} 目前作为预留服务商保存配置。`,
    "可以先填写服务商侧的声音 ID、性别偏好和风格。",
    "当前 CLI 尚未接入该服务商，运行时会回退到 macOS say。",
  ];
}

const state = {
  section: "status",
  config: null,
  status: null,
  health: null,
  events: [],
  voices: [],
  sounds: [],
  dirty: false,
  busy: false,
  lastOutput: "",
};

const elements = {
  nav: document.getElementById("nav"),
  content: document.getElementById("content"),
  sectionTitle: document.getElementById("section-title"),
  sectionKicker: document.getElementById("section-kicker"),
  reloadButton: document.getElementById("reload-button"),
  saveButton: document.getElementById("save-button"),
  quitButton: document.getElementById("quit-button"),
  notice: document.getElementById("notice"),
  serverStatus: document.getElementById("server-status"),
  serverStatusText: document.getElementById("server-status-text"),
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function getPath(object, path) {
  return path.split(".").reduce((current, part) => current?.[part], object);
}

function setPath(object, path, value) {
  const parts = path.split(".");
  let current = object;
  for (let index = 0; index < parts.length - 1; index += 1) {
    current = current[parts[index]];
  }
  current[parts.at(-1)] = value;
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload.error || payload.stderr || `HTTP ${response.status}`;
    throw new Error(message);
  }
  return payload;
}

function showNotice(message, type = "ok") {
  elements.notice.textContent = message;
  elements.notice.className = `notice${type === "error" ? " error" : ""}`;
  elements.notice.hidden = false;
}

function clearNotice() {
  elements.notice.hidden = true;
}

function persistedNotificationsEnabled() {
  return state.status?.notificationsEnabled ?? state.config?.alert?.enabled ?? true;
}

function testActionButton(label, action = "test", attributes = "") {
  const disabled = persistedNotificationsEnabled() ? "" : ' disabled aria-disabled="true"';
  return `<button class="secondary-button" type="button" data-action="${action}" ${attributes}${disabled}>${label}</button>`;
}

function markDirty() {
  state.dirty = true;
  elements.saveButton.textContent = "保存配置";
}

function updateConnectionStatus(ok, text) {
  elements.serverStatus.classList.toggle("ok", ok);
  elements.serverStatusText.textContent = text;
}

function renderShutdownState() {
  elements.content.innerHTML = `
    <section class="section">
      <h3>Web Preview 已退出</h3>
      <p class="muted">本地调试服务已经关闭。需要再次使用时，请重新运行 <code>scripts/start-codexdone-web-preview.sh</code>。</p>
    </section>
  `;
}

function renderNav() {
  elements.nav.innerHTML = sections.map((section) => `
    <button type="button" data-section="${section.id}" aria-current="${state.section === section.id ? "page" : "false"}">
      ${escapeHtml(section.label)}
    </button>
  `).join("");

  elements.nav.querySelectorAll("button").forEach((button) => {
    button.addEventListener("click", () => {
      state.section = button.dataset.section;
      render();
    });
  });
}

function optionList(options, selected) {
  return options.map(([value, label]) => `
    <option value="${escapeHtml(value)}" ${String(selected ?? "") === String(value) ? "selected" : ""}>${escapeHtml(label)}</option>
  `).join("");
}

function formatEventTime(timestamp) {
  if (!timestamp) {
    return "未知时间";
  }
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) {
    return timestamp;
  }
  return date.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function eventLabel(eventType) {
  const match = eventDefinitions.find(([value]) => value === (eventType || "taskCompleted"));
  return match?.[1] || eventType || "任务完成";
}

function healthStatusLabel(status) {
  if (status === "pass") {
    return "正常";
  }
  if (status === "fail") {
    return "需处理";
  }
  return "注意";
}

function healthStatusClass(status) {
  return status === "pass" || status === "fail" ? status : "warn";
}

function renderEventsSection() {
  const events = state.events || [];
  return `
    <section class="section">
      <div class="section-header">
        <h3>最近完成记录</h3>
        <button class="plain-button" type="button" data-action="refresh-events">刷新</button>
      </div>
      ${events.length === 0 ? `
        <p class="muted">暂无完成记录。运行一次完整提醒测试后，这里会显示新的任务事件。</p>
      ` : `
        <div class="event-list">
          ${events.slice(0, 8).map((event) => `
            <article class="event-item">
              <div class="event-meta">
                <strong>${escapeHtml(event.project || "未知项目")}</strong>
                <span>${escapeHtml(formatEventTime(event.timestamp))}</span>
              </div>
              <div class="event-tag">${escapeHtml(eventLabel(event.eventType))}</div>
              <div class="event-message">${escapeHtml(event.rawMessage || event.message || "任务完成")}</div>
            </article>
          `).join("")}
        </div>
      `}
    </section>
  `;
}

function field(label, path, type = "text", attrs = "") {
  const value = getPath(state.config, path);
  const safeValue = type === "checkbox" ? "" : `value="${escapeHtml(value ?? "")}"`;
  if (type === "checkbox") {
    return `
      <label class="switch-row">
        <span><strong>${escapeHtml(label)}</strong></span>
        <input type="checkbox" data-path="${path}" ${value ? "checked" : ""}>
      </label>
    `;
  }
  return `
    <div class="field">
      <label>${escapeHtml(label)}</label>
      <input type="${type}" data-path="${path}" ${safeValue} ${attrs}>
    </div>
  `;
}

function textarea(label, path) {
  return `
    <div class="field full">
      <label>${escapeHtml(label)}</label>
      <textarea data-path="${path}">${escapeHtml(getPath(state.config, path) ?? "")}</textarea>
    </div>
  `;
}

function select(label, path, options) {
  const selected = getPath(state.config, path) ?? "";
  return `
    <div class="field">
      <label>${escapeHtml(label)}</label>
      <select data-path="${path}">${optionList(options, selected)}</select>
    </div>
  `;
}

function ensureEventConfig(eventName) {
  if (!state.config.events[eventName] || typeof state.config.events[eventName] !== "object") {
    state.config.events[eventName] = {
      mode: null,
      messageTemplate: null,
      soundName: null,
    };
  }
  return state.config.events[eventName];
}

function attachFormHandlers() {
  elements.content.querySelectorAll("[data-path]").forEach((input) => {
    input.addEventListener("input", () => {
      let value = input.type === "checkbox" ? input.checked : input.value;
      if (input.type === "number" || input.type === "range") {
        value = Number.parseInt(input.value, 10);
      }
      if (input.dataset.path.endsWith("voiceName")
        || input.dataset.path.endsWith("customFilePath")
        || input.dataset.path.startsWith("futureVoice.")
        || input.dataset.path.startsWith("events.")) {
        value = value === "" ? null : value;
      }
      setPath(state.config, input.dataset.path, value);
      if (input.dataset.path === "voice.language") {
        state.config.voice.voiceName = null;
      }
      markDirty();
      if (input.dataset.rerender === "true") {
        render();
      }
    });
  });
}

function renderStatus() {
  const status = state.status || {};
  return `
    <section class="section">
      <h3>运行状态</h3>
      <div class="metric-grid">
        <div class="metric"><span>通知总开关</span><strong>${persistedNotificationsEnabled() ? "已开启" : "已暂停"}</strong></div>
        <div class="metric"><span>本机提醒</span><strong>${status.cliAvailable ? "可用" : "未找到"}</strong></div>
        <div class="metric"><span>手机推送</span><strong>${status.mobilePushConfigured ? "已配置" : "未配置"}</strong></div>
        <div class="metric"><span>当前模式</span><strong>${escapeHtml(alertModes.find(([value]) => value === state.config.alert.mode)?.[1] || state.config.alert.mode)}</strong></div>
        <div class="metric"><span>语音服务商</span><strong>${escapeHtml(voiceProviderLabel(state.config.futureVoice.provider || ""))}</strong></div>
      </div>
    </section>
    <section class="section">
      <h3>路径</h3>
      <div class="grid">
        <div class="field full">
          <label>配置文件</label>
          <div class="path">${escapeHtml(status.configPath || "")}</div>
        </div>
        <div class="field full">
          <label>命令行脚本</label>
          <div class="path">${escapeHtml(status.cliPath || "")}</div>
        </div>
        <div class="field full">
          <label>事件日志</label>
          <div class="path">${escapeHtml(status.eventsPath || "")}</div>
        </div>
      </div>
      <div class="actions">
        ${testActionButton("测试完整提醒")}
      </div>
    </section>
    ${renderEventsSection()}
    ${state.lastOutput ? `<section class="section"><h3>最近输出</h3><pre class="code-box">${escapeHtml(state.lastOutput)}</pre></section>` : ""}
  `;
}

function renderHealth() {
  const health = state.health;
  if (!health) {
    return '<section class="section"><h3>健康检查</h3><p class="muted">正在读取检查结果。</p></section>';
  }

  const counts = health.counts || {};
  const generatedAt = health.generatedAt
    ? new Date(health.generatedAt).toLocaleString("zh-CN")
    : "未知时间";

  return `
    <section class="section">
      <div class="section-header">
        <h3>健康概览</h3>
        <button class="plain-button" type="button" data-action="refresh-health">重新检查</button>
      </div>
      <div class="health-summary">
        <div class="metric"><span>整体状态</span><strong>${escapeHtml(healthStatusLabel(health.status))}</strong></div>
        <div class="metric pass"><span>正常</span><strong>${Number(counts.pass || 0)}</strong></div>
        <div class="metric warn"><span>注意</span><strong>${Number(counts.warn || 0)}</strong></div>
        <div class="metric fail"><span>需处理</span><strong>${Number(counts.fail || 0)}</strong></div>
      </div>
      <p class="section-note">最近检查：${escapeHtml(generatedAt)}。未配置的可选能力会显示为“注意”，不会阻止本机提醒运行。</p>
    </section>
    <section class="section">
      <h3>检查项</h3>
      <div class="health-list">
        ${(health.checks || []).map((check) => {
          const statusClass = healthStatusClass(check.status);
          return `
            <article class="health-item ${statusClass}">
              <div class="health-status">${escapeHtml(healthStatusLabel(check.status))}</div>
              <div>
                <strong>${escapeHtml(check.label)}</strong>
                <p>${escapeHtml(check.summary)}</p>
                ${check.detail ? `<div class="path small">${escapeHtml(check.detail)}</div>` : ""}
              </div>
            </article>
          `;
        }).join("")}
      </div>
    </section>
    <section class="section">
      <h3>快速验证</h3>
      <p class="section-note">如果核心检查都正常，可以运行一次完整提醒测试，验证语音、桌面通知、手机推送和事件日志能完整串起来。</p>
      <div class="actions">
        ${testActionButton("测试完整提醒")}
        <button class="plain-button" type="button" data-action="refresh-health">刷新健康检查</button>
      </div>
    </section>
  `;
}

function renderReminder() {
  const soundOptions = state.sounds.map((sound) => [sound.name, sound.name]);
  if (!soundOptions.some(([name]) => name === state.config.sound.name)) {
    soundOptions.unshift([state.config.sound.name || "Ping", state.config.sound.name || "Ping"]);
  }
  return `
    <section class="section">
      <h3>提醒模式</h3>
      ${field("启用所有通知", "alert.enabled", "checkbox")}
      <div class="grid">
        ${select("模式", "alert.mode", alertModes)}
        ${field("提示音重复次数", "sound.repeatCount", "number", 'min="1" max="10"')}
      </div>
      <div>
        ${field("桌面通知", "alert.desktopNotification", "checkbox")}
        ${field("手机推送", "alert.mobilePush", "checkbox")}
      </div>
    </section>
    <section class="section">
      <h3>提示音</h3>
      <div class="grid">
        ${select("声音", "sound.name", soundOptions)}
        ${field("自定义提示音文件路径", "sound.customFilePath")}
      </div>
      <div class="actions">
        <button class="secondary-button" type="button" data-action="preview-sound">试听提示音</button>
        <button class="plain-button" type="button" data-action="clear-custom-sound">清除自定义文件</button>
      </div>
    </section>
  `;
}

function renderQueue() {
  return `
    <section class="section">
      <h3>合并通知</h3>
      <p class="section-note">多个 Codex 线程短时间内完成时，可以合并成一次语音和手机推送，避免通知互相打断。</p>
      ${field("合并短时间内的完成通知", "queue.mergeNotifications", "checkbox")}
      <div class="grid">
        ${field("合并等待时间（秒）", "queue.batchDelaySeconds", "number", 'min="0" max="60"')}
        ${field("完成记录保留数量", "queue.retentionCount", "number", 'min="1" max="5000"')}
      </div>
    </section>
    <section class="section">
      <h3>完成记录</h3>
      <div class="grid">
        <div class="field full">
          <label>事件日志</label>
          <div class="path">${escapeHtml(state.status?.eventsPath || "")}</div>
        </div>
        <div class="field full">
          <label>处理状态</label>
          <div class="path">${escapeHtml(state.status?.notifyStatePath || "")}</div>
        </div>
      </div>
      <div class="actions">
        <button class="secondary-button" type="button" data-action="refresh-events">刷新完成记录</button>
        <button class="plain-button" type="button" data-action="clear-events">清空完成记录</button>
      </div>
    </section>
    ${renderEventsSection()}
  `;
}

function renderEventPolicies() {
  const modeOptions = [["", "跟随全局"], ...alertModes];
  const soundOptions = [["", "跟随全局"], ...state.sounds.map((sound) => [sound.name, sound.name])];
  return `
    <section class="section">
      <h3>事件策略</h3>
      <p class="section-note">不同事件可以使用不同提醒模式和播报模板。CLI 可通过 <code>--event testFailed</code> 或 <code>CODEX_DONE_EVENT=testFailed</code> 触发。</p>
      <div class="policy-list">
        ${eventDefinitions.map(([eventName, label, description]) => {
          ensureEventConfig(eventName);
          return `
            <article class="policy-card">
              <div class="policy-heading">
                <div>
                  <strong>${escapeHtml(label)}</strong>
                  <p>${escapeHtml(description)}</p>
                </div>
                <code>${escapeHtml(eventName)}</code>
              </div>
              <div class="grid three">
                ${select("提醒模式", `events.${eventName}.mode`, modeOptions)}
                ${select("提示音", `events.${eventName}.soundName`, soundOptions)}
              </div>
              ${textarea("播报模板", `events.${eventName}.messageTemplate`)}
              <div class="actions">
                ${testActionButton("测试此策略", "test-event", `data-event="${escapeHtml(eventName)}"`)}
              </div>
            </article>
          `;
        }).join("")}
      </div>
    </section>
  `;
}

function renderVoice() {
  const availableLanguages = new Set(state.voices.map((voice) => voice.languageCode));
  const languageOptions = preferredLanguageOptions.filter(([language]) => availableLanguages.has(language));
  if (languageOptions.length > 0 && !languageOptions.some(([language]) => language === state.config.voice.language)) {
    state.config.voice.language = languageOptions[0][0];
    state.config.voice.voiceName = null;
  }
  const voices = state.voices.filter((voice) => voice.languageCode === state.config.voice.language);
  const voiceOptions = [["", "系统默认"], ...voices.map((voice) => [voice.name, `${voice.name}${voice.sample ? ` — ${voice.sample}` : ""}`])];
  const futureVoiceProvider = state.config.futureVoice.provider || "";
  const openAIKeyConfigured = Boolean(state.status?.openAIKeyConfigured);
  const providerStatus = voiceProviderStatus(futureVoiceProvider, openAIKeyConfigured);
  const providerGuideItems = voiceProviderGuide(futureVoiceProvider);
  const providerFields = [
    select("服务商", "futureVoice.provider", futureProviders).replace("<select", '<select data-rerender="true"'),
  ];
  if (futureVoiceProvider === "openai") {
    providerFields.push(select("OpenAI 声音", "futureVoice.voiceId", openAIVoices.map((voice) => [voice, voice])));
  } else if (futureVoiceProvider) {
    providerFields.push(field("声音 ID", "futureVoice.voiceId"));
  }
  const openAIKeySourceLabel = state.status?.openAIKeySource === "environment" ? "启动环境" : "本机密钥文件";
  const openAIKeyStatusText = openAIKeyConfigured
    ? `已配置（${openAIKeySourceLabel}${state.status?.openAIKeyMasked ? ` · ${state.status.openAIKeyMasked}` : ""}）`
    : "未配置";

  return `
    <section class="section">
      <h3>播报内容</h3>
      <div class="grid">
        ${textarea("播报模板", "voice.messageTemplate")}
      </div>
    </section>
    <section class="section">
      <h3>macOS say（本机）</h3>
      <p class="section-note">用于本机 say 播报和试听，也是云端语音不可用时的回退配置。</p>
      <div class="grid three">
        ${select("语言", "voice.language", languageOptions).replace("<select", '<select data-rerender="true"')}
        ${select("声音", "voice.voiceName", voiceOptions)}
        ${field("语速", "voice.rate", "number", 'min="80" max="360"')}
      </div>
      <div class="actions">
        <button class="secondary-button" type="button" data-action="preview-voice">试听语音</button>
      </div>
    </section>
    <section class="section">
      <h3>完成提醒语音服务商</h3>
      <p class="section-note">选择 macOS say 会直接使用本机语音；选择 OpenAI TTS 后会优先使用云端真人语音。其他云端服务商先作为配置预留。</p>
      <div class="setup-box">
        <div>
          <strong>配置说明</strong>
          <ol>
            ${providerGuideItems.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ol>
        </div>
        <div class="status-badge ${providerStatus.ready ? "ready" : "warning"}">
          ${escapeHtml(providerStatus.text)}
        </div>
      </div>
      ${futureVoiceProvider === "openai" ? `<div class="secret-panel">
        <div>
          <strong>OpenAI API Key</strong>
          <p>保存到本机密钥文件，不写入 config.json；页面不会回显完整 Key。</p>
          <div class="secret-state ${openAIKeyConfigured ? "ready" : "warning"}">${escapeHtml(openAIKeyStatusText)}</div>
          <div class="path small">${escapeHtml(state.status?.openAIKeyPath || "")}</div>
        </div>
        <div class="api-key-row">
          <input type="password" data-openai-key-input placeholder="输入 OpenAI API Key" autocomplete="off" spellcheck="false">
          <button class="secondary-button" type="button" data-action="save-openai-key">保存 Key</button>
          <button class="plain-button" type="button" data-action="clear-openai-key" ${openAIKeyConfigured ? "" : "disabled"}>清除</button>
        </div>
      </div>` : ""}
      <div class="grid three">
        ${providerFields.join("")}
      </div>
      ${futureVoiceProvider ? `<div class="grid three provider-options">
        ${select("性别偏好", "futureVoice.genderPreference", genderOptions)}
        ${select("风格", "futureVoice.style", styleOptions)}
      </div>
      ${field("缓存生成的音频", "futureVoice.cacheAudio", "checkbox")}` : ""}
    </section>
  `;
}

function renderMobile() {
  const provider = state.config.mobile.provider || "ntfy";
  const isAppleMessages = provider === "apple_messages";
  return `
    <section class="section">
      <h3>手机推送</h3>
      <div>
        ${field("启用手机推送", "alert.mobilePush", "checkbox")}
      </div>
      <div class="grid">
        ${select("服务商", "mobile.provider", mobileProviders).replace("<select", '<select data-rerender="true"')}
        ${field("推送标题", "mobile.title")}
      </div>
    </section>
    <section class="section">
      <h3>${isAppleMessages ? "Apple Messages / iMessage" : "ntfy"}</h3>
      <div class="grid">
        ${isAppleMessages
          ? field("接收人手机号或 Apple ID", "mobile.recipient")
          : field("Topic 或完整 URL", "mobile.topic")}
      </div>
      <p class="section-note">${isAppleMessages
        ? "Mac 会通过系统 Messages app 给该接收人发送 iMessage。首次使用时，系统可能要求允许运行环境控制 Messages。"
        : "Topic 可以填写普通 topic，例如 my-codex-topic，也可以填写完整地址，例如 https://ntfy.sh/my-codex-topic。留空时会回退到 CODEX_NOTIFY_TOPIC。"}</p>
      <div class="actions">
        ${testActionButton("测试完整提醒")}
      </div>
    </section>
  `;
}

function renderCodex() {
  return `
    <section class="section">
      <h3>工作规则</h3>
      <pre id="codex-rule" class="code-box">读取中...</pre>
      <div class="actions">
        <button class="secondary-button" type="button" data-action="copy-rule">复制工作规则</button>
      </div>
    </section>
  `;
}

async function loadCodexRule() {
  if (state.section !== "codex") {
    return;
  }
  const target = document.getElementById("codex-rule");
  if (!target) {
    return;
  }
  try {
    const payload = await api("/api/codex-rule");
    target.textContent = payload.rule;
  } catch (error) {
    target.textContent = error.message;
  }
}

function render() {
  if (!state.config) {
    elements.content.innerHTML = '<section class="section"><h3>加载中</h3><p class="muted">正在读取配置。</p></section>';
    return;
  }

  const section = sections.find((item) => item.id === state.section) || sections[0];
  elements.sectionTitle.textContent = section.label;
  elements.sectionKicker.textContent = section.label;
  renderNav();

  const renderers = {
    status: renderStatus,
    health: renderHealth,
    reminder: renderReminder,
    queue: renderQueue,
    events: renderEventPolicies,
    voice: renderVoice,
    mobile: renderMobile,
    codex: renderCodex,
  };
  elements.content.innerHTML = renderers[state.section]();
  attachFormHandlers();
  attachActions();
  loadCodexRule();
}

function resultText(result) {
  const parts = [];
  if (result.code !== undefined && result.code !== null) {
    parts.push(`exit code: ${result.code}`);
  }
  if (result.timedOut) {
    parts.push("timed out");
  }
  if (result.stdout) {
    parts.push(`stdout:\n${result.stdout}`);
  }
  if (result.stderr) {
    parts.push(`stderr:\n${result.stderr}`);
  }
  return parts.join("\n\n") || "ok";
}

async function runAction(action, dataset = {}) {
  clearNotice();
  try {
    if ((action === "test" || action === "test-event") && !persistedNotificationsEnabled()) {
      showNotice("通知已暂停，未发送测试提醒");
      return;
    }

    if (action === "test") {
      const message = "CodexDone Web Preview 测试提醒";
      const result = await api("/api/test", {
        method: "POST",
        body: JSON.stringify({ message }),
      });
      state.lastOutput = resultText(result);
      await loadStatus();
      await loadHealth();
      await loadEvents();
      showNotice("测试提醒已完成");
      render();
      return;
    }

    if (action === "test-event") {
      const eventType = dataset.event || "taskCompleted";
      const label = eventLabel(eventType);
      const result = await api("/api/test", {
        method: "POST",
        body: JSON.stringify({
          eventType,
          message: `CodexDone ${label}策略测试`,
        }),
      });
      state.lastOutput = resultText(result);
      await loadStatus();
      await loadHealth();
      await loadEvents();
      showNotice(`${label}策略测试已完成`);
      render();
      return;
    }

    if (action === "preview-voice") {
      const result = await api("/api/preview-voice", {
        method: "POST",
        body: JSON.stringify({
          message: "这是 CodexDone Web Preview 语音试听",
          voiceName: state.config.voice.voiceName,
          rate: state.config.voice.rate,
        }),
      });
      state.lastOutput = resultText(result);
      showNotice("语音试听已完成");
      render();
      return;
    }

    if (action === "preview-sound") {
      const result = await api("/api/preview-sound", {
        method: "POST",
        body: JSON.stringify({
          name: state.config.sound.name,
          customFilePath: state.config.sound.customFilePath,
          repeatCount: state.config.sound.repeatCount,
        }),
      });
      state.lastOutput = resultText(result);
      showNotice("提示音试听已完成");
      render();
      return;
    }

    if (action === "clear-custom-sound") {
      state.config.sound.customFilePath = null;
      markDirty();
      render();
      showNotice("已清除自定义提示音路径");
      return;
    }

    if (action === "save-openai-key") {
      const input = elements.content.querySelector("[data-openai-key-input]");
      const apiKey = input?.value.trim() || "";
      if (!apiKey) {
        throw new Error("请先输入 API Key");
      }
      await api("/api/openai-key", {
        method: "POST",
        body: JSON.stringify({ apiKey }),
      });
      await loadStatus();
      render();
      showNotice("API Key 已保存到本机密钥文件");
      return;
    }

    if (action === "clear-openai-key") {
      await api("/api/openai-key", { method: "DELETE" });
      await loadStatus();
      render();
      showNotice("已清除本机保存的 API Key");
      return;
    }

    if (action === "refresh-events") {
      await loadEvents();
      render();
      showNotice("完成记录已刷新");
      return;
    }

    if (action === "refresh-health") {
      await loadHealth();
      render();
      showNotice("健康检查已刷新");
      return;
    }

    if (action === "clear-events") {
      await api("/api/events", { method: "DELETE" });
      await loadStatus();
      await loadEvents();
      render();
      showNotice("完成记录已清空");
      return;
    }

    if (action === "copy-rule") {
      const rule = document.getElementById("codex-rule")?.textContent || "";
      await navigator.clipboard.writeText(rule);
      showNotice("工作规则已复制");
    }
  } catch (error) {
    showNotice(error.message, "error");
  }
}

function attachActions() {
  elements.content.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => runAction(button.dataset.action, button.dataset));
  });
}

async function saveConfig() {
  clearNotice();
  try {
    const payload = await api("/api/config", {
      method: "POST",
      body: JSON.stringify({ config: state.config }),
    });
    state.config = payload.config;
    state.dirty = false;
    elements.saveButton.textContent = "已保存";
    showNotice("配置已保存");
    await loadStatus();
    await loadHealth();
    render();
  } catch (error) {
    showNotice(error.message, "error");
  }
}

async function quitWebPreview() {
  const confirmed = window.confirm("确定要退出 CodexDone Web Preview 吗？退出后当前网页会断开连接。");
  if (!confirmed) {
    return;
  }

  clearNotice();
  try {
    elements.quitButton.disabled = true;
    elements.reloadButton.disabled = true;
    elements.saveButton.disabled = true;
    await api("/api/quit", { method: "POST" });
    updateConnectionStatus(false, "已退出");
    showNotice("Web Preview 正在退出");
    window.setTimeout(renderShutdownState, 250);
  } catch (error) {
    updateConnectionStatus(false, "退出中");
    showNotice("Web Preview 正在退出");
    window.setTimeout(renderShutdownState, 250);
  }
}

async function loadStatus() {
  state.status = await api("/api/status");
  updateConnectionStatus(true, "已连接");
}

async function loadHealth() {
  state.health = await api("/api/health");
}

async function loadEvents() {
  const payload = await api("/api/events?limit=20");
  state.events = payload.events || [];
}

async function loadAll() {
  clearNotice();
  try {
    const [configPayload, voicesPayload, soundsPayload] = await Promise.all([
      api("/api/config"),
      api("/api/voices"),
      api("/api/sounds"),
      loadStatus().then(() => null),
      loadHealth().then(() => null),
      loadEvents().then(() => null),
    ]);
    state.config = configPayload.config;
    state.voices = voicesPayload.voices || [];
    state.sounds = soundsPayload.sounds || [];
    state.dirty = false;
    elements.saveButton.textContent = "保存配置";
    render();
  } catch (error) {
    updateConnectionStatus(false, "连接失败");
    showNotice(error.message, "error");
  }
}

elements.reloadButton.addEventListener("click", loadAll);
elements.saveButton.addEventListener("click", saveConfig);
elements.quitButton.addEventListener("click", quitWebPreview);
loadAll();
