import CodexDoneCore
import SwiftUI

struct ReminderModeSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let fallbackSounds = ["Ping", "Glass", "Pop", "Submarine", "Tink"]

    private var soundOptions: [String] {
        let discoveredSounds = appState.systemSounds.map(\.name)
        let baseSounds = discoveredSounds.isEmpty ? fallbackSounds : discoveredSounds
        let currentSound = appState.config.sound.name
        guard !currentSound.isEmpty, !baseSounds.contains(currentSound) else {
            return baseSounds
        }

        return baseSounds + [currentSound]
    }

    private var soundCountText: String {
        if appState.isLoadingSounds {
            return "正在读取系统提示音..."
        }

        return appState.systemSounds.isEmpty
            ? "未读取到系统提示音，仍可保留当前声音"
            : "已读取 \(appState.systemSounds.count) 个系统提示音"
    }

    var body: some View {
        SettingsPage(
            title: "提醒方式",
            subtitle: "配置任务完成时的提示音、语音和桌面/手机提醒组合。",
            systemImage: "bell"
        ) {
            SettingsSectionCard("全局提醒模式") {
                Picker("提醒模式", selection: $appState.config.alert.mode) {
                    ForEach(AlertMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSectionCard("提示音", subtitle: soundCountText) {
                LabeledContent("声音") {
                    Picker("声音", selection: $appState.config.sound.name) {
                        ForEach(soundOptions, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }

                LabeledContent("重复次数") {
                    Stepper(
                        "\(appState.config.sound.repeatCount)",
                        value: $appState.config.sound.repeatCount,
                        in: 1...3
                    )
                    .frame(maxWidth: 120)
                }

                LabeledContent("自定义提示音文件路径") {
                    TextField("留空时使用上方选择的系统提示音", text: Binding(
                        get: { appState.config.sound.customFilePath ?? "" },
                        set: { appState.config.sound.customFilePath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                Text("填写自定义文件路径后会优先使用该文件；留空时使用上方选择的系统提示音。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsSectionCard("操作") {
                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("保存配置") { appState.save() },
                        SettingsAction("试听提示音") { appState.previewSound() },
                        SettingsAction("重新读取系统提示音") { appState.loadSystemSounds() },
                        SettingsAction("清除自定义文件") { appState.config.sound.customFilePath = nil },
                        SettingsAction("测试完整提醒") { appState.testReminder() },
                    ]
                )
            }
        }
    }
}
