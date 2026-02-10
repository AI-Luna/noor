//
//  VisionView.swift
//  leap
//
//  Vision + action: Pinterest boards, places to travel, and links that close the gap
//  (see the world, travel solo, 6-figure, financial freedom — then act on it).
//

import SwiftUI
import MapKit

struct VisionView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var items: [VisionItem] = []
    @State private var goals: [Goal] = []
    @State private var showAddSheet = false
    @State private var organizationMode: VisionOrganizationMode = .byType

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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            sectionHeader

                            Picker("Organize", selection: $organizationMode) {
                                ForEach(VisionOrganizationMode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 4)

                            ForEach(groupedItems, id: \.0) { groupName, groupItems in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(groupName)
                                        .font(NoorFont.callout)
                                        .foregroundStyle(Color.noorRoseGold)
                                        .padding(.horizontal, 4)

                                    ForEach(groupItems) { item in
                                        VisionItemCard(
                                            item: item,
                                            linkedGoalTitle: goals.first { $0.id.uuidString == item.goalID }.map { $0.destination.isEmpty ? $0.title : $0.destination },
                                            onOpen: { openItem(item) },
                                            onMap: item.kind == .destination ? { openInMaps(item) } : nil,
                                            onMarkDone: { toggleDone(item) },
                                            onDelete: { deleteItem(item) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 100)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Vision")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
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
                    .presentationDetents([.large, .fraction(0.92)])
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

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inspiration & action")
                .font(NoorFont.title2)
                .foregroundStyle(.white)
            Text("See it. Then act on it.")
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.noorRoseGold, Color.noorOrange.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 14) {
                Text("This is where your path takes shape")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Vision is the heart of Noor. Add inspiration—Pinterest, Instagram, places you want to go—and actions that close the gap. Then come back here to act on it.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Add to your vision")
                        .font(NoorFont.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.noorViolet.opacity(0.8), Color.noorAccent.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                        .stroke(Color.noorRoseGold.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 12)
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

// MARK: - Card for one vision item (with accountability: mark done, link to journey)
private struct VisionItemCard: View {
    let item: VisionItem
    let linkedGoalTitle: String?
    let onOpen: () -> Void
    let onMap: (() -> Void)?
    let onMarkDone: () -> Void
    let onDelete: () -> Void

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

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.8))
                }
                .buttonStyle(.plain)
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero: frame this as the main action
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.noorRoseGold)
                                Text("Add to your vision")
                                    .font(NoorFont.largeTitle)
                                    .foregroundStyle(.white)
                            }
                            Text("Inspiration, destinations, and actions that light your path.")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 28)

                        // Section: What are you adding?
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What are you adding?")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)

                            Picker("Type", selection: $kind) {
                                ForEach(VisionItemKind.allCases, id: \.self) { k in
                                    Text(k.displayName).tag(k)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.bottom, 24)

                        if !goals.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Link to journey (optional)")
                                    .font(NoorFont.caption)
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
                            .padding(.bottom, 24)
                        }

                        Text("Details")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                            .padding(.bottom, 12)

                        if kind == .pinterest {
                            Text("Pinterest board or profile URL")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            TextField("https://pin.it/... or pinterest.com/...", text: $url)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            TextField("Name (optional)", text: $title)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Paste a Pinterest link (board, profile, or pin.it). We'll open it when you tap Open.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        if kind == .instagram {
                            Text("Instagram post or profile URL")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            TextField("https://instagram.com/p/... or /username", text: $url)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            TextField("Name (optional) — e.g. @handle or post description", text: $title)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Paste a post link (Share → Copy link) or an influencer's profile. Tap Open to revisit for inspiration.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        if kind == .destination {
                            Text("Place you want to go")
                                .font(NoorFont.caption)
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

                            Text("Tap \"Flights\" to search flights to this place.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        if kind == .action {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose an idea (optional)")
                                    .font(NoorFont.caption)
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

                            Text("What action or link?")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                            TextField("e.g. Update LinkedIn, Message Sarah", text: $title)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            TextField("URL (LinkedIn, shop, etc.)", text: $url)
                                .textFieldStyle(.plain)
                                .font(NoorFont.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            Text("Save a link that moves you forward. We'll open it when you tap Open.")
                                .font(NoorFont.caption)
                                .foregroundStyle(Color.noorTextSecondary)
                        }

                        // Primary CTA: Save feels like the main action
                        Button(action: save) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                Text("Save to vision")
                                    .font(NoorFont.button)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                canSave
                                    ? LinearGradient(
                                        colors: [Color.noorViolet.opacity(0.9), Color.noorAccent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                            .overlay(
                                RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge)
                                    .stroke(canSave ? Color.noorRoseGold.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .disabled(!canSave)
                        .buttonStyle(.plain)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(Color.noorTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(canSave ? Color.noorRoseGold : Color.noorTextSecondary.opacity(0.5))
                        .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    VisionView()
}
