import SwiftUI
import UIKit
import PhotosUI

struct ContentView: View {
    enum Destination: Hashable {
        case projects
        case discovery
        case learning
        case voices
        case memory
        case documents
        case history
        case journal
        case settings
        case about
    }
    
    /// Day or Night (from Settings → Appearance, or the phone's setting).
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(SettingsKeys.appearance) private var appearance = Appearance.automatic
    /// First-run welcome (shown once; About can show it again).
    @AppStorage(SettingsKeys.welcomed) private var welcomed = false
    /// The one-time "New: Concierge" hint above the ask bar.
    @AppStorage("ns.conciergeHintSeen") private var conciergeHintSeen = false

    private func applyWindowLook() {
        // Discovery is the start screen now, so chat always follows Settings → Appearance (even when empty).
        appearance.apply()
    }

    @State private var awaitingMemorySave = false
    
    @State private var detectedMemoryCandidate: MemoryCandidate?
    @State private var isSavingDetectedMemory = false

    private let memoryDetector = MemoryDetector()
    private let memoryService = MemoryService()

    private var memoryIdentityId: UUID? {
        SupabaseManager.shared.currentUserId
    }
    private let projectMemoryKey = "northstarCurrentProject"

    @State private var livePDFText = ""
    @State private var isLivePDFDraftPresented = false
    @State private var generatedPDFURL: URL?
    @State private var isPDFSharePresented = false
    @State private var documentStep = 0
    @State private var documentType = ""

    @State private var websiteType = ""
    @State private var websiteName = ""
    @State private var websiteServices = ""
    @State private var webDesignStep = 0
    @State private var currentWorkflow: NorthstarIntent?

    @State private var navigationPath: [Destination] = []
    /// The saved chat this conversation belongs to (nil until the first message, or with memory off).
    @State private var currentChatId: UUID?
    /// The chat that was open last time, so closing the app (even by mistake) never loses it.
    /// Cleared only when they tap New chat (or the chat is deleted).
    @AppStorage("ns.openChatId") private var openChatId = ""
    /// ✦ The one-time "Keep your memory safe" card (after the 3rd thing kept).
    @State private var showKeepSafe = false
    @State private var isFeedbackPresented = false
    private let chatsService = ChatsService()
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var appleAccount = AppleAccount.shared
    @State private var viewModel = ChatViewModel()
    @State private var isCameraPresented = false
    @State private var isPhotoLibraryPresented = false
    @State private var isConciergePresented = false
    /// The photo picked in Apple's photo picker (Photo Library opens it straight away).
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var promptText = ""
    @State private var isThinking = false
    /// Replies whose "From before" card was used or set aside (survives scrolling).
    @State private var fromBeforeDone: Set<UUID> = []
    /// Subject cards per reply: "kept", "dismissed" or "undone" (survives scrolling).
    @State private var subjectStates: [UUID: String] = [:]
    private let subjectsService = SubjectsService()
    /// Pills the person removed since the last message; sent once as corrections.
    @State private var pendingCorrections: [String] = []
    @State private var isStarMenuPresented = false
    /// ✦ Discovery: explore ways forward around the star (opened by the star button).
    @State private var isDiscoveryPresented = false
    @State private var responseTask: Task<Void, Never>?
    @FocusState private var isPromptFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWelcomeMessageVisible = true
    /// Launch screen (approved): star, wordmark, tagline and mountains only, no ask bar.
    /// The bar fades in when the tagline fades out (first open only, not after New Chat).
    @State private var launching = true

    // The composer's real, measured footprint (bar + its own bottom margin),
    // used to pad the scroll content directly instead of trusting
    // .safeAreaInset's automatic content-inset propagation — that mechanism
    // isn't reliable in this view hierarchy (see NorthstarVisionLandscapeBackground's
    // .ignoresSafeArea() sibling), so the clearance is computed explicitly here.
    @State private var composerHeight: CGFloat = 0

    // Minimal, unobtrusive feedback for microphone failures (permission
    // denied, recognizer unavailable, audio session/engine failure) — never
    // added to the conversation history, just a small alert.
    @State private var microphoneErrorMessage: String?

    private let engine = NorthstarEngineClient()
    private let intelligence = NorthstarIntelligence()
    private let pdfService = PDFDocumentService()

    private var cleanedPrompt: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                VStack(spacing: 0) {
                    adaptiveHeader
                    conversationArea
                        .overlay {
                            // An empty chat: a quiet line, no start screen (Discovery is the start).
                            if viewModel.messages.isEmpty {
                                Text("What's on your mind?")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(NorthstarChatStyle.soft)
                                    .allowsHitTesting(false)
                            }
                        }
                    promptArea
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Home (star and mountains) is always Night; chats follow Day or Night.
                .environment(\.colorScheme, colorScheme)

                if isStarMenuPresented {
                    starMenu
                        .environment(\.colorScheme, .dark)
                }
            }
            // The landscape and chat veil sit BEHIND the layout as a background,
            // so they never change its size. That lets the text field rise
            // above the keyboard instead of being pushed under it.
            .background {
                ZStack {
                    NorthstarVisionLandscapeBackground()

                    // Chat veil (approved): once a conversation starts, the landscape
                    // dims and softens so long replies stay easy to read.
                    chatVeil
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                destinationView(for: destination)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !welcomed }, set: { if !$0 { welcomed = true } })) {
            WelcomeView { welcomed = true }
        }
        .fullScreenCover(isPresented: $isDiscoveryPresented) {
            DiscoveryView(
                canGoToChat: !viewModel.messages.isEmpty,
                onResult: { result in startFromDiscovery(result) },
                onMenu: {
                    isDiscoveryPresented = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        withAnimation(.easeInOut(duration: 0.25)) { isStarMenuPresented = true }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isFeedbackPresented) { FeedbackView() }
        .sheet(isPresented: $isConciergePresented) {
            ConciergeView(memory: { await memoryForEngine() })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Photo Library opens Apple's own photo picker straight away: no extra screen in between.
        // It only sees the photo the person picks (no full library permission needed).
        .photosPicker(isPresented: $isPhotoLibraryPresented, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    isPromptFocused = true
                }
                photoItem = nil
            }
        }
        .sheet(isPresented: $isLivePDFDraftPresented) {
            LivePDFDraftView(
                documentText: $livePDFText,
                isRecording: speechRecognizer.isRecording,
                onMicrophoneTapped: { toggleMicrophone() },
                onSave: { saveLivePDF() }
            )
            .preferredColorScheme(.dark)   // the live PDF draft keeps its Night look
        }
        .sheet(isPresented: $isPDFSharePresented) {
            pdfShareView
        }
        .alert(
            "Voice Input",
            isPresented: Binding(
                get: { microphoneErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { microphoneErrorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(microphoneErrorMessage ?? "")
        }
        .onChange(of: speechRecognizer.transcript) {
            if isLivePDFDraftPresented {
                livePDFText = speechRecognizer.transcript
            } else {
                promptText = speechRecognizer.transcript
            }
        }
        .task {
            await SupabaseManager.shared.signInIfNeeded()
            loadProjectMemory()
            scheduleWelcomeMessageFade()
            // Reopen the chat they were in, right where they left off.
            if viewModel.messages.isEmpty, let id = UUID(uuidString: openChatId) {
                openChat(id)
            }
            // Discovery is home: the app opens on it (their last chat waits underneath, one ✕ away).
            if welcomed { isDiscoveryPresented = true }
        }
        .onChange(of: welcomed) {
            guard welcomed else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isDiscoveryPresented = true
            }
        }
        .onChange(of: currentChatId) { openChatId = currentChatId?.uuidString ?? "" }
        // The home screen (star and mountains) is always Night, status bar included;
        // chats and other screens use Settings → Appearance.
        .onAppear { applyWindowLook() }
        .onChange(of: viewModel.messages.isEmpty) { applyWindowLook() }
        .onChange(of: navigationPath) { applyWindowLook() }
        .onChange(of: appearance) { applyWindowLook() }
        .onChange(of: appleAccount.accountChanges) {
            // Signed in to a different account (or out): start fresh so nothing mixes.
            startNewChat()
            loadProjectMemory()
        }
    }

    /// Empty conversation gets the full lockup + welcome message; an active
    /// conversation gets a small permanent header instead, so the scrolling
    /// area actually has room for tall structured-response cards. Branding
    /// lives here, as a sibling of conversationArea — never inside its
    /// ScrollView content.
    @ViewBuilder
    private var adaptiveHeader: some View {
        // No separate start screen: Discovery is the start. An empty chat is simply a chat waiting for words.
        compactHeader
            .overlay { chatTopButtons }
    }

    /// ≡ top left opens the menu; ✕ top right goes back to Discovery.
    private var chatTopButtons: some View {
        HStack {
            Button {
                isPromptFocused = false
                withAnimation(.easeInOut(duration: 0.25)) { isStarMenuPresented = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Menu")
            .accessibilityHint("Shows every place in Northstar")
            Spacer()
            Button {
                isPromptFocused = false
                isDiscoveryPresented = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to Discovery")
        }
        .padding(.horizontal, 8)
    }

    private var compactHeader: some View {
        HStack(spacing: 6) {
            if colorScheme == .light {
                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(NorthstarChatStyle.starGold)
                    .accessibilityHidden(true)
            } else {
                NorthstarVisionStarMark(size: 22)
                    .accessibilityHidden(true)
            }

            Text("Northstar")
                .font(.system(size: 14, weight: .medium))
                .tracking(2)
                .foregroundStyle(NorthstarChatStyle.soft)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    /// The large star + wordmark + welcome-message lockup, used only for the
    /// empty conversation state now (see adaptiveHeader).
    private var heroHeader: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Star + wordmark as one grouped lockup, tightly spaced so they
            // read as a single logo rather than two separate elements.
            VStack(spacing: 6) {
                NorthstarVisionStarMark(size: 72)
                    .accessibilityHidden(true)

                Text("Northstar")
                    .font(.system(size: 30, weight: .light))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 10)

            VStack(spacing: 3) {
                Text("One clear destination.")
                Text("An intelligent path forward.")
            }
            .font(.system(size: 13, weight: .regular))
            .tracking(0.4)
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .opacity(showWelcomeMessage ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityHidden(!showWelcomeMessage)

            Spacer(minLength: 16)
        }
    }

    /// Visible only while truly empty — hides immediately once a message
    /// exists (not just after the fade timer), and the timer independently
    /// hides it if the user leaves the screen untouched.
    private var showWelcomeMessage: Bool {
        isWelcomeMessageVisible && viewModel.messages.isEmpty
    }

    /// Re-armed on every fresh empty state (initial launch and after New Chat)
    /// so the welcome message replays instead of staying permanently faded.
    private func scheduleWelcomeMessageFade() {
        isWelcomeMessageVisible = true
        Task {
            try? await Task.sleep(for: .seconds(2.75))
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.6)) { launching = false }
            guard viewModel.messages.isEmpty else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.6)) {
                isWelcomeMessageVisible = false
            }
        }
    }

    /// Dark navy veil over the landscape while chatting. Home stays clear.
    private var chatVeil: some View {
        ZStack {
            if colorScheme == .light {
                // Day: a solid cream page over the landscape, for easy reading.
                NorthstarChatStyle.background
            } else {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.09, blue: 0.21).opacity(0.55),
                        Color(red: 0.05, green: 0.09, blue: 0.21).opacity(0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(1)
        .accessibilityHidden(true)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.messages) { message in
                        if message.role == .user {
                            UserMessageView(text: message.content, image: message.image)
                        } else {
                            NorthstarReplyView(
                                text: message.content,
                                insight: message.insight,
                                onSave: saveSuggestion,
                                onUndo: undoSave,
                                onRemovePill: { pendingCorrections.append($0) },
                                onChooseDirection: chooseDirection,
                                chosenDirection: chosenDirection(after: message),
                                canChooseDirection: !isThinking && message.id == viewModel.messages.last?.id,
                                onUseFromBefore: { note in
                                    fromBeforeDone.insert(message.id)
                                    useFromBefore(note)
                                },
                                fromBeforeDone: fromBeforeDone.contains(message.id),
                                onDismissFromBefore: { fromBeforeDone.insert(message.id) },
                                subjectState: subjectStates[message.id],
                                onKeepSubject: { offer in keepSubject(offer, for: message.id) },
                                onDismissSubject: { subjectStates[message.id] = "dismissed" },
                                onUndoSubject: { update in undoSubject(update, for: message.id) },
                                wholeChat: { ChatExport.lines(viewModel.messages) }
                            )
                        }
                    }

                    if showKeepSafe && !isThinking {
                        KeepMemoryCard { withAnimation { showKeepSafe = false } }
                            .transition(.opacity)
                    }

                    if isThinking {
                        NorthstarThinkingStar()
                            .id("THINKING")
                            .transition(.opacity)
                    }

                    // Sized to the composer's real measured footprint (+16pt
                    // breathing room) rather than a fixed 1pt marker — this is
                    // what actually guarantees the last message clears the
                    // composer when scrolled to bottom, regardless of whether
                    // .safeAreaInset is correctly shrinking this ScrollView's
                    // own viewport in this hierarchy.
                    Color.clear
                        .frame(height: composerHeight + 40)
                        .id("CHAT_BOTTOM")
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { isPromptFocused = false }
            .onChange(of: viewModel.messages.count) {
                scrollToLatestMessage(proxy)
            }
            .onChange(of: isThinking) {
                // Keep the thinking star in view, just above the ask bar.
                guard isThinking else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom) }
                }
            }
        }
    }

    private var promptArea: some View {
        composerBox
        .opacity(launching ? 0 : 1)
        .allowsHitTesting(!launching)
        .accessibilityHidden(launching)
        .padding(.horizontal, 6)
        .padding(.bottom, isPromptFocused ? 8 : 46)
        .animation(.easeOut(duration: 0.2), value: isPromptFocused)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { newHeight in
            composerHeight = newHeight
        }
    }

    /// Shown once so people know the bell is there; tapping it (or ✕) hides it for good.
    private var conciergeHint: some View {
        HStack(spacing: 8) {
            Button {
                conciergeHintSeen = true
                isPromptFocused = false
                isConciergePresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(NorthstarChatStyle.starGold)
                    Text("New: Concierge. Dinner, classes, fun and more.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.text)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the Concierge")
            Button {
                withAnimation(.easeOut(duration: 0.2)) { conciergeHintSeen = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NorthstarChatStyle.label)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide this tip")
        }
        .padding(.leading, 6)
        .transition(.opacity)
    }

    /// 🛎 Opens the Concierge: dinner, fitness, fun, travel, errands, gifts. In the ask bar by the star, on every screen.
    private var conciergeButton: some View {
        Button {
            isPromptFocused = false
            conciergeHintSeen = true
            isConciergePresented = true
        } label: {
            Image(systemName: "bell")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(NorthstarChatStyle.text)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Concierge")
        .accessibilityHint("Find dinner, classes, things to do, travel and more")
    }

    private var composerBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selectedImage {
                attachedPhoto(selectedImage)
            } else if !conciergeHintSeen {
                conciergeHint
            }
            promptRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background {
            // Frosted glass: the scene blurs through, with a soft white tint.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                NorthstarChatStyle.cardStrong
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1)
        }
        .shadow(color: Color(red: 0.45, green: 0.55, blue: 1.0).opacity(0.18), radius: 16)
        .animation(.easeOut(duration: 0.2), value: selectedImage != nil)
    }

    /// The photo waiting to be sent: a small rounded thumbnail with an ✕ to remove it.
    private func attachedPhoto(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
                    .accessibilityLabel("Attached photo")
                Button {
                    self.selectedImage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NorthstarChatStyle.onPrimary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(NorthstarChatStyle.primaryFill))
                        .frame(width: 44, height: 44)   // easy to tap
                        .contentShape(Rectangle())
                }
                .offset(x: 14, y: -14)
                .accessibilityLabel("Remove photo")
            }
            Text("Ask about this photo")
                .font(.footnote)
                .foregroundStyle(NorthstarChatStyle.label)
        }
        .padding(.leading, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var promptRow: some View {
        HStack(spacing: 10) {
            // ✦ opens Discovery; its ≡ opens the main menu.
            Button {
                isPromptFocused = false
                isDiscoveryPresented = true
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(NorthstarChatStyle.text)
                    .frame(width: 34, height: 34)
            }

            // The concierge bell sits next to the star on every screen (both are "places to go").
            conciergeButton

            // While listening: live voice bars, then their words appear as they speak.
            if speechRecognizer.isRecording {
                VoiceBars(level: speechRecognizer.level, count: promptText.isEmpty ? 14 : 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
            }

            TextField(speechRecognizer.isRecording ? "Listening\u{2026}" : "Ask Northstar...", text: $promptText, axis: .vertical)
                .focused($isPromptFocused)
                .foregroundStyle(NorthstarChatStyle.text)
                .lineLimit(1...6)
                .disabled(isThinking)
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            Button { toggleMicrophone() } label: {
                Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(speechRecognizer.isRecording ? NorthstarChatStyle.listening : NorthstarChatStyle.text)
                    .frame(width: 34, height: 34)
                    .background { ListeningRing(active: speechRecognizer.isRecording) }
            }
            .accessibilityLabel(speechRecognizer.isRecording ? "Stop listening" : "Speak")

            Button {
                isThinking ? stopResponse() : sendMessage()
            } label: {
                Image(systemName: isThinking ? "stop.fill" : "arrow.up")
                    .font(.system(size: isThinking ? 12 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(NorthstarChatStyle.sendFill) }
            }
        }
    }

    private var starMenu: some View {
        StarMenuView(
            isPresented: $isStarMenuPresented,
            onOpen: { go($0) }
        )
        .transition(
            .move(edge: .leading)
        )
        .zIndex(10)
    }

    @ViewBuilder
    private var pdfShareView: some View {
        if let generatedPDFURL {
            NavigationStack {
                VStack(spacing: 24) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Color(red: 0.74, green: 0.61, blue: 0.30))

                    Text("PDF Created")
                        .font(.system(size: 28, weight: .semibold))

                    Text(generatedPDFURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ShareLink(item: generatedPDFURL) {
                        Label("Share or Save PDF", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.25))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(32)
                .navigationTitle("Northstar Document")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPDFSharePresented = false }
                    }
                }
            }
        } else {
            Text("The PDF is unavailable.").padding()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .projects:
            // Projects: the subjects Northstar keeps (goal, decisions, next step).
            SubjectsView()
        case .discovery:
            placeholderScreen(title: "Discovery", symbol: "safari")
        case .learning:
            // 🎬 Videos: saved YouTube lessons and videos made in Northstar, in folders.
            VideoLibraryView()
        case .voices:
            // 🔊 Voices: read replies aloud, and choose the voice (premium or phone).
            VoicesView()
        case .memory:
            // Search: find anything you've said (by words and meaning).
            NotesSearchView(onOpenChat: openChat)

        case .documents:
            DocumentsView()
        case .history:
            HistoryView(onOpen: openChat, onDeleted: { id in
                if id == currentChatId { currentChatId = nil }  // the next message starts a new saved chat
            })
        case .journal:
            // Good Listener: the private journal. "Talk this through" starts a new chat with one entry.
            JournalView(onTalk: talkThrough)
        case .settings:
            NorthstarSettingsView()
        case .about:
            AboutView()
        }
    }

    private func placeholderScreen(title: String, symbol: String) -> some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .ultraLight))
                Text(title).font(.system(size: 28, weight: .light))
                Text("This Northstar area is ready to be designed.")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.label)
            }
            .foregroundStyle(NorthstarChatStyle.text)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Opens a saved chat (from History or Search) and continues it.
    private func openChat(_ id: UUID) {
        Task {
            guard let stored = try? await chatsService.messages(chatId: id), !stored.isEmpty else { return }
            responseTask?.cancel()
            responseTask = nil
            isThinking = false
            viewModel.messages = stored.map {
                MessageModel(role: $0.role == "user" ? .user : .assistant, content: $0.content)
            }
            currentChatId = id
            navigationPath.removeAll()
        }
    }

    /// Opens any place from the shared list (NorthstarDestinations): the ✦ menu and Discovery both use this.
    private func go(_ route: NorthstarRoute) {
        switch route {
        case .newChat:
            // ≡ → New Chat goes straight to a fresh chat (Roger, Oct 19). Discovery stays the start screen.
            startNewChat()
        case .camera: isCameraPresented = true
        case .photoLibrary: isPhotoLibraryPresented = true
        case .projects: open(.projects)
        case .videos: open(.learning)
        case .voices: open(.voices)
        case .memory: open(.memory)
        case .documents: open(.documents)
        case .history: open(.history)
        case .journal: open(.journal)
        case .concierge: isConciergePresented = true
        case .settings: open(.settings)
        case .about: open(.about)
        case .feedback: isFeedbackPresented = true
        }
    }

    /// My Journal → "Talk this through": a new chat whose first message is their entry (and its photo).
    private func talkThrough(_ text: String, _ image: Data?) {
        guard !isThinking else { return }
        startNewChat()
        currentWorkflow = nil
        let photo = image.flatMap { UIImage(data: $0) }
        viewModel.messages.append(MessageModel(role: .user, content: text, image: photo.flatMap { Self.smallJPEG($0) }))
        requestGeminiResponse()
    }

    private func open(_ destination: Destination) {
        isPromptFocused = false
        navigationPath.append(destination)
    }

    private func toggleMicrophone() {
        NorthstarVoice.shared.stop()   // never talk over them
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            return
        }

        Task {
            let permissionGranted = await speechRecognizer.requestPermissions()
            guard permissionGranted else {
                microphoneErrorMessage = """
                Northstar needs microphone and speech-recognition access for voice input. \
                You can enable these in Settings > Privacy & Security.
                """
                return
            }

            do {
                try speechRecognizer.startRecording()
            } catch {
                print("Speech recording failed:", error.localizedDescription)
                microphoneErrorMessage = microphoneUnavailableMessage
            }
        }
    }

    /// Simulator audio input depends on the host Mac's own microphone being
    /// forwarded in, which is a separate, unreliable permission from anything
    /// in-app — confirmed working correctly on a physical iPhone, so this
    /// wording only ever appears in Simulator builds.
    private var microphoneUnavailableMessage: String {
        #if targetEnvironment(simulator)
        return "Voice input is unavailable in this environment. Try Northstar on your iPhone or check the Mac microphone permission for Simulator."
        #else
        return "Northstar couldn't start voice input. Please try again."
        #endif
    }

    private func wantsSitemap(_ question: String) -> Bool {
        let text = question.lowercased()
        return text.contains("sitemap")
            || text.contains("site map")
            || text.contains("pages")
            || text.contains("navigation")
            || text.contains("structure")
            || text.contains("what pages")
            || text.contains("site structure")
    }

    private func sendMessage() {
        NorthstarVoice.shared.stop()
        // A photo waiting in the ask bar: send it with their words straight to the brain.
        if let photo = selectedImage, !isThinking {
            sendPhoto(photo)
            return
        }
        let question = cleanedPrompt
        guard !question.isEmpty, !isThinking else { return }
        
        let normalizedQuestion =
            question.lowercased()
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if normalizedQuestion == "northstar save to memory"
            || normalizedQuestion == "save our conversation"
            || normalizedQuestion == "northstar save our conversation"
            || normalizedQuestion == "save this conversation"
            || normalizedQuestion == "save this discussion" {

            awaitingMemorySave = true

            appendAssistantMessage(
                """
                Memory Save Requested

                What would you like me to remember?
                """
            )

            return
        }
        
        if awaitingMemorySave {
            awaitingMemorySave = false

            appendUserMessage(question)

            guard let identityId = memoryIdentityId else {
                appendAssistantMessage(
                    """
                    Memory Save Failed

                    Northstar could not identify the memory owner.
                    """
                )
                return
            }

            Task {
                do {
                    try await memoryService.saveMemory(
                        identityId: identityId,
                        projectId: nil,
                        content: question,
                        category: "Memory"
                    )

                    await MainActor.run {
                        appendAssistantMessage(
                            """
                            Memory Saved

                            \(question)
                            """
                        )
                    }

                } catch {
                    await MainActor.run {
                        appendAssistantMessage(
                            """
                            Memory Save Failed

                            Nothing was added to permanent memory.
                            """
                        )
                    }

                    print(
                        "Memory save failed:",
                        error.localizedDescription
                    )
                }
            }

            return
        }
        

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }

        isPromptFocused = false

        if currentWorkflow == .documentCreation {
            handleDocumentWorkflow(question)
            return
        }

        if currentWorkflow == .webDesign {
            handleWebsiteWorkflow(question)
            return
        }

        let intent = intelligence.detectIntent(from: question)
        print("Northstar Intent:", intent)
        appendUserMessage(question)

        switch intent {
        case .imageGeneration:
            appendAssistantMessage("Image generation is not connected yet.")
        case .videoGeneration:
            appendAssistantMessage("Video generation is not connected yet.")
        case .webDesign:
            currentWorkflow = .webDesign
            webDesignStep = 1
            appendAssistantMessage("""
            Let's build your website.

            What type of website would you like to create?

            • Business
            • Portfolio
            • Ecommerce
            • Landing Page
            • Other
            """)
        case .projectGuidance:
            appendAssistantMessage("""
            Project Guidance

            Tell me about your project.

            Include:

            • What you're building
            • Where you're currently stuck
            • What outcome you're trying to achieve
            """)
        case .documentCreation:
            currentWorkflow = .documentCreation
            documentStep = 1
            appendAssistantMessage("""
            Document Creation

            PDF creation is now available.

            Type PDF to continue.
            """)
        case .imageAnalysis:
            appendAssistantMessage("""
            Image Analysis

            Choose a photo using the Northstar menu.
            Then tell me what you want Northstar to examine.
            """)
        case .conversation:
            requestGeminiResponse()
        }
    }

    private func handleDocumentWorkflow(_ question: String) {
        appendUserMessage(question)

        switch documentStep {
        case 1:
            guard question.lowercased().contains("pdf") else {
                appendAssistantMessage("""
                PDF Creation

                PDF is the first connected document format.

                Type PDF to continue.
                """)
                return
            }

            documentType = "PDF"
            documentStep = 2
            livePDFText = ""
            isLivePDFDraftPresented = true

            appendAssistantMessage("""
            PDF Draft Opened

            Dictate or type your document.

            Tap Save PDF when ready.
            """)

        default:
            resetDocumentWorkflow()
        }
    }

    private func handleWebsiteWorkflow(_ question: String) {
        appendUserMessage(question)

        switch webDesignStep {
        case 1:
            websiteType = question
            webDesignStep = 2
            appendAssistantMessage("Great choice.\n\nWhat is the name of your website?")
        case 2:
            websiteName = question
            webDesignStep = 3
            appendAssistantMessage("What kind of work or services will the website showcase?")
        case 3:
            websiteServices = question
            saveProjectMemory()
            webDesignStep = 4
            appendAssistantMessage("""
            Website Brief Complete

            Name: \(websiteName)
            Type: \(websiteType)
            Services: \(websiteServices)

            What would you like me to create next?

            • Sitemap
            """)
        case 4:
            guard wantsSitemap(question) else {
                appendAssistantMessage("""
                I can help with the website structure.

                Try asking:

                • What pages should I have?
                • Show me the site structure
                • What should the navigation be?
                • Create a sitemap
                """)
                return
            }
            generateSitemap()
        default:
            currentWorkflow = nil
            webDesignStep = 0
        }
    }

    /// Sends the attached photo (made small first) with what they typed, or a simple question.
    private func sendPhoto(_ photo: UIImage) {
        if speechRecognizer.isRecording { speechRecognizer.stopRecording() }
        isPromptFocused = false
        let typed = cleanedPrompt
        let question = typed.isEmpty ? "What do you see in this photo?" : typed
        guard let data = Self.smallJPEG(photo) else {
            appendAssistantMessage("I couldn't read that photo. Please try another one.")
            selectedImage = nil
            return
        }
        // A photo question is always a normal chat (not a document or website flow).
        currentWorkflow = nil
        viewModel.messages.append(MessageModel(role: .user, content: question, image: data))
        promptText = ""
        selectedImage = nil
        requestGeminiResponse()
    }

    /// Longest side at most 1280 points and JPEG, so it uploads fast and costs little.
    private static func smallJPEG(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1280
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func appendUserMessage(_ content: String) {
        viewModel.messages.append(MessageModel(role: .user, content: content))
        promptText = ""
    }

    /// One-tap save from a Northstar save card. Only what the person confirms is stored.
    private func saveSuggestion(_ save: NorthstarInsight.Save) async -> UUID? {
        guard let identityId = memoryIdentityId else { return nil }
        do {
            let id = try await memoryService.saveMemory(
                identityId: identityId,
                projectId: nil,
                content: save.text,
                category: save.kind
            )
            if KeepMemoryNudge.noteKept() { withAnimation { showKeepSafe = true } }
            return id
        } catch {
            print("Save suggestion failed:", error.localizedDescription)
            return nil
        }
    }

    /// Discovery finished: close it without the slide (chat sits on the same sky), then do what they chose:
    /// open a place directly, start a chat on their request (Northstar speaks first), or connect an app.
    private func startFromDiscovery(_ result: DiscoveryResult) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) { isDiscoveryPresented = false }
        switch result {
        case .close:
            return
        case .navigate(let route):
            // A sheet or screen can only open once Discovery has finished closing.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                go(route)
            }
        case .crisis(let words):
            if !viewModel.messages.isEmpty, !isThinking { startNewChat() }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !isThinking else { return }
                appendUserMessage(words)
                requestGeminiResponse()
            }
        case .beginChat(let prompt, _, let opener):
            if !viewModel.messages.isEmpty, !isThinking { startNewChat() }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { appendUserMessage(prompt) }
                appendAssistantMessage(opener)
            }
        case .connect(_, let prompt):
            // No connector is live yet (none are ever offered), so this can't be reached today. When Connections
            // ships, open that connector's flow here, then continue the same request.
            if !viewModel.messages.isEmpty, !isThinking { startNewChat() }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !isThinking else { return }
                appendUserMessage(prompt)
                requestGeminiResponse()
            }
        }
    }

    /// The person picked a direction: say it in their words and continue.
    /// Keeps any half-typed text in the field.
    private func chooseDirection(_ direction: NorthstarInsight.Direction) {
        guard !isThinking else { return }
        viewModel.messages.append(MessageModel(role: .user, content: Self.choicePrefix + direction.name + "\u{201D}."))
        requestGeminiResponse()
    }

    /// "Keep" on a subject offer: saved only because the person confirmed it.
    private func keepSubject(_ offer: NorthstarInsight.SubjectOffer, for messageId: UUID) {
        subjectStates[messageId] = "kept"
        Task {
            do {
                try await subjectsService.keep(title: offer.title, goal: offer.goal, nextStep: offer.nextStep)
                if KeepMemoryNudge.noteKept() { withAnimation { showKeepSafe = true } }
            } catch {
                subjectStates[messageId] = "keepFailed"   // shows "Couldn't keep it" with the buttons again
            }
        }
    }

    /// "Undo" on an automatic subject update: the card goes back the way it was.
    private func undoSubject(_ update: NorthstarInsight.SubjectUpdate, for messageId: UUID) {
        subjectStates[messageId] = "undone"
        Task {
            do {
                let ok = try await subjectsService.undo(update)
                if !ok { subjectStates[messageId] = "changedSince" }
            } catch {
                subjectStates[messageId] = "undoFailed"
            }
        }
    }

    /// "Use this" on a From before card: bring the earlier line into the chat, in plain words.
    private func useFromBefore(_ note: Note) {
        guard !isThinking else { return }
        let day = note.createdAt.formatted(.dateTime.month(.wide).day())
        viewModel.messages.append(MessageModel(role: .user, content: "From before (\(day)): \u{201C}\(note.text)\u{201D}. Let's use this."))
        requestGeminiResponse()
    }

    private static let choicePrefix = "Let's go with \u{201C}"

    /// Which direction was chosen, read from the chat itself (the next message),
    /// so it stays right after scrolling.
    private func chosenDirection(after message: MessageModel) -> String? {
        let all = viewModel.messages
        guard let i = all.firstIndex(where: { $0.id == message.id }), i + 1 < all.count else { return nil }
        let next = all[i + 1]
        guard next.role == .user, next.content.hasPrefix(Self.choicePrefix) else { return nil }
        return String(next.content.dropFirst(Self.choicePrefix.count).dropLast(2))
    }

    /// Undo from the "Saved" line: removes the item that was just saved.
    private func undoSave(_ id: UUID) async -> Bool {
        do {
            try await memoryService.deleteMemory(id: id)
            return true
        } catch {
            print("Undo save failed:", error.localizedDescription)
            return false
        }
    }

    /// Confirmed memories for the brain: newest first, at most 20.
    /// Only what the person saved is sent; nothing is guessed.
    private func memoryForEngine() async -> [NorthstarEngineClient.MemoryItem] {
        guard let identityId = memoryIdentityId else { return [] }
        do {
            let items = try await memoryService.loadMemories(identityId: identityId)
            return items.prefix(20).compactMap { item in
                let text = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                let kind = (item.category ?? "").isEmpty ? "note" : (item.category ?? "note")
                return NorthstarEngineClient.MemoryItem(kind: kind, text: text)
            }
        } catch {
            print("Loading memory for the Engine failed:", error.localizedDescription)
            return []
        }
    }

    private func appendAssistantMessage(_ content: String) {
        viewModel.messages.append(MessageModel(role: .assistant, content: content))
    }

    private func requestGeminiResponse() {
        isThinking = true
        responseTask = Task {
            let settings = EngineSettings.current
            var memory: [NorthstarEngineClient.MemoryItem] = []
            if settings.memoryOn {
                memory = await memoryForEngine()
            }
            let corrections = pendingCorrections
            pendingCorrections = []
            let lastUser = viewModel.messages.last(where: { $0.role == .user })?.content ?? ""

            // Saved chats (memory on only): start one on the first message.
            var createdNow: UUID?
            if settings.memoryOn, currentChatId == nil, !lastUser.isEmpty {
                let id = try? await chatsService.create(firstMessage: lastUser)
                // They may have opened another chat or started a new one meanwhile.
                guard !Task.isCancelled else {
                    if let id { try? await chatsService.delete(id: id) }
                    return
                }
                currentChatId = id
                createdNow = id
            }
            let chatId = settings.memoryOn ? currentChatId : nil

            // "What's on my calendar?": send the next 7 days (asks for Calendar access the first time).
            let calendar = NorthstarCalendar.asksAboutSchedule(lastUser)
                ? await NorthstarCalendar.shared.upcoming() : nil

            let answer = await engine.getReply(
                for: viewModel.messages,
                memory: memory,
                corrections: corrections,
                settings: settings,
                chatId: chatId,
                calendar: calendar
            )
            guard !Task.isCancelled else {
                // Stopped before any reply: don't leave an empty chat in History.
                if let createdNow { try? await chatsService.delete(id: createdNow) }
                return
            }
            await MainActor.run {
                viewModel.messages.append(
                    MessageModel(role: .assistant, content: answer.text, insight: answer.insight)
                )
                isThinking = false
                responseTask = nil
                // Settings → Voice → Read replies aloud. Not in a crisis reply (the help card is read, not spoken).
                if NorthstarVoice.autoSpeak, !answer.failed, answer.insight?.crisis != true {
                    NorthstarVoice.shared.speak(answer.text)
                }
            }
            // Keep this exchange in the saved chat (never blocks the reply).
            if let chatId, !lastUser.isEmpty, !answer.failed {
                try? await chatsService.append(chatId: chatId, user: lastUser, assistant: answer.text)
                if let title = answer.insight?.chatTitle {
                    try? await chatsService.rename(chatId: chatId, to: title)
                }
            }
        }
    }

    private func saveLivePDF() {
        let cleanedText = livePDFText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }

        // A calm name, never the private first line ("Hi mom, …" → "Letter to Mom").
        let title = DocumentNaming.calmName(for: cleanedText)

        do {
            let fileURL = try pdfService.createPDF(title: title, topic: cleanedText)
            generatedPDFURL = fileURL

            appendAssistantMessage("""
            PDF Created

            Title: \(title)

            The PDF was saved in Northstar Documents.
            """)

            livePDFText = ""
            resetDocumentWorkflow()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isPDFSharePresented = true
            }
        } catch {
            appendAssistantMessage("I couldn't create the PDF.\n\nPlease try again.")
            print("Live PDF creation failed:", error.localizedDescription)
        }
    }

    private func resetDocumentWorkflow() {
        currentWorkflow = nil
        documentStep = 0
        documentType = ""
    }

    private func generateSitemap() {
        isThinking = true
        let prompt = """
        Create a professional website sitemap.

        Website name: \(websiteName)
        Website type: \(websiteType)
        Services: \(websiteServices)

        Include main navigation pages, important child pages, clear hierarchy,
        and a short purpose for every page. Keep it concise and practical.
        """

        responseTask = Task {
            let sitemap = await engine.getResponse(
                for: [MessageModel(role: .user, content: prompt)]
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                appendAssistantMessage(sitemap)
                currentWorkflow = nil
                webDesignStep = 0
                isThinking = false
                responseTask = nil
            }
        }
    }

    private func stopResponse() {
        responseTask?.cancel()
        responseTask = nil
        isThinking = false
    }

    private func startNewChat() {
        NorthstarVoice.shared.stop()
        responseTask?.cancel()
        responseTask = nil
        currentWorkflow = nil
        webDesignStep = 0
        documentStep = 0
        documentType = ""
        livePDFText = ""
        isLivePDFDraftPresented = false
        generatedPDFURL = nil
        isPDFSharePresented = false

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }

        isPromptFocused = false
        navigationPath.removeAll()
        promptText = ""
        selectedImage = nil
        websiteType = ""
        websiteName = ""
        websiteServices = ""
        viewModel.messages.removeAll()
        currentChatId = nil
        isThinking = false
        scheduleWelcomeMessageFade()
    }

    private func saveProjectMemory() {
        let project = ProjectMemory(
            websiteType: websiteType,
            websiteName: websiteName,
            websiteServices: websiteServices
        )
        guard let data = try? JSONEncoder().encode(project) else { return }
        UserDefaults.standard.set(data, forKey: projectMemoryKey)
    }

    private func loadProjectMemory() {
        guard
            let data = UserDefaults.standard.data(forKey: projectMemoryKey),
            let project = try? JSONDecoder().decode(ProjectMemory.self, from: data)
        else { return }

        websiteType = project.websiteType
        websiteName = project.websiteName
        websiteServices = project.websiteServices
    }

    /// The user's own message is always short, so bottom-anchoring its arrival
    /// is correct and expected. An assistant reply can be taller than the
    /// visible viewport (an expanded structured-response card) — scrolling
    /// that to its own top shows the beginning first and lets the user scroll
    /// down through the rest normally, rather than bottom-anchoring and
    /// pushing the card's opening content off-screen above the viewport.
    /// Fires once per new message, never re-triggered on a timer, so it never
    /// fights a manual scroll the user makes afterward.
    private func scrollToLatestMessage(_ proxy: ScrollViewProxy) {
        guard let latestMessage = viewModel.messages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                if latestMessage.role == .user {
                    proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                } else {
                    proxy.scrollTo(latestMessage.id, anchor: .top)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
