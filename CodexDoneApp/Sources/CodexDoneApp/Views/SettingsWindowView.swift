import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case status = "状态"
    case health = "健康检查"
    case reminder = "提醒方式"
    case queue = "队列设置"
    case events = "事件策略"
    case voice = "语音内容"
    case mobile = "手机推送"
    case codex = "Codex 集成"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .status:
            return "checkmark.circle"
        case .health:
            return "checklist"
        case .reminder:
            return "bell"
        case .queue:
            return "tray.full"
        case .events:
            return "flag"
        case .voice:
            return "speaker.wave.2"
        case .mobile:
            return "iphone"
        case .codex:
            return "terminal"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                        .accessibilityIdentifier("settings.section.\(section.id)")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CodexDone")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } detail: {
            detailView
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection ?? .status {
            case .status:
                StatusSettingsView()
            case .health:
                HealthSettingsView()
            case .reminder:
                ReminderModeSettingsView()
            case .queue:
                QueueSettingsView()
            case .events:
                EventPolicySettingsView()
            case .voice:
                VoiceContentSettingsView()
            case .mobile:
                MobilePushSettingsView()
            case .codex:
                CodexIntegrationSettingsView()
            }
    }
}
