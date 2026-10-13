import SwiftUI
import UIKit

struct ContentView: View {
    enum Destination: Hashable {
        case projects
        case discovery
        case learning
        case memory
        case documents
        case history
        case settings
        case about
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
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var viewModel = ChatViewModel()
    @State private var isCameraPresented = false
    @State private var isPhotoLibraryPresented = false
    @State private var selectedImage: UIImage?
    @State private var promptText = ""
    @State private var isThinking = false
    /// Pills the person removed since the last message; sent once as corrections.
    @State private var pendingCorrections: [String] = []
    @State private var isStarMenuPresented = false
    @State private var responseTask: Task<Void, Never>?
    @FocusState private var isPromptFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWelcomeMessageVisible = true

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
                    promptArea
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isStarMenuPresented {
                    starMenu
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
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPhotoLibraryPresented) {
            PhotoPickerView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $isLivePDFDraftPresented) {
            LivePDFDraftView(
                documentText: $livePDFText,
                isRecording: speechRecognizer.isRecording,
                onMicrophoneTapped: { toggleMicrophone() },
                onSave: { saveLivePDF() }
            )
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
        }
    }

    /// Empty conversation gets the full lockup + welcome message; an active
    /// conversation gets a small permanent header instead, so the scrolling
    /// area actually has room for tall structured-response cards. Branding
    /// lives here, as a sibling of conversationArea — never inside its
    /// ScrollView content.
    @ViewBuilder
    private var adaptiveHeader: some View {
        if viewModel.messages.isEmpty {
            heroHeader
        } else {
            compactHeader
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 6) {
            NorthstarVisionStarMark(size: 16)
                .accessibilityHidden(true)

            Text("Northstar")
                .font(.system(size: 14, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityAddTraits(.isHeader)
        }
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
                NorthstarVisionStarMark(size: 48)
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
            guard viewModel.messages.isEmpty else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.6)) {
                isWelcomeMessageVisible = false
            }
        }
    }

    /// Dark navy veil over the landscape while chatting. Home stays clear.
    private var chatVeil: some View {
        ZStack {
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
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(viewModel.messages.isEmpty ? 0 : 1)
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.6), value: viewModel.messages.isEmpty)
        .accessibilityHidden(true)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.messages) { message in
                        if message.role == .user {
                            UserMessageView(text: message.content)
                        } else {
                            NorthstarReplyView(
                                text: message.content,
                                insight: message.insight,
                                onSave: saveSuggestion,
                                onUndo: undoSave,
                                onRemovePill: { pendingCorrections.append($0) }
                            )
                        }
                    }

                    // Sized to the composer's real measured footprint (+16pt
                    // breathing room) rather than a fixed 1pt marker — this is
                    // what actually guarantees the last message clears the
                    // composer when scrolled to bottom, regardless of whether
                    // .safeAreaInset is correctly shrinking this ScrollView's
                    // own viewport in this hierarchy.
                    Color.clear
                        .frame(height: composerHeight + 16)
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
        }
    }

    private var promptArea: some View {
        HStack(spacing: 10) {
            Button {
                isPromptFocused = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    isStarMenuPresented = true
                }
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            TextField("Ask Northstar...", text: $promptText, axis: .vertical)
                .focused($isPromptFocused)
                .foregroundStyle(.white)
                .lineLimit(1...6)
                .disabled(isThinking)
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            Button { toggleMicrophone() } label: {
                Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(speechRecognizer.isRecording ? .red : .white)
                    .frame(width: 34, height: 34)
            }

            Button {
                isThinking ? stopResponse() : sendMessage()
            } label: {
                Image(systemName: isThinking ? "stop.fill" : "arrow.up")
                    .font(.system(size: isThinking ? 12 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(.white.opacity(0.20)) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background {
            // Frosted glass: the scene blurs through, with a soft white tint.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.white.opacity(0.10)
            }
            .environment(\.colorScheme, .dark)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.45, green: 0.55, blue: 1.0).opacity(0.18), radius: 16)
        .padding(.horizontal, 6)
        .padding(.bottom, isPromptFocused ? 8 : 46)
        .animation(.easeOut(duration: 0.2), value: isPromptFocused)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { newHeight in
            composerHeight = newHeight
        }
    }

    private var starMenu: some View {
        StarMenuView(
            isPresented: $isStarMenuPresented,
            onNewChat: {
                startNewChat()
            },
            onCamera: {
                isCameraPresented = true
            },
            onPhotoLibrary: {
                isPhotoLibraryPresented = true
            },
            onProjects: {
                open(.projects)
            },
            onDiscovery: {
                open(.discovery)
            },
            onLearning: {
                open(.learning)
            },
            onMemory: {
                open(.memory)
            },
            onDocuments: {
                open(.documents)
            },
            onHistory: {
                open(.history)
            },
            onSettings: {
                open(.settings)
            },
            onAbout: {
                open(.about)
            }
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
            placeholderScreen(title: "Projects", symbol: "folder")
        case .discovery:
            placeholderScreen(title: "Discovery", symbol: "safari")
        case .learning:
            placeholderScreen(
                title: "Learning",
                symbol: "book"
            )
        case .memory:
            MemorySearchView()

        case .documents:
            DocumentsView()
        case .history:
            placeholderScreen(title: "History", symbol: "clock.arrow.circlepath")
        case .settings:
            NorthstarSettingsView()
        case .about:
            placeholderScreen(title: "About Northstar", symbol: "sparkle")
        }
    }

    private func placeholderScreen(title: String, symbol: String) -> some View {
        ZStack {
            Color(red: 0.08, green: 0.12, blue: 0.25).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .ultraLight))
                Text(title).font(.system(size: 28, weight: .light))
                Text("This Northstar area is ready to be designed.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open(_ destination: Destination) {
        isPromptFocused = false
        navigationPath.append(destination)
    }

    private func toggleMicrophone() {
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

    private func appendUserMessage(_ content: String) {
        viewModel.messages.append(MessageModel(role: .user, content: content))
        promptText = ""
    }

    /// One-tap save from a Northstar save card. Only what the person confirms is stored.
    private func saveSuggestion(_ save: NorthstarInsight.Save) async -> UUID? {
        guard let identityId = memoryIdentityId else { return nil }
        do {
            return try await memoryService.saveMemory(
                identityId: identityId,
                projectId: nil,
                content: save.text,
                category: save.kind
            )
        } catch {
            print("Save suggestion failed:", error.localizedDescription)
            return nil
        }
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
            let answer = await engine.getReply(
                for: viewModel.messages,
                memory: memory,
                corrections: corrections,
                settings: settings
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.messages.append(
                    MessageModel(role: .assistant, content: answer.text, insight: answer.insight)
                )
                isThinking = false
                responseTask = nil
            }
        }
    }

    private func saveLivePDF() {
        let cleanedText = livePDFText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }

        let firstLine = cleanedText
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = (firstLine?.isEmpty == false) ? firstLine! : "Northstar Document"

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
