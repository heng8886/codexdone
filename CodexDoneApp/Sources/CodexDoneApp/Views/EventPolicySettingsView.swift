import CodexDoneCore
import SwiftUI

struct EventPolicySettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let definitions = EventPolicyDefinition.all
    private let fallbackSounds = ["Ping", "Glass", "Pop", "Submarine", "Tink"]

    private var soundOptions: [String] {
        let discoveredSounds = appState.systemSounds.map(\.name)
        return discoveredSounds.isEmpty ? fallbackSounds : discoveredSounds
    }

    var body: some View {
        SettingsPage(
            title: "事件策略",
            subtitle: "为不同 Codex 完成事件配置独立的提醒方式、提示音和播报模板。",
            systemImage: "flag"
        ) {
            SettingsSectionCard("触发方式") {
                Text("CLI 可通过 --event testFailed 或 CODEX_DONE_EVENT=testFailed 触发不同策略。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(definitions) { definition in
                    EventPolicyCard(
                        definition: definition,
                        soundOptions: soundOptions,
                        mode: modeBinding(for: definition.kind),
                        sound: soundBinding(for: definition.kind),
                        template: templateBinding(for: definition.kind)
                    ) {
                        appState.testReminder(
                            eventType: definition.kind.rawValue,
                            message: "CodexDone \(definition.title)策略测试"
                        )
                    }
                }
            }

            SettingsSectionCard("操作") {
                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("保存配置") { appState.save() },
                    ]
                )
            }
        }
    }

    private func modeBinding(for kind: EventPolicyKind) -> Binding<AlertMode?> {
        Binding(
            get: { policy(for: kind).mode },
            set: { newValue in
                var currentPolicy = policy(for: kind)
                currentPolicy.mode = newValue
                setPolicy(currentPolicy, for: kind)
            }
        )
    }

    private func soundBinding(for kind: EventPolicyKind) -> Binding<String> {
        Binding(
            get: { policy(for: kind).soundName ?? "" },
            set: { newValue in
                var currentPolicy = policy(for: kind)
                currentPolicy.soundName = newValue.isEmpty ? nil : newValue
                setPolicy(currentPolicy, for: kind)
            }
        )
    }

    private func templateBinding(for kind: EventPolicyKind) -> Binding<String> {
        Binding(
            get: { policy(for: kind).messageTemplate ?? "" },
            set: { newValue in
                var currentPolicy = policy(for: kind)
                currentPolicy.messageTemplate = newValue.isEmpty ? nil : newValue
                setPolicy(currentPolicy, for: kind)
            }
        )
    }

    private func policy(for kind: EventPolicyKind) -> EventAlertConfig {
        switch kind {
        case .taskCompleted:
            return appState.config.events.taskCompleted ?? emptyPolicy()
        case .testPassed:
            return appState.config.events.testPassed ?? emptyPolicy()
        case .testFailed:
            return appState.config.events.testFailed ?? emptyPolicy()
        case .needsAttention:
            return appState.config.events.needsAttention ?? emptyPolicy()
        }
    }

    private func setPolicy(_ policy: EventAlertConfig, for kind: EventPolicyKind) {
        switch kind {
        case .taskCompleted:
            appState.config.events.taskCompleted = policy
        case .testPassed:
            appState.config.events.testPassed = policy
        case .testFailed:
            appState.config.events.testFailed = policy
        case .needsAttention:
            appState.config.events.needsAttention = policy
        }
    }

    private func emptyPolicy() -> EventAlertConfig {
        EventAlertConfig(mode: nil, messageTemplate: nil, soundName: nil)
    }
}

private struct EventPolicyCard: View {
    let definition: EventPolicyDefinition
    let soundOptions: [String]
    @Binding var mode: AlertMode?
    @Binding var sound: String
    @Binding var template: String
    let testAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.title)
                        .font(.headline)
                    Text(definition.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(definition.kind.rawValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .textSelection(.enabled)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("提醒模式")
                        .foregroundStyle(.secondary)
                    Picker("提醒模式", selection: $mode) {
                        Text("跟随全局").tag(Optional<AlertMode>.none)
                        ForEach(AlertMode.allCases) { mode in
                            Text(mode.displayName).tag(Optional(mode))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                }

                GridRow {
                    Text("提示音")
                        .foregroundStyle(.secondary)
                    Picker("提示音", selection: $sound) {
                        Text("跟随全局").tag("")
                        ForEach(soundOptions, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 300)
                }

                GridRow {
                    Text("播报模板")
                        .foregroundStyle(.secondary)
                    TextField("留空表示使用全局语音模板", text: $template, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Text("可用变量：{project}、{message}、{time}、{event}、{eventType}、{taskId}、{threadId}。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("测试此策略", action: testAction)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum EventPolicyKind: String, CaseIterable, Identifiable {
    case taskCompleted
    case testPassed
    case testFailed
    case needsAttention

    var id: String { rawValue }
}

private struct EventPolicyDefinition: Identifiable {
    let kind: EventPolicyKind
    let title: String
    let description: String

    var id: String { kind.rawValue }

    static let all: [EventPolicyDefinition] = [
        EventPolicyDefinition(
            kind: .taskCompleted,
            title: "任务完成",
            description: "普通阶段完成或最终答复前的通知。"
        ),
        EventPolicyDefinition(
            kind: .testPassed,
            title: "测试通过",
            description: "测试或构建成功时的通知。"
        ),
        EventPolicyDefinition(
            kind: .testFailed,
            title: "测试失败",
            description: "需要明显提醒你查看失败原因。"
        ),
        EventPolicyDefinition(
            kind: .needsAttention,
            title: "需要处理",
            description: "任务暂停、需要你确认或人工介入。"
        ),
    ]
}
