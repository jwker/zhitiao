import SwiftUI

/// 设置：文本模型 + 插画模型。
///
/// H5 版的地址、Key、模型名放在 `.env.local` 里由 Vite 注入；原生 App 没有构建期注入这一层，
/// 改成在 App 内填写，存本机 UserDefaults（不进代码库、不进 iCloud）。
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var mock = true

    @State private var imageBaseURL = ""
    @State private var imageKey = ""
    @State private var imageModel = ""

    @State private var showTextKey = false
    @State private var showImageKey = false
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("调试模式（不联网，用本地规则）", isOn: $mock)
                        .onChange(of: mock) { _, value in
                            // 调试模式下不碰模型，避免误以为在调接口
                            if value { testResult = nil }
                        }
                } footer: {
                    Text("打开调试模式时不发请求，强调词和插画都由本地规则给。")
                }

                Section {
                    TextField("请求地址", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("模型名称", text: $modelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    keyField(title: "API Key", text: $apiKey, visible: $showTextKey)
                } header: {
                    Text("文本模型")
                } footer: {
                    Text("OpenAI 兼容格式。默认指向阿里云百炼，换成别家只改地址和模型名。")
                }

                Section {
                    TextField("请求地址", text: $imageBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("模型名称", text: $imageModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    keyField(title: "API Key", text: $imageKey, visible: $showImageKey)
                } header: {
                    Text("插画模型（可留空）")
                } footer: {
                    Text("填了 Key 才会真的画插画；留空就用内置的 18 个简笔画。插画风格固定为彩色简笔画，不随模型变化。")
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack(spacing: 6) {
                            if testing { ProgressView().controlSize(.small) }
                            Text(testing ? "正在测试…" : "测试连接")
                        }
                    }
                    .disabled(testing || mock)

                    if let testResult {
                        Text(testResult)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("配置只保存在这台设备上，不会上传，也不写进代码。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(DocumentStore.shared.isCloudAvailable
                         ? "iCloud 已连接，纸条会在设备间同步（不含 Key）。"
                         : "iCloud 不可用，纸条只保存在本机。")
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

    @ViewBuilder
    private func keyField(title: String, text: Binding<String>, visible: Binding<Bool>) -> some View {
        HStack {
            if visible.wrappedValue {
                TextField(title, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField(title, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Button(visible.wrappedValue ? "隐藏" : "显示") {
                visible.wrappedValue.toggle()
            }
            .font(.system(size: 13))
        }
    }

    private func load() {
        baseURL = model.config.baseURL
        apiKey = model.config.apiKey
        modelName = model.config.model
        mock = model.config.mock

        imageBaseURL = model.imageConfig.baseURL
        imageKey = model.imageConfig.apiKey
        imageModel = model.imageConfig.model
    }

    private func save() {
        model.config.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        model.config.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
        model.config.model = modelName.trimmingCharacters(in: .whitespaces)
        model.config.mock = mock

        model.imageConfig.baseURL = imageBaseURL.trimmingCharacters(in: .whitespaces)
        model.imageConfig.apiKey = imageKey.trimmingCharacters(in: .whitespaces)
        model.imageConfig.model = imageModel.trimmingCharacters(in: .whitespaces)

        model.persist()
    }

    private func test() async {
        testing = true
        testResult = "正在测试…"
        defer { testing = false }

        var config = model.config
        config.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        config.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
        config.model = modelName.trimmingCharacters(in: .whitespaces)
        config.mock = false

        do {
            let analysis = try await AIClient.analyze(text: "这是一段测试文字，用来检查模型接口是否通。", config: config)
            testResult = "连接正常，返回 \(analysis.emphasis.count) 个强调词、\(analysis.illustrationSubjects.count) 个插画主体"
        } catch {
            testResult = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
