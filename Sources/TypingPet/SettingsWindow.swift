import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class TypingPetSettingsModel: ObservableObject {
    @Published private(set) var imageSets: [PetImageSet] = []
    @Published var selectedSetID: UUID?
    @Published private(set) var activeSetID: UUID
    @Published private(set) var rules: [KeyReactionRule] = []
    @Published private(set) var scale: Double
    @Published private(set) var restingOpacity: Double
    @Published private(set) var hoverOpacity: Double
    @Published private(set) var shakeLevel: Int
    @Published private(set) var alwaysOnTop: Bool
    @Published private(set) var positionLocked: Bool
    @Published private(set) var avoidsPointerWhenLocked: Bool
    @Published private(set) var launchAtLogin: Bool
    @Published var errorMessage: String?

    let library: PetImageLibrary
    let keyStore: KeyReactionStore
    private let applyScale: (CGFloat) -> Void
    private let applyRestingOpacity: (CGFloat) -> Void
    private let applyHoverOpacity: (CGFloat) -> Void
    private let applyShake: (Int) -> Void
    private let applyAlwaysOnTop: (Bool) -> Void
    private let applyPositionLock: (Bool) -> Void
    private let applyPointerAvoidance: (Bool) -> Void
    private let reloadPet: () -> Void
    private let openInputMonitoringSettingsAction: () -> Void

    init(
        library: PetImageLibrary,
        keyStore: KeyReactionStore,
        scale: CGFloat,
        restingOpacity: CGFloat,
        hoverOpacity: CGFloat,
        shakeLevel: Int,
        alwaysOnTop: Bool,
        positionLocked: Bool,
        avoidsPointerWhenLocked: Bool,
        applyScale: @escaping (CGFloat) -> Void,
        applyRestingOpacity: @escaping (CGFloat) -> Void,
        applyHoverOpacity: @escaping (CGFloat) -> Void,
        applyShake: @escaping (Int) -> Void,
        applyAlwaysOnTop: @escaping (Bool) -> Void,
        applyPositionLock: @escaping (Bool) -> Void,
        applyPointerAvoidance: @escaping (Bool) -> Void,
        reloadPet: @escaping () -> Void,
        openInputMonitoringSettings: @escaping () -> Void
    ) {
        self.library = library
        self.keyStore = keyStore
        self.scale = Double(scale)
        self.restingOpacity = Double(restingOpacity)
        self.hoverOpacity = Double(hoverOpacity)
        self.shakeLevel = shakeLevel
        self.alwaysOnTop = alwaysOnTop
        self.positionLocked = positionLocked
        self.avoidsPointerWhenLocked = avoidsPointerWhenLocked
        self.applyScale = applyScale
        self.applyRestingOpacity = applyRestingOpacity
        self.applyHoverOpacity = applyHoverOpacity
        self.applyShake = applyShake
        self.applyAlwaysOnTop = applyAlwaysOnTop
        self.applyPositionLock = applyPositionLock
        self.applyPointerAvoidance = applyPointerAvoidance
        self.reloadPet = reloadPet
        openInputMonitoringSettingsAction = openInputMonitoringSettings
        activeSetID = library.activeSetID
        selectedSetID = library.activeSetID
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refresh()
    }

    var selectedSet: PetImageSet? { imageSets.first { $0.id == selectedSetID } }
    var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    func thumbnail(for set: PetImageSet) -> NSImage? {
        library.idleURL(for: set).flatMap(NSImage.init(contentsOf:))
    }

    func ruleImage(for rule: KeyReactionRule) -> NSImage? {
        keyStore.imageURL(for: rule).flatMap(NSImage.init(contentsOf:))
    }

    func refresh() {
        imageSets = library.imageSets
        activeSetID = library.activeSetID
        rules = keyStore.rules
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setScale(_ value: Double) {
        scale = value
        applyScale(CGFloat(value))
    }

    func syncScale(_ value: CGFloat) {
        scale = Double(value)
    }

    func setRestingOpacity(_ value: Double) {
        restingOpacity = value
        applyRestingOpacity(CGFloat(value))
    }

    func setHoverOpacity(_ value: Double) {
        hoverOpacity = value
        applyHoverOpacity(CGFloat(value))
    }

    func setShakeLevel(_ value: Int) {
        shakeLevel = value
        applyShake(value)
    }

    func setAlwaysOnTop(_ value: Bool) {
        alwaysOnTop = value
        applyAlwaysOnTop(value)
    }

    func setPositionLocked(_ value: Bool) {
        positionLocked = value
        applyPositionLock(value)
    }

    func setPointerAvoidance(_ value: Bool) {
        avoidsPointerWhenLocked = value
        applyPointerAvoidance(value)
    }

    func toggleLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = value
        } catch {
            errorMessage = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func activateSelectedSet() {
        guard let id = selectedSetID else { return }
        do {
            try library.activateSet(id: id)
            activeSetID = id
            reloadPet()
        } catch { errorMessage = error.localizedDescription }
    }

    func importImageSet() {
        let panel = NSOpenPanel()
        panel.title = "이미지 세트 폴더 추가"
        panel.message = "idle.* 또는 pet-idle.*는 대기 이미지로, 나머지는 반응 이미지로 가져옵니다."
        panel.prompt = "갤러리에 추가"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let set = try library.addSet(from: url)
            selectedSetID = set.id
            refresh()
            reloadPet()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteSelectedSet() {
        guard let set = selectedSet, !set.isBuiltIn else { return }
        let alert = NSAlert()
        alert.messageText = "‘\(set.name)’ 세트를 목록에서 제거할까요?"
        alert.informativeText = "원본 이미지에는 영향을 주지 않습니다."
        alert.addButton(withTitle: "제거")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try library.deleteSet(id: set.id)
            selectedSetID = library.activeSetID
            refresh()
            reloadPet()
        } catch { errorMessage = error.localizedDescription }
    }

    func renameSelectedSet() {
        guard let set = selectedSet, !set.isBuiltIn else { return }
        let field = NSTextField(string: set.name)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        let alert = NSAlert()
        alert.messageText = "이미지 세트 이름 변경"
        alert.accessoryView = field
        alert.addButton(withTitle: "변경")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try library.renameSet(id: set.id, to: field.stringValue)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func addRule(stroke: KeyStroke, imageURL: URL) {
        do {
            try keyStore.setRule(for: stroke, image: imageURL)
            rules = keyStore.rules
        } catch { errorMessage = error.localizedDescription }
    }

    func removeRule(_ rule: KeyReactionRule) {
        keyStore.removeRule(id: rule.id)
        rules = keyStore.rules
    }

    func openInputMonitoringSettings() {
        openInputMonitoringSettingsAction()
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(model: TypingPetSettingsModel, todoStore: TodoStore, updater: UpdateController) {
        let root = SettingsRootView(model: model, todoStore: todoStore, updater: updater)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = AppEnvironment.displayName + " 설정"
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 700, height: 540)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct SettingsRootView: View {
    @ObservedObject var model: TypingPetSettingsModel
    @ObservedObject var todoStore: TodoStore
    let updater: UpdateController

    var body: some View {
        TabView {
            GeneralSettingsView(model: model, updater: updater)
                .tabItem { Label("일반", systemImage: "gearshape") }
            TodoSettingsView(store: todoStore)
                .tabItem { Label("할 일", systemImage: "checklist") }
            GallerySettingsView(model: model)
                .tabItem { Label("갤러리", systemImage: "photo.on.rectangle.angled") }
            KeyReactionSettingsView(model: model)
                .tabItem { Label("키 반응", systemImage: "keyboard") }
        }
        .padding(SettingsMetrics.space4)
        .alert("오류", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("확인") { model.errorMessage = nil } } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private enum SettingsMetrics {
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space6: CGFloat = 24
    static let labelWidth: CGFloat = 132
    static let rowHeight: CGFloat = 40
}

private struct FlatSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.space2) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight, alignment: .leading)
    }
}

private struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        SettingsRow {
            HStack(spacing: SettingsMetrics.space3) {
                Text(title)
                    .frame(width: SettingsMetrics.labelWidth, alignment: .leading)
                Slider(value: $value, in: range)
                Text("\(Int(value * 100))%")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        SettingsRow {
            HStack(spacing: SettingsMetrics.space3) {
                Text(title)
                Spacer(minLength: SettingsMetrics.space3)
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
        }
        .disabled(!isEnabled)
    }
}

private struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, SettingsMetrics.space2)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: TypingPetSettingsModel
    @ObservedObject var updater: UpdateController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.space6) {
                FlatSettingsSection("펫") {
                    VStack(spacing: 0) {
                        SettingsSliderRow(
                            title: "크기",
                            value: Binding(get: { model.scale }, set: model.setScale),
                            range: 0.35...1.25
                        )
                        Divider()
                        SettingsSliderRow(
                            title: "상시 투명도",
                            value: Binding(get: { model.restingOpacity }, set: model.setRestingOpacity),
                            range: 0...1
                        )
                        Divider()
                        SettingsSliderRow(
                            title: "호버 시 투명도",
                            value: Binding(get: { model.hoverOpacity }, set: model.setHoverOpacity),
                            range: 0...1
                        )
                        Divider()
                        SettingsNote(text: "100%는 선명하게, 0%는 완전히 투명하게 표시됩니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("통통 튀는 정도")
                                Spacer(minLength: SettingsMetrics.space3)
                                Picker("", selection: Binding(get: { model.shakeLevel }, set: model.setShakeLevel)) {
                                    Text("끔").tag(0)
                                    Text("약하게").tag(1)
                                    Text("보통").tag(2)
                                    Text("강하게").tag(3)
                                }
                                .labelsHidden()
                                .frame(width: 112)
                            }
                        }
                        Divider()
                        SettingsToggleRow(
                            title: "항상 다른 창 위에 표시",
                            isOn: Binding(get: { model.alwaysOnTop }, set: model.setAlwaysOnTop)
                        )
                        Divider()
                        SettingsToggleRow(
                            title: "위치 잠금 (클릭 통과)",
                            isOn: Binding(get: { model.positionLocked }, set: model.setPositionLocked)
                        )
                        Divider()
                        SettingsToggleRow(
                            title: "위치 잠금 중 마우스 피하기",
                            isOn: Binding(get: { model.avoidsPointerWhenLocked }, set: model.setPointerAvoidance),
                            isEnabled: model.positionLocked
                        )
                        Divider()
                        SettingsNote(text: "커서가 가까워지면 펫이 화면 안에서 부드럽게 자리를 비킵니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                FlatSettingsSection("시스템") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: "로그인 시 자동 실행",
                            isOn: Binding(get: { model.launchAtLogin }, set: model.toggleLaunchAtLogin)
                        )
                        Divider()
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Label(
                                    model.inputMonitoringGranted ? "입력 모니터링 권한 허용됨" : "입력 모니터링 권한 필요",
                                    systemImage: model.inputMonitoringGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(model.inputMonitoringGranted ? .green : .orange)
                                Spacer(minLength: SettingsMetrics.space3)
                                Button("시스템 설정 열기") { model.openInputMonitoringSettings() }
                            }
                        }
                        Divider()
                        SettingsNote(text: "키 조합 판별에는 물리 키 코드와 보조 키만 사용하며, 입력 문자는 저장하거나 전송하지 않습니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                FlatSettingsSection("업데이트") {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                VStack(alignment: .leading, spacing: SettingsMetrics.space1) {
                                    Text("현재 버전 \(updater.currentVersionText)")
                                    Text(updater.statusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: SettingsMetrics.space3)
                                if updater.isBusy { ProgressView().controlSize(.small) }
                                Button(updater.menuTitle) { updater.performPrimaryAction() }
                                    .disabled(updater.isBusy || updater.unavailableReason != nil)
                            }
                            .padding(.vertical, SettingsMetrics.space2)
                        }
                        Divider()
                        SettingsToggleRow(
                            title: "자동으로 업데이트 확인",
                            isOn: $updater.automaticChecks,
                            isEnabled: updater.unavailableReason == nil
                        )
                        Divider()
                        SettingsNote(text: "하루에 한 번 pet.miel.ing에서 새 버전을 확인합니다. 앱 버전 외의 정보는 보내지 않으며, 서명을 확인한 업데이트만 설치합니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(SettingsMetrics.space4)
        }
    }
}

private struct TodoSettingsView: View {
    @ObservedObject var store: TodoStore

    private var enabled: Bool { store.engine.state.featurePreferences.enabled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.space6) {
                FlatSettingsSection("할 일과 집중 타이머") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: "할 일 기능 사용",
                            isOn: Binding(get: { enabled }, set: { value in
                                store.expanded = true
                                store.change { $0.setFeature(enabled: value, hidden: false) }
                            }),
                            isEnabled: !store.loadBlocked
                        )
                        Divider()
                        SettingsToggleRow(
                            title: "말풍선 표시",
                            isOn: Binding(
                                get: { !store.engine.state.featurePreferences.bubbleHidden },
                                set: { value in if value { store.show() } else { store.hide() } }
                            ),
                            isEnabled: enabled && !store.loadBlocked
                        )
                        Divider()
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("자리 비움 감지")
                                Spacer(minLength: SettingsMetrics.space3)
                                Picker("", selection: Binding(get: { store.idleMinutes }, set: store.setIdleMinutes)) {
                                    ForEach(TodoStore.idleMinuteChoices, id: \.self) { minutes in
                                        Text(minutes == 0 ? "끔" : (minutes < 60 ? "\(minutes)분 후" : "\(minutes / 60)시간 후")).tag(minutes)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 168)
                            }
                        }
                        .disabled(!enabled || store.loadBlocked)
                        Divider()
                        SettingsNote(text: store.idleMinutes == 0
                            ? "말풍선을 숨겨도 실행 중인 타이머는 유지합니다. 잠자기와 앱 종료 시에는 일시정지합니다."
                            : "타이머가 도는 동안 \(store.idleMinutes < 60 ? "\(store.idleMinutes)분" : "\(store.idleMinutes / 60)시간") 넘게 키보드와 마우스 입력이 없거나, 화면을 잠그거나, Mac이 잠자기에 들어가면 일시정지하고 마지막 입력 이후의 시간은 기록에서 뺍니다. 돌아오면 말풍선에서 그 시간을 포함할지 고를 수 있어요. 말풍선을 숨겨도 타이머는 유지됩니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                FlatSettingsSection("말풍선") {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("크기")
                                    .frame(width: SettingsMetrics.labelWidth, alignment: .leading)
                                Spacer(minLength: SettingsMetrics.space3)
                                HStack(spacing: SettingsMetrics.space1) {
                                    ZoomStepButton(symbol: "minus", label: "작게 보기", enabled: store.canZoomOut) { store.zoomOut() }
                                    Text("\(store.zoomPercent)%")
                                        .monospacedDigit()
                                        .frame(width: 52)
                                        .accessibilityLabel("말풍선 크기 \(store.zoomPercent)%")
                                    ZoomStepButton(symbol: "plus", label: "크게 보기", enabled: store.canZoomIn) { store.zoomIn() }
                                }
                                Button("100%로") { store.resetZoom() }
                                    .disabled(store.zoom == 1)
                            }
                        }
                        Divider()
                        SettingsNote(text: "브라우저처럼 80%부터 200%까지 단계별로 바뀝니다. 말풍선에 입력하는 중에는 ⌘+, ⌘−, ⌘0으로도 조절할 수 있어요.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("목록 보기")
                                Spacer(minLength: SettingsMetrics.space3)
                                Picker("", selection: Binding(get: { store.listStyle }, set: store.setListStyle)) {
                                    Text("풀 뷰").tag(TodoListStyle.full)
                                    Text("컴팩트 뷰").tag(TodoListStyle.compact)
                                }
                                .labelsHidden()
                                .frame(width: 168)
                            }
                        }
                        Divider()
                        SettingsNote(text: "컴팩트 뷰는 할 일을 3개까지 한 줄씩만 보여 줘서 자리를 덜 차지해요. 체크는 바로 하고, 타이머는 할 일을 우클릭해서 시작하거나 멈춰요. 추가나 수정은 말풍선에 마우스를 올리면 나오는 ⤢ 버튼으로 풀 뷰를 열어서 해요.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("표시 방식")
                                Spacer(minLength: SettingsMetrics.space3)
                                Picker("", selection: Binding(get: { store.bubbleVisibility }, set: store.setBubbleVisibility)) {
                                    Text("항상 표시").tag(TodoBubbleVisibility.always)
                                    Text("마우스를 올렸을 때").tag(TodoBubbleVisibility.hover)
                                }
                                .labelsHidden()
                                .frame(width: 168)
                            }
                        }
                        Divider()
                        SettingsSliderRow(
                            title: "상시 투명도",
                            value: Binding(get: { store.bubbleRestingOpacity }, set: store.setBubbleRestingOpacity),
                            range: 0...1
                        )
                        .disabled(store.bubbleVisibility == .hover)
                        Divider()
                        SettingsSliderRow(
                            title: "호버 시 투명도",
                            value: Binding(get: { store.bubbleHoverOpacity }, set: store.setBubbleHoverOpacity),
                            range: 0...1
                        )
                        Divider()
                        SettingsNote(text: store.bubbleVisibility == .always
                            ? "100%는 선명하게, 0%는 완전히 투명하게 표시됩니다. 펫이나 말풍선에 마우스를 올리면 호버 시 투명도를 씁니다. 입력 중이거나 집중 시간이 끝났을 때는 항상 선명하게 보여요."
                            : "펫에 마우스를 올리면 말풍선이 호버 시 투명도로 나타나고, 말풍선 위에 있는 동안 유지됩니다. 입력 중이거나 집중 시간이 끝났을 때는 항상 선명하게 보여요.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                FlatSettingsSection("기록") {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack(spacing: SettingsMetrics.space3) {
                                Text("기록 파일")
                                Spacer(minLength: SettingsMetrics.space3)
                                Button("기록 데이터 열기") { NSWorkspace.shared.activateFileViewerSelecting([store.storage.url]) }
                            }
                        }
                        Divider()
                        Text(store.storage.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, SettingsMetrics.space2)
                        SettingsNote(text: "할 일 제목, 완료 날짜, 타이머 설정과 실제 집중 시간을 이 Mac의 JSON 파일에 저장합니다.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let error = store.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(SettingsMetrics.space4)
        }
    }
}

// Both steps share one frame, so the minus and plus buttons render at the same size.
private struct ZoomStepButton: View {
    let symbol: String
    let label: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 16, height: 16)
        }
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct GallerySettingsView: View {
    @ObservedObject var model: TypingPetSettingsModel
    private let columns = [GridItem(.adaptive(minimum: 152, maximum: 192), spacing: SettingsMetrics.space4)]

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.space4) {
            HStack(spacing: SettingsMetrics.space3) {
                Text("이미지 세트").font(.title2).bold()
                Spacer()
                Button { model.importImageSet() } label: { Label("폴더 추가", systemImage: "plus") }
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: SettingsMetrics.space4) {
                    ForEach(model.imageSets) { set in
                        GalleryCard(set: set, image: model.thumbnail(for: set), active: set.id == model.activeSetID, selected: set.id == model.selectedSetID)
                            .onTapGesture { model.selectedSetID = set.id }
                    }
                }
                .padding(SettingsMetrics.space1)
            }
            Divider()
            HStack(spacing: SettingsMetrics.space2) {
                if let set = model.selectedSet {
                    Text("\(set.name) · 반응 이미지 \(model.library.reactionURLs(for: set).count)장")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("이름 변경") { model.renameSelectedSet() }.disabled(model.selectedSet?.isBuiltIn != false)
                Button("제거") { model.deleteSelectedSet() }.disabled(model.selectedSet?.isBuiltIn != false)
                Button("적용") { model.activateSelectedSet() }.buttonStyle(.borderedProminent).disabled(model.selectedSetID == model.activeSetID)
            }
        }
        .padding(SettingsMetrics.space4)
    }
}

private struct GalleryCard: View {
    let set: PetImageSet
    let image: NSImage?
    let active: Bool
    let selected: Bool

    var body: some View {
        VStack(spacing: SettingsMetrics.space2) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: SettingsMetrics.space2)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 112)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(SettingsMetrics.space3)
                        .frame(maxWidth: .infinity, maxHeight: 112)
                }
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(SettingsMetrics.space2)
                }
            }
            Text(set.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SettingsMetrics.space3)
        .background(RoundedRectangle(cornerRadius: SettingsMetrics.space3).fill(selected ? Color.accentColor.opacity(0.13) : .clear))
        .overlay(RoundedRectangle(cornerRadius: SettingsMetrics.space3).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1))
    }
}

private struct KeyReactionSettingsView: View {
    @ObservedObject var model: TypingPetSettingsModel
    @State private var pendingImageURL: URL?
    @State private var isCapturing = false

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.space4) {
            HStack(spacing: SettingsMetrics.space3) {
                VStack(alignment: .leading, spacing: SettingsMetrics.space1) {
                    Text("특정 키 반응").font(.title2).bold()
                    Text("등록한 키 또는 키 조합에는 지정한 이미지가 우선 표시됩니다.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { chooseImage() } label: { Label("규칙 추가", systemImage: "plus") }
            }
            if model.rules.isEmpty {
                VStack(spacing: SettingsMetrics.space2) {
                    Image(systemName: "keyboard").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("등록된 키 반응이 없습니다").font(.headline)
                    Text("규칙 추가를 눌러 이미지와 키 조합을 지정하세요.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.rules) { rule in
                    HStack(spacing: SettingsMetrics.space3) {
                        Group {
                            if let image = model.ruleImage(for: rule) { Image(nsImage: image).resizable().scaledToFit() }
                            else { Image(systemName: "photo") }
                        }.frame(width: 46, height: 46)
                        Text(rule.stroke.displayName).font(.system(size: 16, weight: .semibold, design: .rounded))
                        Spacer()
                        Button(role: .destructive) { model.removeRule(rule) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, SettingsMetrics.space2)
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: SettingsMetrics.space1,
                        bottom: 0,
                        trailing: SettingsMetrics.space1
                    ))
                }
                .listStyle(.plain)
            }
        }
        .padding(SettingsMetrics.space4)
        .sheet(isPresented: $isCapturing) {
            KeyCaptureSheet { stroke in
                if let url = pendingImageURL { model.addRule(stroke: stroke, imageURL: url) }
                pendingImageURL = nil
                isCapturing = false
            } onCancel: {
                pendingImageURL = nil
                isCapturing = false
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "키 반응 이미지 선택"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImageURL = url
        isCapturing = true
    }
}

private struct KeyCaptureSheet: View {
    let onCapture: (KeyStroke) -> Void
    let onCancel: () -> Void
    @State private var captured: KeyStroke?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 42)).foregroundStyle(.tint)
            Text("사용할 키 또는 키 조합을 누르세요").font(.title3).bold()
            Text(captured?.displayName ?? "예: K, ⌘K, ⌃⌥Space")
                .font(.system(size: 22, weight: .semibold, design: .rounded)).frame(minHeight: 32)
            KeyCaptureView { captured = $0 }.frame(width: 1, height: 1)
            HStack {
                Button("취소", action: onCancel)
                Button("등록") { if let captured { onCapture(captured) } }
                    .buttonStyle(.borderedProminent).disabled(captured == nil)
            }
        }.padding(32).frame(width: 420, height: 260)
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let onCapture: (KeyStroke) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) { nsView.onCapture = onCapture }

    final class CaptureNSView: NSView {
        var onCapture: ((KeyStroke) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in if let self { self.window?.makeFirstResponder(self) } }
        }
        override func keyDown(with event: NSEvent) {
            let modifiers = KeyModifiers(eventFlags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            onCapture?(KeyStroke(keyCode: event.keyCode, modifiers: modifiers))
        }
    }
}
