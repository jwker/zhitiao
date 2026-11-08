import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var mock = true
    @State private var showKey = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("模型连接") {
                    Toggle("调试模式（不联网，用本地规则）", isOn: $mock)
                    if !mock {
                        TextField("请求地址", text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("模型名称", text: $modelName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        HStack {
                            SecureField("API Key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button(showKey ? "隐藏" : "显示") {
                                showKey.toggle()
                            }
                            .font(.system(size: 13))
                        }
                    }
                }

                Section {
                    Button("测试连接") {
                        Task { await test() }
                    }
                    if let testResult {
                        Text(testResult)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("配置只保存在这台设备上。Key 不会上传到任何服务器。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(DocumentStore.shared.isCloudAvailable ? "iCloud 已连接，正文会在设备间同步。" : "iCloud 不可用，正文只保存在本机。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let config = model.config
        baseURL = config.baseURL
        apiKey = config.apiKey
        modelName = config.model
        mock = config.mock
    }

    private func save() {
        model.config.baseURL = baseURL
        model.config.apiKey = apiKey
        model.config.model = modelName
        model.config.mock = mock
        model.saveNow()
    }

    private func test() async {
        testResult = "正在测试…"
        var config = model.config
        config.baseURL = baseURL
        config.apiKey = apiKey
        config.model = modelName
        config.mock = false
        do {
            let analysis = try await AIClient.analyze(text: "这是一段测试文字，用来检查模型接口是否通。", config: config)
            testResult = "连接正常，返回 \(analysis.emphasis.count) 个强调词、\(analysis.illustrationSubjects.count) 个插画主体"
        } catch {
            testResult = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
