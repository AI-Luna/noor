//
//  VisionView.swift
//  leap
//
//  Vision + action: Pinterest boards, places to travel, and links that close the gap
//  (see the world, travel solo, 6-figure, financial freedom — then act on it).
//

import SwiftUI
import MapKit
import UIKit

struct VisionView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var items: [VisionItem] = []
    @State private var goals: [Goal] = []
    @State private var showAddSheet = false
    @State private var organizationMode: VisionOrganizationMode = .byType
    @State private var itemForActions: VisionItem?  // tap cell → show Open/Delete
    @State private var selectedScienceLesson: VisionScienceLesson?
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum VisionOrganizationMode: String, CaseIterable {
        case byType = "By type"
        case byJourney = "By journey"
    }

    private var groupedItems: [(String, [VisionItem])] {
        switch organizationMode {
        case .byType:
            let pinterest = items.filter { $0.kind == .pinterest }
            let instagram = items.filter { $0.kind == .instagram }
            let dest = items.filter { $0.kind == .destination }
            let action = items.filter { $0.kind == .action }
            var result: [(String, [VisionItem])] = []
            if !pinterest.isEmpty { result.append(("Pinterest", pinterest)) }
            if !instagram.isEmpty { result.append(("Instagram", instagram)) }
            if !dest.isEmpty { result.append(("Destinations", dest)) }
            if !action.isEmpty { result.append(("Actions", action)) }
            return result
        case .byJourney:
            var result: [(String, [VisionItem])] = []
            for goal in goals {
                let linked = items.filter { $0.goalID == goal.id.uuidString }
                if !linked.isEmpty {
                    result.append((goal.destination.isEmpty ? goal.title : goal.destination, linked))
                }
            }
            let unlinked = items.filter { $0.goalID == nil || $0.goalID?.isEmpty == true }
            if !unlinked.isEmpty { result.append(("Not linked to a journey", unlinked)) }
            return result
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        Picker("Organize", selection: $organizationMode) {
                            ForEach(VisionOrganizationMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(Color.noorTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .onAppear {
                            // Selected segment: subtext color (light purple) with dark text for readability
                            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 233/255, green: 213/255, blue: 255/255, alpha: 1) // noorTextSecondary
                            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(red: 15/255, green: 10/255, blue: 30/255, alpha: 1)], for: .selected) // noorBackground
                        }

                        List {
                            ForEach(groupedItems, id: \.0) { groupName, groupItems in
                                Section {
                                    ForEach(groupItems) { item in
                                        VisionItemCard(
                                            item: item,
                                            linkedGoalTitle: goals.first { $0.id.uuidString == item.goalID }.map { $0.destination.isEmpty ? $0.title : $0.destination },
                                            onOpen: { openItem(item) },
                                            onMap: item.kind == .destination ? { openInMaps(item) } : nil,
                                            onMarkDone: { toggleDone(item) },
                                            onDelete: { deleteItem(item) },
                                            onTap: { itemForActions = item }
                                        )
                                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            Button("Open") {
                                                openItem(item)
                                            }
                                            .tint(Color.noorRoseGold)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button("Delete", role: .destructive) {
                                                deleteItem(item)
                                            }
                                        }
                                    }
                                } header: {
                                    Text(groupName)
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorRoseGold)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Vision")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text("See it, then act on it")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(Color.noorTextSecondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedScienceLesson = VisionScienceLesson.dailyLesson
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!isLoading && errorMessage == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $selectedScienceLesson) { lesson in
                VisionScienceLessonSheet(lesson: lesson, onDismiss: { selectedScienceLesson = nil })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .confirmationDialog("Vision item", isPresented: Binding(
                get: { itemForActions != nil },
                set: { if !$0 { itemForActions = nil } }
            )) {
                if let item = itemForActions {
                    Button("Open") {
                        openItem(item)
                        itemForActions = nil
                    }
                    Button("Delete", role: .destructive) {
                        deleteItem(item)
                        itemForActions = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    itemForActions = nil
                }
            } message: {
                Text("Open or delete this item?")
            }
            .onAppear {
                loadItems()
            }
            .onAppear {
                loadGoals()
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                loadItems()
                loadGoals()
            }) {
                AddVisionItemSheet(goals: goals, onDismiss: { showAddSheet = false }, onSaved: { showAddSheet = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func loadGoals() {
        Task { @MainActor in
            do {
                goals = try await dataManager.fetchAllGoals()
            } catch {
                goals = []
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                Text("You don't need permission")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Add the life you want — travel, career moves, financial goals, and more.\nNoor helps you take the steps to get there.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Button {
                showAddSheet = true
            } label: {
                Text("Create your vision")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.noorRoseGold, Color.noorOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .shadow(color: Color.noorRoseGold.opacity(0.5), radius: 16, x: 0, y: 0)
                    .shadow(color: Color.noorOrange.opacity(0.3), radius: 24, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
           let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) {
            items = decoded
            return
        }
        // Migrate from old vision boards
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionBoards),
           let legacy = try? JSONDecoder().decode([VisionBoardItem].self, from: data) {
            items = legacy.map { VisionItem(kind: .pinterest, title: $0.title, url: $0.url) }
            persistItems()
            UserDefaults.standard.removeObject(forKey: StorageKey.visionBoards)
        } else {
            items = []
        }
    }

    private func toggleDone(_ item: VisionItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].completedAt = item.completedAt == nil ? Date() : nil
        persistItems()
    }

    private func deleteItem(_ item: VisionItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: StorageKey.visionItems)
        }
    }

    private func openItem(_ item: VisionItem) {
        switch item.kind {
        case .pinterest, .instagram, .action:
            if let urlString = item.url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case .destination:
            let name = item.placeName ?? item.title
            let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            if let url = URL(string: "https://www.google.com/search?q=flights+to+\(query)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openInMaps(_ item: VisionItem) {
        let name = item.placeName ?? item.title
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        MKLocalSearch(request: request).start { response, _ in
            guard let mapItem = response?.mapItems.first else {
                if let url = URL(string: "https://maps.apple.com/?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                    UIApplication.shared.open(url)
                }
                return
            }
            mapItem.openInMaps()
        }
    }
}

// MARK: - Card for one vision item (mark done, open; delete via swipe or tap)
private struct VisionItemCard: View {
    let item: VisionItem
    let linkedGoalTitle: String?
    let onOpen: () -> Void
    let onMap: (() -> Void)?
    let onMarkDone: () -> Void
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: item.kind.icon)
                .font(.system(size: 22))
                .foregroundStyle(item.isCompleted ? Color.noorTextSecondary.opacity(0.7) : Color.noorRoseGold)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
                    .strikethrough(item.isCompleted, color: Color.noorTextSecondary)
                    .lineLimit(1)

                if let journey = linkedGoalTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 10))
                        Text(journey)
                            .font(NoorFont.caption)
                    }
                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                    .lineLimit(1)
                } else if item.kind == .destination, let place = item.placeName ?? item.url {
                    Text(place)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(1)
                } else if let url = item.url {
                    Text(url)
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onMarkDone) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isCompleted ? Color.noorSuccess : Color.noorTextSecondary)
                }
                .buttonStyle(.plain)

                if item.kind == .destination {
                    Button(action: onOpen) {
                        Text("Flights")
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .buttonStyle(.plain)
                    if onMap != nil {
                        Button(action: { onMap?() }) {
                            Text("Map")
                                .font(NoorFont.callout)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: onOpen) {
                        Text("Open")
                            .font(NoorFont.callout)
                            .foregroundStyle(Color.noorRoseGold)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(item.isCompleted ? Color.white.opacity(0.04) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Add sheet: choose type, link to journey, action dropdown for ideas
private struct AddVisionItemSheet: View {
    let goals: [Goal]

    @State private var kind: VisionItemKind = .pinterest
    @State private var title = ""
    @State private var url = ""
    @State private var placeName = ""
    @State private var selectedGoalID: String?
    @State private var actionSuggestion: VisionActionSuggestion = .other
    @State private var showDetailsSheet = false

    let onDismiss: () -> Void
    let onSaved: () -> Void

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .pinterest:
            let u = url.trimmingCharacters(in: .whitespaces)
            return !u.isEmpty && (u.lowercased().contains("pinterest") || u.lowercased().contains("pin.it"))
        case .instagram:
            let u = url.trimmingCharacters(in: .whitespaces)
            return !u.isEmpty && (u.lowercased().contains("instagram.com") || u.lowercased().contains("instagr.am"))
        case .destination:
            let p = placeName.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty || !p.isEmpty
        case .action:
            let u = url.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty || !u.isEmpty
        }
    }

    private func save() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let t = title.trimmingCharacters(in: .whitespaces)
        let u = url.trimmingCharacters(in: .whitespaces)
        let p = placeName.trimmingCharacters(in: .whitespaces)

        switch kind {
        case .pinterest:
            let item = VisionItem(
                kind: .pinterest,
                title: t.isEmpty ? (URL(string: u)?.host ?? "Pinterest") : t,
                url: u,
                goalID: selectedGoalID
            )
            saveItem(item)
        case .instagram:
            let item = VisionItem(
                kind: .instagram,
                title: t.isEmpty ? "Instagram post or profile" : t,
                url: u,
                goalID: selectedGoalID
            )
            saveItem(item)
        case .destination:
            let name = !p.isEmpty ? p : (!t.isEmpty ? t : "Destination")
            let item = VisionItem(kind: .destination, title: name, url: nil, placeName: name, goalID: selectedGoalID)
            saveItem(item)
        case .action:
            let item = VisionItem(kind: .action, title: t.isEmpty ? "Action" : t, url: u.isEmpty ? nil : u, goalID: selectedGoalID)
            saveItem(item)
        }
        onSaved()
    }

    private func saveItem(_ item: VisionItem) {
        var list: [VisionItem] = []
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
           let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) {
            list = decoded
        }
        list.insert(item, at: 0)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: StorageKey.visionItems)
        }
    }

    @State private var currentStep: Int = 0

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — back button only on step 1
                if currentStep == 1 {
                    HStack(alignment: .center) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentStep = 0
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .buttonStyle(.plain)

                        Text(kind.displayName)
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                }

                // Step content with slide animation
                ZStack {
                    // Step 0: Choose type
                    if currentStep == 0 {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header + subtext together
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Make your vision real.")
                                    .font(NoorFont.largeTitle)
                                    .foregroundStyle(.white)

                                Text("Your vision only works when you act on it. Save what inspires you — Noor turns it into your next move.")
                                    .font(NoorFont.bodyLarge)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            .padding(.bottom, 32)

                            // Section: What type
                            VStack(alignment: .leading, spacing: 10) {
                                Text("What are you adding?")
                                    .font(NoorFont.title)
                                    .foregroundStyle(.white)

                                Text("A board, post, destination, or action step.")
                                    .font(NoorFont.bodyLarge)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            .padding(.bottom, 24)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(VisionItemKind.allCases, id: \.self) { k in
                                    VisionKindCell(kind: k, isSelected: kind == k) {
                                        kind = k
                                        title = ""
                                        url = ""
                                        placeName = ""
                                        actionSuggestion = .other
                                    }
                                }
                            }

                            Spacer()

                            // Next arrow — bottom right, thumb-friendly
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        currentStep = 1
                                    }
                                } label: {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 52))
                                        .foregroundStyle(Color.noorRoseGold)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 32)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                    }

                    // Step 1: Details
                    if currentStep == 1 {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if kind == .pinterest {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Board or pin link")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("pinterest.com/... or pin.it/...", text: $url)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .autocapitalization(.none)
                                            .keyboardType(.URL)

                                        TextField("Label (optional)", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("We'll open this board when you tap it from your vision.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .instagram {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Post or profile link")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("instagram.com/p/... or @handle", text: $url)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .autocapitalization(.none)
                                            .keyboardType(.URL)

                                        TextField("Label (optional)", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("We'll open this post when you tap it from your vision.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .destination {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("City or country")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("e.g. Iceland, Tokyo, Bali", text: $placeName)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        TextField("Label (optional)", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("We'll help you search flights when you're ready to book.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .action {
                                    VStack(alignment: .leading, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Common actions (optional)")
                                                .font(NoorFont.bodyLarge)
                                                .foregroundStyle(Color.noorTextSecondary)
                                            Picker("Idea", selection: $actionSuggestion) {
                                                ForEach(VisionActionSuggestion.allCases, id: \.self) { s in
                                                    Text(s.rawValue).tag(s)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .tint(.white)
                                            .onChange(of: actionSuggestion) { _, new in
                                                if new != .other {
                                                    title = new.rawValue
                                                    if let u = new.urlPlaceholder { url = u }
                                                }
                                            }
                                        }

                                        Text("Name your next step")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("e.g. Update LinkedIn, DM Sarah", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("Link to open (booking page, profile, purchase)")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("https://...", text: $url)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .autocapitalization(.none)
                                            .keyboardType(.URL)

                                        Text("We'll open this link when you tap it from your vision.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                // Link to journey (if goals exist)
                                if !goals.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Link to journey (optional)")
                                            .font(NoorFont.title)
                                            .foregroundStyle(.white)
                                        Text("Connect this to one of your visions or goals.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        Picker("Journey", selection: $selectedGoalID) {
                                            Text("None").tag(nil as String?)
                                            ForEach(goals, id: \.id) { g in
                                                Text(g.destination.isEmpty ? g.title : g.destination).lineLimit(1)
                                                    .tag(g.id.uuidString as String?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.white)
                                    }
                                    .padding(.top, 8)
                                }

                                // Save button
                                Button(action: save) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Save to vision")
                                            .font(NoorFont.button)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        canSave
                                            ? Color.noorRoseGold
                                            : Color.white.opacity(0.15)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                                }
                                .disabled(!canSave)
                                .buttonStyle(.plain)
                                .padding(.top, 24)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 48)
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

// MARK: - Vision type cell (icon + label, selected state) — fixed size so all cells match
private struct VisionKindCell: View {
    let kind: VisionItemKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? Color.noorRoseGold : Color.noorTextSecondary)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.noorRoseGold.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(kind.displayName)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(isSelected ? Color.noorRoseGold : Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.noorRoseGold.opacity(0.15) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.noorRoseGold : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vision Science Lessons
struct VisionScienceLesson: Identifiable {
    let id: UUID
    let tag: String
    let title: String
    let snippet: String
    let fullText: String

    init(id: UUID = UUID(), tag: String, title: String, snippet: String, fullText: String) {
        self.id = id
        self.tag = tag
        self.title = title
        self.snippet = snippet
        self.fullText = fullText
    }

    static let allLessons: [VisionScienceLesson] = [
        VisionScienceLesson(
            tag: "Science",
            title: "The power of visualization",
            snippet: "Research shows that mental imagery activates the same brain regions as actual experience. Visualizing your goals primes your brain to recognize opportunities.",
            fullText: "Research in neuroscience shows that mental imagery activates the same brain regions as actual experience. When you visualize your goals, you're essentially rehearsing success in your mind.\n\nVisualization primes your brain's reticular activating system (RAS) to recognize opportunities and resources that align with your vision. It's why you suddenly notice things related to your goals everywhere once you've clearly defined them.\n\nElite athletes use visualization to improve performance. Studies show that mental practice can be nearly as effective as physical practice for skill development."
        ),
        VisionScienceLesson(
            tag: "Science",
            title: "Vision boards and goal achievement",
            snippet: "Having a visual representation of your goals increases the likelihood of achieving them by keeping them top of mind and emotionally connected.",
            fullText: "Having a visual representation of your goals—whether it's Pinterest boards, photos, or places you want to visit—increases the likelihood of achieving them.\n\nVisual cues keep your goals top of mind and create emotional connections. When you see images of your desired future regularly, you're more likely to make decisions that align with those goals.\n\nThe key is accessibility: the more often you see your vision, the more it influences your daily choices and actions. That's why Noor brings your vision into your daily routine."
        ),
        VisionScienceLesson(
            tag: "Science",
            title: "Closing the gap between vision and action",
            snippet: "The most powerful visions include specific actions. Research shows that combining visualization with implementation plans dramatically increases success rates.",
            fullText: "The most powerful visions include specific actions. Research shows that combining visualization with implementation plans dramatically increases success rates.\n\nIt's not enough to see where you want to go—you need to identify the actions that will get you there. This is why Noor encourages you to add both inspiration (Pinterest, places, Instagram) and actions (specific steps you can take).\n\nWhen you regularly review your vision AND the actions that close the gap, you create a clear path forward. Your brain can then focus on execution rather than figuring out what to do next."
        )
    ]

    static var dailyLesson: VisionScienceLesson {
        allLessons.first!
    }
}

struct VisionScienceLessonCard: View {
    let lesson: VisionScienceLesson
    let onTap: () -> Void
    var showTag: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                if showTag {
                    HStack {
                        Text(lesson.tag)
                            .font(NoorFont.caption)
                            .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }

                Text(lesson.title)
                    .font(NoorFont.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(lesson.snippet)
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary.opacity(0.95))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct VisionScienceLessonSheetContent: View {
    let lesson: VisionScienceLesson
    let allLessons: [VisionScienceLesson]
    let onSelectLesson: (VisionScienceLesson) -> Void
    let onDismiss: () -> Void

    private var otherLessons: [VisionScienceLesson] {
        allLessons.filter { $0.id != lesson.id }
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 24)

                // Header
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.noorRoseGold)
                        Text("Science of visualization")
                            .font(NoorFont.title)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Current lesson
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(lesson.tag)
                                    .font(NoorFont.caption)
                                    .foregroundStyle(Color.noorRoseGold.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                Spacer()
                            }

                            Text(lesson.title)
                                .font(NoorFont.largeTitle)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            Text(lesson.fullText)
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(6)
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                        // Other lessons
                        if !otherLessons.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("More on visualization")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)

                                ForEach(otherLessons) { otherLesson in
                                    VisionScienceLessonCard(lesson: otherLesson) {
                                        onSelectLesson(otherLesson)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct VisionScienceLessonSheet: View {
    let initialLesson: VisionScienceLesson
    let onDismiss: () -> Void
    
    @State private var currentLesson: VisionScienceLesson
    
    init(lesson: VisionScienceLesson, onDismiss: @escaping () -> Void) {
        self.initialLesson = lesson
        self.onDismiss = onDismiss
        _currentLesson = State(initialValue: lesson)
    }

    var body: some View {
        VisionScienceLessonSheetContent(
            lesson: currentLesson,
            allLessons: VisionScienceLesson.allLessons,
            onSelectLesson: { selectedLesson in
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentLesson = selectedLesson
                }
            },
            onDismiss: onDismiss
        )
    }
}

#Preview {
    VisionView()
}
