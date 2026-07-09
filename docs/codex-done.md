# Codex 任务完成通知器

`codex-done` 是 CodexDone 的命令行入口。Codex 完成阶段性任务时调用它，它会读取配置并执行本机提醒、桌面通知和手机推送。

## 快速使用

```bash
./codex-done
./codex-done "代码修改完成，测试已通过"
```

如果希望所有项目都能直接调用命令，可以安装全局入口：

```bash
scripts/install-codexdone-cli.sh
codex-done "全局命令安装完成"
```

默认会创建：

```text
~/.local/bin/codex-done
```

如果 `codex-done` 命令不可见，请确认 `~/.local/bin` 已在 `PATH` 中。

## 配置文件

桌面 App 会写入：

```text
~/.codex-done/config.json
```

如果配置文件不存在或损坏，`codex-done` 会使用 CLI 内置默认配置，不会中断任务。

## 提醒模式

提醒模式只控制提示音和语音播报行为；桌面通知和手机推送由配置和 topic 分别控制，所以 `sound` 或 `voice` 不表示会关闭桌面通知或手机推送。

```text
silent           不播放提示音或语音，仍可按配置发送桌面/手机通知
sound            只播放提示音
voice            只语音播报
voice_and_sound  先提示音，再语音播报
```

App 的“提醒方式”页面会自动读取 `~/Library/Sounds`、`/System/Library/Sounds` 和 `/Library/Sounds` 中的提示音文件，可以直接试听当前提示音。也可以填写自定义提示音文件路径；`sound.customFilePath` 非空且文件存在时，会优先于 `sound.name` 使用。提示音试听只调用 `afplay`，不受全局提醒模式影响。

## 通知内容模板

配置中的 `voice.messageTemplate` 会渲染为通知正文。语音播报、桌面通知和手机推送都会使用同一份渲染后的内容。

App 的“语音内容”页面会自动读取 `say -v ?` 返回的 macOS 系统语音列表，可以按语言选择声音，并可直接试听当前模板、声音和语速。语音试听只调用 `say`，不受全局提醒模式影响。

“完成提醒语音服务商”设置区会保存后续 TTS 接入所需的服务商、声音 ID、性别偏好、风格和音频缓存开关。默认使用 `macOS say` 本机语音。当 `futureVoice.provider` 设为 `openai` 且 `OPENAI_API_KEY` 可用时，`codex-done` 会优先调用 OpenAI Speech API 生成 AI 语音；失败、缺少密钥或缺少工具时会自动回退到本地 `say`。

当前 Web Preview 和 macOS App 会列出这些语音服务商：

```text
macOS say（本机默认）
OpenAI TTS
ElevenLabs
Azure Speech
Google Cloud TTS
Amazon Polly
Edge TTS
自定义 HTTP
```

目前真正接入运行时的是 `macOS say` 和 `OpenAI TTS`；其他服务商先作为预留配置保存，运行时仍会回退到 `macOS say`。

OpenAI API Key 可以通过 Web Preview 的“语音内容”页面输入并保存。密钥会写入本机私密文件，不会写入 `config.json`，页面也不会回显完整密钥：

```text
~/.codex-done/env
```

该文件权限会设置为 `600`。如果需要自定义位置，可以在启动 Web Preview 或运行 CLI 时设置：

```bash
export CODEX_DONE_ENV="/path/to/codex-done-env"
```

也可以继续直接用启动环境变量：

```bash
export OPENAI_API_KEY=<your-openai-api-key>
```

macOS say 和云端真人语音不是同时播放关系。启用 OpenAI TTS 后，任务完成提醒会优先使用 OpenAI 生成语音；如果云端语音不可用，才回退到 macOS `say`。

OpenAI TTS 默认使用 `gpt-4o-mini-tts`，默认声音为 `marin`。请明确告知使用者他们听到的是 AI 生成语音。

支持变量：

```text
{project}
{message}
{time}
{event}
{eventType}
{taskId}
{threadId}
```

App 保存的默认模板：

```text
{project}: {message}
```

CLI 无配置 fallback 仍为：

```text
{message}
```

## 事件策略

Web Preview 和 macOS App 的“事件策略”页面可以为不同事件单独设置提醒模式、提示音和播报模板。没有单独配置的事件会跟随全局提醒方式和全局语音模板。

支持事件：

```text
taskCompleted   任务完成，默认事件
testPassed      测试通过
testFailed      测试失败
needsAttention  需要处理
```

CLI 用法：

```bash
./codex-done --event taskCompleted "本阶段工作已经完成"
./codex-done --event testPassed "测试已通过"
./codex-done --event testFailed "测试失败，需要查看日志"
./codex-done --event needsAttention "需要你确认下一步"
```

也可以用环境变量：

```bash
export CODEX_DONE_EVENT="testFailed"
export CODEX_DONE_TASK_ID="build-42"
export CODEX_DONE_THREAD_ID="codex-thread-a"
./codex-done "构建失败"
```

事件日志会记录 `eventType`、`taskId` 和 `threadId`，Web Preview 和 macOS App 的最近完成记录会显示事件类型。

## 手机推送

当前支持 ntfy 和 Apple Messages / iMessage。可以在 App 的“手机推送”页面选择服务商，也可以继续使用环境变量。已保存的非空配置值优先，环境变量作为 fallback。

### ntfy

Topic 可以写普通 topic：

```bash
export CODEX_NOTIFY_TOPIC="my-codex-topic"
export CODEX_NOTIFY_TITLE="Codex 任务完成"
```

也可以在 App 中填写完整 ntfy 地址，例如：

```text
https://ntfy.sh/my-codex-topic
```

### Apple Messages / iMessage

选择 Apple Messages 后，CodexDone 会通过 macOS Messages app 给指定接收人发送 iMessage。接收人可以是手机号或 Apple ID：

```bash
export CODEX_NOTIFY_RECIPIENT="you@example.com"
```

也兼容旧命名：

```bash
export CODEX_IMESSAGE_RECIPIENT="you@example.com"
```

注意：

- 首次使用时，macOS 可能要求允许运行环境控制 Messages。
- 这条链路本质是发送一条 iMessage，不是 APNs 原生 App Push。
- iPhone 是否朗读通知取决于 iOS 通知、Siri 朗读通知、耳机或 CarPlay 等系统设置。

## 多线程通知队列

如果你同时开多个 Codex 线程，每个线程都运行 `codex-done` 时，CLI 会先把完成事件追加到事件日志，再通过一个本机锁串行发送通知。默认会等待 2 秒，把短时间内完成的多条任务合并成一次播报，避免多个语音同时抢着播放。

Web Preview 和 macOS App 的“队列设置”页面可以配置：

```text
mergeNotifications   是否合并短时间内的完成通知
batchDelaySeconds    合并等待时间，默认 2 秒
retentionCount       完成记录保留数量，默认 200 条
```

默认文件：

```text
~/.codex-done/events.jsonl        每次完成任务的事件日志
~/.codex-done/notify-state.json   已处理到哪一行的状态
~/.codex-done/notify.lock         通知发送锁目录
```

可选环境变量：

```bash
export CODEX_DONE_BATCH_DELAY="2"
export CODEX_DONE_EVENTS="/path/to/events.jsonl"
export CODEX_DONE_NOTIFY_STATE="/path/to/notify-state.json"
export CODEX_DONE_NOTIFY_LOCK_DIR="/path/to/notify.lock"
```

`CODEX_DONE_BATCH_DELAY` 可以调大，例如 `10` 或 `30`，这样多个线程结束得比较接近时会更容易合并为一句“有 N 个 Codex 任务已完成”。调成 `0` 则几乎立即发送，适合自动化测试。

Web Preview 和 macOS App 的“状态”页会读取同一份事件日志，显示最近完成记录；“队列设置”页也可以一键清空完成记录。

## 健康检查面板

Web Preview 和 macOS App 都提供“健康检查”页面，用来快速判断通知链路是否可用。检查结果分为三类：

```text
正常    当前能力可用
注意    可选能力未启用或预留服务商尚未真正接入
需处理  核心能力缺失，可能导致提醒失败
```

当前检查项包括：

- `codex-done` 命令是否可执行
- 配置文件是否存在、是否可读取
- 配置目录和事件日志目录是否可写
- macOS `say`、`osascript`、`afplay`、`curl` 是否可用
- ntfy 手机推送 Topic 是否已配置
- OpenAI TTS 是否选择且具备 API Key
- LaunchAgent 是否已安装
- App 是否以 `.app` 包运行
- Web Preview 服务是否正在运行

其中 ntfy、OpenAI TTS、LaunchAgent 属于增强能力，未配置时通常显示为“注意”，不会阻止本机语音和桌面通知工作。如果已经选择 OpenAI TTS 但没有 API Key，则会显示为“需处理”，因为该配置下真人语音无法启用。

## Codex 工作规则

单项目使用时，建议给该项目的 Codex 工作说明加入：

```text
每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `codex-done` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。普通完成使用默认事件；测试通过可用 `--event testPassed`，测试失败可用 `--event testFailed`，需要我处理时可用 `--event needsAttention`。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。
```

如果希望新开的 Codex 线程都自动执行通知，请先安装全局命令，再把类似规则加入全局 Codex 指令文件，例如：

```text
~/.codex/AGENTS.md
```

推荐内容：

```text
Whenever you complete a stage of work and are about to send the final reply, run `codex-done` if it is available. Use one short sentence to summarize what was completed. If `codex-done` is unavailable or the notification fails, do not interrupt the task; reply normally and mention the notification failure briefly.
```

注意：已经打开的旧 Codex 线程可能不会立即重新读取全局指令。可以在旧线程里补一句“请遵守全局 CodexDone 完成通知规则，任务结束前运行 codex-done”，或重新开启线程。

## 开发验证

```bash
bash tests/test_codex_done.sh
bash -n codex-done tests/test_codex_done.sh
swift test --package-path CodexDoneApp
swift build --package-path CodexDoneApp
scripts/build-codexdone-app.sh
```

其中 `swift test --package-path CodexDoneApp` 需要带 XCTest 的 Swift/Xcode 工具链；如果当前环境缺少 XCTest，可能会因 `no such module 'XCTest'` 失败。

## 打包为 macOS App

运行：

```bash
scripts/build-codexdone-app.sh
```

脚本会生成：

```text
dist/CodexDone.app
```

这个 app bundle 会内置 `codex-done` 到 `Contents/Resources/codex-done`，因此设置窗口中的“测试提醒”可以直接调用随 App 一起打包的命令行通知器。

## 安装命令行入口

如果希望在任意目录直接运行 `codex-done`，可以安装到 `~/.local/bin`：

```bash
scripts/install-codexdone-cli.sh
```

如果终端还找不到命令，把下面这行加入 shell 配置：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 登录时自动启动菜单栏 App

先打包 App，然后安装 LaunchAgent：

```bash
scripts/build-codexdone-app.sh
scripts/install-codexdone-launch-agent.sh
```

卸载登录自启：

```bash
scripts/uninstall-codexdone-launch-agent.sh
```

LaunchAgent 会运行 `dist/CodexDone.app/Contents/MacOS/CodexDone`，因此如果移动了 App 位置，需要重新运行安装脚本。

LaunchAgent 会设置 `CODEX_DONE_SHOW_SETTINGS_ON_LAUNCH=0`，所以开机自启动时只驻留菜单栏，不会自动弹出设置窗口。手动双击 `CodexDone.app` 或再次打开正在运行的 App 时，会主动显示设置窗口。

## Web Preview 调试面板

如果希望在 Codex 右侧内置浏览器中调试配置，可以启动本地 Web Preview：

```bash
scripts/start-codexdone-web-preview.sh
```

默认会监听 `http://127.0.0.1:51429`；如果端口被占用，服务会自动尝试后续端口。面板会读写同一个配置文件：

```text
~/.codex-done/config.json
```

调试面板支持：

- 查看本机提醒、手机推送、OpenAI TTS、配置路径状态
- 查看健康检查，确认命令、配置、系统依赖、手机推送和真人语音是否可用
- 查看事件日志路径和最近完成记录
- 配置合并通知、合并等待时间、完成记录保留数量，并清空完成记录
- 配置任务完成、测试通过、测试失败、需要处理四类事件策略
- 编辑提醒模式、提示音、语音模板、语速、ntfy topic、语音服务商配置
- 输入、保存和清除 OpenAI API Key，本机保存到 `~/.codex-done/env`
- 试听提示音和 macOS 语音
- 运行一次完整 `codex-done` 测试提醒
- 复制 Codex 工作规则

停止服务：

```bash
scripts/stop-codexdone-web-preview.sh
```
