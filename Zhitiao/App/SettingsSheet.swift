import SwiftUI

/// 设置：文本模型 + 插画模型。
///
/// H5 版的地址、Key、模型名放在 `.env.local` 里由 Vite 注入；原生 App 没有构建期注入这一层，
/// 改成在 App 内填写，存本机 UserDefaults（不进代码库、不随安装包分发）。
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
                    LabeledContent("版本", value: Self.version)
                } footer: {
                    Text("纸条 · 把文字做成一张排版精美的图片")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 1.0 (1)
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /* AI 相关设置暂时下线，代码保留在这里，恢复时把上面的 body 换回下面这段即可。
       同时需要恢复：CardTab 的 element/emphasis/illustration 三个 case、
       OptionsPanel 里对应的三段实现、Renderer 里的元素/强调/插画绘制。

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("调试模式（不联网，用本地规则）", isOn: $mock)
                } footer: {
                    Text("打开调试模式时不发请求，强调词和插画都由本地规则给。")
                }

                Section {
                    TextField("请求地址", text: $baseURL)
                    TextField("模型名称", text: $modelName)
                    keyField(title: "API Key", text: $apiKey, visible: $showTextKey)
                } header: {
                    Text("文本模型")
                } footer: {
                    Text("OpenAI 兼容格式。默认指向阿里云百炼，换成别家只改地址和模型名。")
                }

                Section {
                    TextField("请求地址", text: $imageBaseURL)
                    TextField("模型名称", text: $imageModel)
                    keyField(title: "API Key", text: $imageKey, visible: $showImageKey)
                } header: {
                    Text("插画模型（可留空）")
                }

                Section {
                    Button { Task { await test() } } label: {
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
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }
    */

    /* AI 相关，暂时下线
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
    */
}
