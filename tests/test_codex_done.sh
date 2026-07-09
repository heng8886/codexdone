#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/codex-done"
TMP_DIR="$(mktemp -d)"
STUB_DIR="$TMP_DIR/bin"
LOG_DIR="$TMP_DIR/logs"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"

  if [[ ! -f "$file" ]]; then
    fail "expected $file to exist"
  fi

  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected to find: %s\n' "$expected" >&2
    printf 'Actual contents:\n' >&2
    cat "$file" >&2
    fail "$file did not contain expected text"
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  if grep -Fq -- "$unexpected" "$file"; then
    printf 'Did not expect to find: %s\n' "$unexpected" >&2
    printf 'Actual contents:\n' >&2
    cat "$file" >&2
    fail "$file contained unexpected text"
  fi
}

assert_not_exists() {
  local file="$1"

  if [[ -e "$file" ]]; then
    printf 'Unexpected file contents for %s:\n' "$file" >&2
    cat "$file" >&2
    fail "$file should not exist"
  fi
}

assert_exists() {
  local file="$1"

  if [[ ! -e "$file" ]]; then
    fail "$file should exist"
  fi
}

assert_line_count() {
  local file="$1"
  local expected_count="$2"
  local actual_count

  if [[ ! -f "$file" ]]; then
    fail "expected $file to exist"
  fi

  actual_count="$(wc -l <"$file" | tr -d '[:space:]')"
  if [[ "$actual_count" != "$expected_count" ]]; then
    printf 'Expected %s lines in %s, got %s\n' "$expected_count" "$file" "$actual_count" >&2
    cat "$file" >&2
    fail "$file line count mismatch"
  fi
}

write_config() {
  local file="$1"
  local mode="$2"
  local topic="$3"
  local template="$4"
  local voice_rate="${5:-180}"
  local mobile_push="${6:-true}"
  local custom_file_path="${7:-}"
  local custom_file_path_json="null"

  if [[ -n "$custom_file_path" ]]; then
    custom_file_path_json="\"$custom_file_path\""
  fi

  mkdir -p "$(dirname "$file")"
  cat >"$file" <<JSON
{
  "version": 1,
  "alert": {
    "mode": "$mode",
    "desktopNotification": true,
    "mobilePush": $mobile_push
  },
  "sound": {
    "provider": "macos",
    "name": "Ping",
    "repeatCount": 2,
    "customFilePath": $custom_file_path_json
  },
  "voice": {
    "provider": "macos",
    "language": "zh-CN",
    "voiceName": "Tingting",
    "rate": $voice_rate,
    "messageTemplate": "$template"
  },
  "mobile": {
    "provider": "ntfy",
    "topic": "$topic",
    "title": "JSON 标题"
  },
  "events": {
    "taskCompleted": null,
    "testPassed": null,
    "testFailed": null,
    "needsAttention": null
  },
  "futureVoice": {
    "provider": null,
    "voiceId": null,
    "genderPreference": null,
    "style": null,
    "cacheAudio": true
  }
}
JSON
}

write_default_curl_stub() {
  mkdir -p "$STUB_DIR"

  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/curl.log"
STUB

  chmod +x "$STUB_DIR/curl"
}

set_queue_config() {
  local file="$1"
  local merge_notifications="$2"
  local batch_delay_seconds="$3"
  local retention_count="$4"

  python3 - "$file" "$merge_notifications" "$batch_delay_seconds" "$retention_count" <<'PY'
import json
import sys

path, merge, delay, retention = sys.argv[1:5]
with open(path, "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["queue"] = {
    "mergeNotifications": merge == "true",
    "batchDelaySeconds": int(delay),
    "retentionCount": int(retention),
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle)
PY
}

set_event_config() {
  local file="$1"
  local event_name="$2"
  local mode="$3"
  local template="$4"
  local sound_name="${5:-}"

  python3 - "$file" "$event_name" "$mode" "$template" "$sound_name" <<'PY'
import json
import sys

path, event_name, mode, template, sound_name = sys.argv[1:6]
with open(path, "r", encoding="utf-8") as handle:
    config = json.load(handle)
config.setdefault("events", {})
config["events"][event_name] = {
    "mode": mode or None,
    "messageTemplate": template or None,
    "soundName": sound_name or None,
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle)
PY
}

write_default_say_stub() {
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/say" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/say.log"
STUB

  chmod +x "$STUB_DIR/say"
}

write_default_osascript_stub() {
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/osascript.log"
STUB

  chmod +x "$STUB_DIR/osascript"
}

create_stubs() {
  mkdir -p "$STUB_DIR" "$LOG_DIR"

  write_default_say_stub
  write_default_osascript_stub
  write_default_curl_stub

  cat >"$STUB_DIR/afplay" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/afplay.log"
STUB

  chmod +x "$STUB_DIR/afplay"
}

reset_logs() {
  rm -rf "$LOG_DIR"/*.log "$LOG_DIR"/stdout "$LOG_DIR"/stderr "$LOG_DIR"/config.json "$LOG_DIR"/env "$LOG_DIR"/events.jsonl "$LOG_DIR"/notify-state.json "$LOG_DIR"/notify.lock
  unset CODEX_DONE_ENV CODEX_NOTIFY_TOPIC CODEX_NOTIFY_TITLE OPENAI_API_KEY
  write_default_say_stub
  write_default_osascript_stub
  write_default_curl_stub
}

run_codex_done() {
  (
    cd "$ROOT_DIR"
    CODEX_DONE_CONFIG="$LOG_DIR/config.json" \
      CODEX_DONE_ENV="$LOG_DIR/env" \
      CODEX_DONE_EVENTS="$LOG_DIR/events.jsonl" \
      CODEX_DONE_NOTIFY_STATE="$LOG_DIR/notify-state.json" \
      CODEX_DONE_NOTIFY_LOCK_DIR="$LOG_DIR/notify.lock" \
      CODEX_DONE_BATCH_DELAY="0" \
      CODEX_DONE_TEST_LOG="$LOG_DIR" \
      PATH="$STUB_DIR:$PATH" \
      "$SCRIPT" "$@"
  ) >"$LOG_DIR/stdout" 2>"$LOG_DIR/stderr"
}

test_default_local_notification_without_phone_topic() {
  reset_logs

  run_codex_done

  assert_contains "$LOG_DIR/say.log" "本阶段工作已经完成"
  assert_contains "$LOG_DIR/osascript.log" "display notification"
  assert_contains "$LOG_DIR/osascript.log" "本阶段工作已经完成"
  assert_contains "$LOG_DIR/osascript.log" "Codex 任务完成"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_event_log_records_completion() {
  reset_logs

  run_codex_done "事件记录测试"

  assert_contains "$LOG_DIR/events.jsonl" "\"rawMessage\":\"事件记录测试\""
  assert_contains "$LOG_DIR/events.jsonl" "\"project\":\"$(basename "$ROOT_DIR")\""
  assert_contains "$LOG_DIR/events.jsonl" "\"status\":\"completed\""
}

test_event_type_records_metadata() {
  reset_logs

  run_codex_done --event test-failed --task-id task-123 --thread-id thread-abc "测试失败"

  assert_contains "$LOG_DIR/events.jsonl" "\"eventType\":\"testFailed\""
  assert_contains "$LOG_DIR/events.jsonl" "\"taskId\":\"task-123\""
  assert_contains "$LOG_DIR/events.jsonl" "\"threadId\":\"thread-abc\""
  assert_contains "$LOG_DIR/say.log" "测试失败"
}

test_event_strategy_overrides_mode_and_template() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  set_event_config "$LOG_DIR/config.json" "testFailed" "silent" "{event}：{message}" "Ping"

  run_codex_done --event testFailed "单元测试失败"

  assert_not_exists "$LOG_DIR/say.log"
  assert_not_exists "$LOG_DIR/afplay.log"
  assert_contains "$LOG_DIR/osascript.log" "测试失败：单元测试失败"
  assert_contains "$LOG_DIR/events.jsonl" "\"message\":\"测试失败：单元测试失败\""
}

test_unprocessed_events_are_batched() {
  reset_logs

  cat >"$LOG_DIR/events.jsonl" <<JSONL
{"id":"seed-1","timestamp":"2026-07-08T00:00:00Z","epoch":1,"project":"项目A","rawMessage":"第一个任务完成","message":"项目A: 第一个任务完成","cwd":"/tmp/a","pid":1,"source":"codex-done","status":"completed"}
{"id":"seed-2","timestamp":"2026-07-08T00:00:01Z","epoch":2,"project":"项目B","rawMessage":"第二个任务完成","message":"项目B: 第二个任务完成","cwd":"/tmp/b","pid":2,"source":"codex-done","status":"completed"}
JSONL

  run_codex_done "第三个任务完成"

  assert_contains "$LOG_DIR/say.log" "有 3 个 Codex 任务已完成"
  assert_contains "$LOG_DIR/say.log" "来自"
}

test_queue_merge_disabled_uses_current_message() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  set_queue_config "$LOG_DIR/config.json" "false" "0" "200"

  cat >"$LOG_DIR/events.jsonl" <<JSONL
{"id":"seed-1","timestamp":"2026-07-08T00:00:00Z","epoch":1,"project":"项目A","rawMessage":"第一个任务完成","message":"项目A: 第一个任务完成","cwd":"/tmp/a","pid":1,"source":"codex-done","status":"completed"}
{"id":"seed-2","timestamp":"2026-07-08T00:00:01Z","epoch":2,"project":"项目B","rawMessage":"第二个任务完成","message":"项目B: 第二个任务完成","cwd":"/tmp/b","pid":2,"source":"codex-done","status":"completed"}
JSONL

  run_codex_done "第三个任务完成"

  assert_contains "$LOG_DIR/say.log" "第三个任务完成"
  assert_not_contains "$LOG_DIR/say.log" "有 3 个 Codex 任务已完成"
  assert_contains "$LOG_DIR/notify-state.json" "\"processedLineCount\": 3"
}

test_event_retention_prunes_old_records() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  set_queue_config "$LOG_DIR/config.json" "true" "0" "2"

  cat >"$LOG_DIR/events.jsonl" <<JSONL
{"id":"seed-1","timestamp":"2026-07-08T00:00:00Z","epoch":1,"project":"项目A","rawMessage":"第一个任务完成","message":"项目A: 第一个任务完成","cwd":"/tmp/a","pid":1,"source":"codex-done","status":"completed"}
{"id":"seed-2","timestamp":"2026-07-08T00:00:01Z","epoch":2,"project":"项目B","rawMessage":"第二个任务完成","message":"项目B: 第二个任务完成","cwd":"/tmp/b","pid":2,"source":"codex-done","status":"completed"}
JSONL

  run_codex_done "第三个任务完成"

  assert_line_count "$LOG_DIR/events.jsonl" "2"
  assert_not_contains "$LOG_DIR/events.jsonl" "\"id\":\"seed-1\""
  assert_contains "$LOG_DIR/events.jsonl" "\"id\":\"seed-2\""
  assert_contains "$LOG_DIR/events.jsonl" "\"rawMessage\":\"第三个任务完成\""
}

test_custom_message_and_ntfy_topic() {
  reset_logs

  CODEX_NOTIFY_TOPIC="codex-test-topic" CODEX_NOTIFY_TITLE="自定义标题" run_codex_done "代码修改完成，测试已通过"

  assert_contains "$LOG_DIR/say.log" "代码修改完成，测试已通过"
  assert_contains "$LOG_DIR/osascript.log" "自定义标题"
  assert_contains "$LOG_DIR/curl.log" "https://ntfy.sh/codex-test-topic"
  assert_contains "$LOG_DIR/curl.log" "Title: 自定义标题"
  assert_contains "$LOG_DIR/curl.log" "--connect-timeout 3"
  assert_contains "$LOG_DIR/curl.log" "--max-time 5"
  assert_contains "$LOG_DIR/curl.log" "代码修改完成，测试已通过"
}

test_json_voice_and_sound_config() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice_and_sound" "json-topic" "{project}: {message}"

  run_codex_done "代码修改完成"

  local expected_project
  expected_project="$(basename "$ROOT_DIR")"
  assert_contains "$LOG_DIR/afplay.log" "Ping.aiff"
  assert_line_count "$LOG_DIR/afplay.log" "2"
  assert_contains "$LOG_DIR/say.log" "-v Tingting"
  assert_contains "$LOG_DIR/say.log" "$expected_project: 代码修改完成"
  assert_contains "$LOG_DIR/curl.log" "https://ntfy.sh/json-topic"
  assert_contains "$LOG_DIR/curl.log" "Title: JSON 标题"
}

test_json_voice_rate_uses_configured_value() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}" "210"

  run_codex_done "语速配置测试"

  assert_contains "$LOG_DIR/say.log" "-r 210"
  assert_contains "$LOG_DIR/say.log" "语速配置测试"
}

test_json_mobile_push_false_skips_curl_with_topic() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "json-topic" "{message}" "180" "false"

  run_codex_done "关闭手机推送"

  assert_contains "$LOG_DIR/say.log" "关闭手机推送"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_json_sound_mode_skips_voice() {
  reset_logs
  write_config "$LOG_DIR/config.json" "sound" "" "{message}"

  run_codex_done "只响提示音"

  assert_contains "$LOG_DIR/afplay.log" "Ping.aiff"
  assert_not_exists "$LOG_DIR/say.log"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_json_custom_sound_file_path_takes_precedence() {
  reset_logs
  local custom_sound="$LOG_DIR/custom-notification.wav"
  : >"$custom_sound"
  write_config "$LOG_DIR/config.json" "sound" "" "{message}" "180" "true" "$custom_sound"

  run_codex_done "自定义提示音"

  assert_contains "$LOG_DIR/afplay.log" "$custom_sound"
  assert_line_count "$LOG_DIR/afplay.log" "2"
  assert_not_contains "$LOG_DIR/afplay.log" "Ping.aiff"
  assert_not_exists "$LOG_DIR/say.log"
}

test_openai_tts_uses_speech_endpoint_when_configured() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  python3 - "$LOG_DIR/config.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["futureVoice"]["provider"] = "openai"
config["futureVoice"]["voiceId"] = "marin"
config["futureVoice"]["genderPreference"] = "neutral"
config["futureVoice"]["style"] = "warm"
config["futureVoice"]["cacheAudio"] = False
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle)
PY

  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/curl.log"
output_file=""
payload_file=""
previous=""
for argument in "$@"; do
  if [[ "$previous" == "--output" ]]; then
    output_file="$argument"
  elif [[ "$previous" == "--data-binary" && "$argument" == @* ]]; then
    payload_file="${argument#@}"
  fi
  previous="$argument"
done
if [[ -n "$payload_file" ]]; then
  cat "$payload_file" >>"$CODEX_DONE_TEST_LOG/openai-payload.log"
fi
if [[ -n "$output_file" ]]; then
  printf 'fake audio' >"$output_file"
fi
STUB
  chmod +x "$STUB_DIR/curl"

  OPENAI_API_KEY="test-openai-key" run_codex_done "真人语音测试"

  assert_contains "$LOG_DIR/curl.log" "https://api.openai.com/v1/audio/speech"
  assert_contains "$LOG_DIR/curl.log" "Authorization: Bearer test-openai-key"
  assert_contains "$LOG_DIR/curl.log" "--connect-timeout 5"
  assert_contains "$LOG_DIR/curl.log" "--max-time 45"
  assert_contains "$LOG_DIR/openai-payload.log" "\"model\": \"gpt-4o-mini-tts\""
  assert_contains "$LOG_DIR/openai-payload.log" "\"voice\": \"marin\""
  assert_contains "$LOG_DIR/openai-payload.log" "真人语音测试"
  assert_contains "$LOG_DIR/afplay.log" "codex-openai-tts"
  assert_not_exists "$LOG_DIR/say.log"
}

test_openai_tts_reads_api_key_from_env_file() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  python3 - "$LOG_DIR/config.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["futureVoice"]["provider"] = "openai"
config["futureVoice"]["voiceId"] = "marin"
config["futureVoice"]["cacheAudio"] = False
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle)
PY

  printf "OPENAI_API_KEY='test-openai-key-from-env-file'\n" >"$LOG_DIR/env"
  chmod 600 "$LOG_DIR/env"

  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/curl.log"
output_file=""
payload_file=""
previous=""
for argument in "$@"; do
  if [[ "$previous" == "--output" ]]; then
    output_file="$argument"
  elif [[ "$previous" == "--data-binary" && "$argument" == @* ]]; then
    payload_file="${argument#@}"
  fi
  previous="$argument"
done
if [[ -n "$payload_file" ]]; then
  cat "$payload_file" >>"$CODEX_DONE_TEST_LOG/openai-payload.log"
fi
if [[ -n "$output_file" ]]; then
  printf 'fake audio' >"$output_file"
fi
STUB
  chmod +x "$STUB_DIR/curl"

  run_codex_done "本机密钥文件"

  assert_contains "$LOG_DIR/curl.log" "Authorization: Bearer test-openai-key-from-env-file"
  assert_contains "$LOG_DIR/openai-payload.log" "本机密钥文件"
  assert_contains "$LOG_DIR/afplay.log" "codex-openai-tts"
  assert_not_exists "$LOG_DIR/say.log"
}

test_openai_tts_without_api_key_falls_back_to_say() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "" "{message}"
  python3 - "$LOG_DIR/config.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["futureVoice"]["provider"] = "openai"
config["futureVoice"]["voiceId"] = "marin"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(config, handle)
PY

  run_codex_done "回退本地语音"

  assert_contains "$LOG_DIR/say.log" "回退本地语音"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_json_silent_mode_skips_sound_and_voice() {
  reset_logs
  write_config "$LOG_DIR/config.json" "silent" "" "{message}"

  run_codex_done "静音测试"

  assert_not_exists "$LOG_DIR/afplay.log"
  assert_not_exists "$LOG_DIR/say.log"
  assert_contains "$LOG_DIR/osascript.log" "静音测试"
}

test_damaged_config_uses_defaults() {
  reset_logs
  printf '{ broken json' >"$LOG_DIR/config.json"

  run_codex_done "损坏配置测试"

  assert_contains "$LOG_DIR/say.log" "损坏配置测试"
  assert_contains "$LOG_DIR/osascript.log" "损坏配置测试"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_ntfy_failure_does_not_fail_completion() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "json-topic" "{message}"
  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/curl.log"
exit 22
STUB
  chmod +x "$STUB_DIR/curl"

  run_codex_done "手机推送失败也继续"

  assert_contains "$LOG_DIR/say.log" "手机推送失败也继续"
  assert_contains "$LOG_DIR/stderr" "ntfy push failed"
}

test_empty_json_mobile_fields_use_env_fallbacks() {
  reset_logs
  cat >"$LOG_DIR/config.json" <<'JSON'
{
  "version": 1,
  "alert": {
    "mode": "voice",
    "desktopNotification": true,
    "mobilePush": true
  },
  "voice": {
    "messageTemplate": "{message}"
  },
  "mobile": {
    "topic": "",
    "title": ""
  }
}
JSON

  CODEX_NOTIFY_TOPIC="env-topic" CODEX_NOTIFY_TITLE="Env Title" run_codex_done "环境变量兜底"

  assert_contains "$LOG_DIR/curl.log" "https://ntfy.sh/env-topic"
  assert_contains "$LOG_DIR/curl.log" "Title: Env Title"
}

test_json_desktop_notification_false_skips_osascript() {
  reset_logs
  cat >"$LOG_DIR/config.json" <<'JSON'
{
  "version": 1,
  "alert": {
    "mode": "voice",
    "desktopNotification": false,
    "mobilePush": false
  },
  "voice": {
    "messageTemplate": "{message}"
  },
  "mobile": {
    "topic": "",
    "title": ""
  }
}
JSON

  run_codex_done "不要桌面通知"

  assert_contains "$LOG_DIR/say.log" "不要桌面通知"
  assert_not_exists "$LOG_DIR/osascript.log"
}

test_failing_say_does_not_fail_completion() {
  reset_logs
  cat >"$STUB_DIR/say" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/say.log"
exit 12
STUB
  chmod +x "$STUB_DIR/say"

  run_codex_done "语音失败也继续"

  assert_contains "$LOG_DIR/say.log" "语音失败也继续"
  assert_contains "$LOG_DIR/osascript.log" "语音失败也继续"
  assert_contains "$LOG_DIR/stderr" "voice notification failed"
}

test_failing_osascript_does_not_fail_completion() {
  reset_logs
  cat >"$STUB_DIR/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/osascript.log"
exit 17
STUB
  chmod +x "$STUB_DIR/osascript"

  run_codex_done "桌面通知失败也继续"

  assert_contains "$LOG_DIR/say.log" "桌面通知失败也继续"
  assert_contains "$LOG_DIR/osascript.log" "桌面通知失败也继续"
  assert_contains "$LOG_DIR/stderr" "desktop notification failed"
}

test_message_placeholder_replacement_is_one_pass() {
  reset_logs

  run_codex_done "literal {time}"

  assert_contains "$LOG_DIR/say.log" "literal {time}"
  assert_contains "$LOG_DIR/osascript.log" "literal {time}"
}

test_ntfy_uses_data_raw_for_at_prefixed_message() {
  reset_logs

  CODEX_NOTIFY_TOPIC="codex-test-topic" run_codex_done "@not-a-file"

  assert_contains "$LOG_DIR/curl.log" "--data-raw"
  assert_contains "$LOG_DIR/curl.log" "@not-a-file"
  assert_not_contains "$LOG_DIR/curl.log" "-d @not-a-file"
}

main() {
  if [[ ! -x "$SCRIPT" ]]; then
    fail "codex-done should exist and be executable"
  fi

  create_stubs
  test_default_local_notification_without_phone_topic
  test_event_log_records_completion
  test_event_type_records_metadata
  test_event_strategy_overrides_mode_and_template
  test_unprocessed_events_are_batched
  test_queue_merge_disabled_uses_current_message
  test_event_retention_prunes_old_records
  test_custom_message_and_ntfy_topic
  test_json_voice_and_sound_config
  test_json_voice_rate_uses_configured_value
  test_json_mobile_push_false_skips_curl_with_topic
  test_json_sound_mode_skips_voice
  test_json_custom_sound_file_path_takes_precedence
  test_openai_tts_uses_speech_endpoint_when_configured
  test_openai_tts_reads_api_key_from_env_file
  test_openai_tts_without_api_key_falls_back_to_say
  test_json_silent_mode_skips_sound_and_voice
  test_damaged_config_uses_defaults
  test_ntfy_failure_does_not_fail_completion
  test_empty_json_mobile_fields_use_env_fallbacks
  test_json_desktop_notification_false_skips_osascript
  test_failing_say_does_not_fail_completion
  test_failing_osascript_does_not_fail_completion
  test_message_placeholder_replacement_is_one_pass
  test_ntfy_uses_data_raw_for_at_prefixed_message

  printf 'ok - codex-done behavior verified\n'
}

main "$@"
