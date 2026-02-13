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

// MARK: - Vision filter (like Habits: filter menu beside plus)
enum VisionFilter: String, CaseIterable {
    case all = "All"
    case pinterest = "Pinterest"
    case instagram = "Instagram"
    case destination = "Places to Go"
    case action = "Action Steps"
    case journey = "Linked to Journey"
    case completed = "Completed"
    case toActOn = "To act on"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .pinterest: return "photo.on.rectangle.angled"
        case .instagram: return "camera.fill"
        case .destination: return "globe.americas.fill"
        case .action: return "bolt.fill"
        case .journey: return "airplane"
        case .completed: return "checkmark.circle.fill"
        case .toActOn: return "star.fill"
        }
    }
}

struct VisionView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var items: [VisionItem] = []
    @State private var goals: [Goal] = []
    @State private var showAddSheet = false
    @State private var selectedFilter: VisionFilter = .all
    @State private var itemForActions: VisionItem?
    @State private var itemToEdit: VisionItem?
    @State private var selectedScienceLesson: VisionScienceLesson?
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Filtered vision items based on selected filter
    private var filteredItems: [VisionItem] {
        switch selectedFilter {
        case .all:
            return items
        case .pinterest:
            return items.filter { $0.kind == .pinterest }
        case .instagram:
            return items.filter { $0.kind == .instagram }
        case .destination:
            return items.filter { $0.kind == .destination }
        case .action:
            return items.filter { $0.kind == .action }
        case .journey:
            return items.filter { $0.goalID != nil && !($0.goalID?.isEmpty ?? true) }
        case .completed:
            return items.filter { $0.isCompleted }
        case .toActOn:
            return items.filter { !$0.isCompleted }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else if filteredItems.isEmpty {
                    emptyStateFiltered
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            visionMetricsSection
                            visionList
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
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
                        Text("Build the life, then live it")
                            .font(.system(size: 10, weight: .regular, design: .serif))
                            .foregroundStyle(Color.noorTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedScienceLesson = VisionScienceLesson.dailyLesson
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.noorOrange)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!isLoading && errorMessage == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(VisionFilter.allCases, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Label(filter.rawValue, systemImage: filter.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: selectedFilter.icon)
                                    .font(.system(size: 16))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                        }
                        .allowsHitTesting(!isLoading && errorMessage == nil)
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
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
                    Button("Edit") {
                        itemToEdit = item
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
                Text("Open, edit, or delete this vision item?")
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
            .sheet(item: $itemToEdit) { item in
                EditVisionItemSheet(
                    item: item,
                    goals: goals,
                    onDismiss: { itemToEdit = nil },
                    onSaved: {
                        loadItems()
                        loadGoals()
                        itemToEdit = nil
                    }
                )
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
                Text("Picture your future")
                    .font(NoorFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Save what inspires you — boards, posts, places, actions.\nNoor turns your vision into daily steps.")
                    .font(NoorFont.body)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Button {
                showAddSheet = true
            } label: {
                Text("Add to your vision")
                    .font(NoorFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.noorOrange, Color.noorOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: NoorLayout.cornerRadiusLarge))
                    .shadow(color: Color.noorOrange.opacity(0.5), radius: 16, x: 0, y: 0)
                    .shadow(color: Color.noorOrange.opacity(0.3), radius: 24, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateFiltered: some View {
        VStack(spacing: 24) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.noorOrange.opacity(0.8))
            VStack(spacing: 8) {
                Text(emptyStateFilterMessage)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateFilterMessage: String {
        switch selectedFilter {
        case .all:
            return "Add inspiration to your vision."
        case .pinterest:
            return "No Pinterest boards yet. Add one to fuel your vision."
        case .instagram:
            return "No Instagram posts saved. Add inspiration from the feed."
        case .destination:
            return "No places to go yet. Add destinations you're striving for."
        case .action:
            return "No action steps yet. Add the next move you'll take."
        case .journey:
            return "No items linked to a journey. Link items when adding or editing."
        case .completed:
            return "Completed items show here. Mark items done from the list."
        case .toActOn:
            return "Items you haven't acted on yet. Your priority list."
        }
    }

    // MARK: - Vision Metrics (Redesigned for clarity)
    private var visionMetricsSection: some View {
        let total = items.count
        let completed = items.filter { $0.isCompleted }.count
        let toActOn = items.filter { !$0.isCompleted }.count
        let byKind = Dictionary(grouping: items, by: { $0.kind })
        
        return VStack(spacing: 16) {
            // Top row: Main progress + action needed
            HStack(spacing: 12) {
                // Overall progress - large and prominent
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 70, height: 70)
                        Circle()
                            .trim(from: 0, to: total > 0 ? CGFloat(completed) / CGFloat(total) : 0)
                            .stroke(
                                LinearGradient(colors: [Color.noorSuccess, Color.noorSuccess.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(completed)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("done")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.noorTextSecondary)
                        }
                    }
                    Text("Completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.noorSuccess)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.noorSuccess.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.noorSuccess.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // To act on - action-oriented
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.noorOrange.opacity(0.15))
                            .frame(width: 70, height: 70)
                        VStack(spacing: 0) {
                            Text("\(toActOn)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.noorOrange)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.noorOrange.opacity(0.7))
                        }
                    }
                    Text("To Act On")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.noorOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.noorOrange.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.noorOrange.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            
            // Bottom row: Category breakdown with distinct colors
            HStack(spacing: 10) {
                ForEach(VisionItemKind.allCases, id: \.self) { kind in
                    let count = byKind[kind]?.count ?? 0
                    let color = colorForKind(kind)
                    
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: kind.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(color)
                        }
                        Text("\(count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(shortNameForKind(kind))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(color.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }
    
    // Distinct colors for each vision type
    private func colorForKind(_ kind: VisionItemKind) -> Color {
        switch kind {
        case .pinterest: return Color(hex: "E60023") // Pinterest red
        case .instagram: return Color(hex: "C13584") // Instagram purple-pink
        case .destination: return Color(hex: "4ECDC4") // Teal for travel
        case .action: return Color(hex: "FFD93D") // Yellow for action
        }
    }
    
    // Short names for compact display
    private func shortNameForKind(_ kind: VisionItemKind) -> String {
        switch kind {
        case .pinterest: return "Boards"
        case .instagram: return "Posts"
        case .destination: return "Places"
        case .action: return "Actions"
        }
    }

    private var visionList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(filteredItems, id: \.id) { item in
                SwipeActionCard(
                    onEdit: {
                        itemToEdit = item
                    },
                    onDelete: { deleteItem(item) },
                    editIcon: "pencil",
                    editLabel: "Edit",
                    editColor: Color.noorOrange
                ) {
                    VisionItemCard(
                        item: item,
                        linkedGoalTitle: goals.first { $0.id.uuidString == item.goalID }.map { $0.destination.isEmpty ? $0.title : $0.destination },
                        onOpen: { openItem(item) },
                        onMap: item.kind == .destination ? { openInMaps(item) } : nil,
                        onMarkDone: { toggleDone(item) },
                        onDelete: { deleteItem(item) },
                        onTap: { itemForActions = item }
                    )
                }
                .padding(.horizontal, 20)
            }
        }
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
    
    // Distinct colors for each vision type
    private var kindColor: Color {
        switch item.kind {
        case .pinterest: return Color(hex: "E60023") // Pinterest red
        case .instagram: return Color(hex: "C13584") // Instagram purple-pink
        case .destination: return Color(hex: "4ECDC4") // Teal for travel
        case .action: return Color(hex: "FFD93D") // Yellow for action
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkmark to the left of the vision
            Button(action: onMarkDone) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? Color.noorSuccess : Color.noorTextSecondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Icon with distinct color per type
            Image(systemName: item.kind.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(item.isCompleted ? Color.noorTextSecondary.opacity(0.5) : kindColor)
                .frame(width: 42, height: 42)
                .background(item.isCompleted ? Color.white.opacity(0.05) : kindColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(NoorFont.body)
                    .foregroundStyle(item.isCompleted ? Color.noorTextSecondary : .white)
                    .strikethrough(item.isCompleted, color: Color.noorTextSecondary)
                    .lineLimit(1)

                if let journey = linkedGoalTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 10))
                        Text(journey)
                            .font(NoorFont.caption)
                    }
                    .foregroundStyle(Color.noorAccent.opacity(0.9))
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

            Spacer(minLength: 4)

            // Action buttons with icons - styled with kind color
            HStack(spacing: 10) {
                if item.kind == .destination {
                    Button(action: onOpen) {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Flights")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(kindColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(kindColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    if onMap != nil {
                        Button(action: { onMap?() }) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.noorTextSecondary)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: onOpen) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Open")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(kindColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(kindColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(item.isCompleted ? Color.white.opacity(0.03) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.isCompleted ? Color.white.opacity(0.05) : kindColor.opacity(0.2), lineWidth: 1)
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
                                Text("Add to your vision")
                                    .font(NoorFont.largeTitle)
                                    .foregroundStyle(.white)

                                Text("What does the life you're building look like? Save the inspiration that keeps you moving.")
                                    .font(NoorFont.bodyLarge)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            .padding(.bottom, 32)

                            // Section: What type
                            VStack(alignment: .leading, spacing: 10) {
                                Text("What kind of inspiration?")
                                    .font(NoorFont.title)
                                    .foregroundStyle(.white)
                            }
                            .padding(.bottom, 16)

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
                                        .foregroundStyle(Color.noorOrange)
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
                                        Text("Paste your Pinterest link")
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

                                        TextField("Give it a name, e.g. \"Dream kitchen\"", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("Keep your inspiration one tap away. Noor connects it to your goals.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .instagram {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Paste the Instagram link")
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

                                        TextField("Give it a name, e.g. \"Solo travel inspo\"", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("Save posts that represent the future you're building.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .destination {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Where do you want to go?")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("e.g. Iceland, Tokyo, Amalfi Coast", text: $placeName)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        TextField("What this trip means to you (optional)", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("When you're ready, Noor helps you search flights and take the leap.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                if kind == .action {
                                    VStack(alignment: .leading, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Need ideas? Pick one to start.")
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

                                        Text("What's the action?")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                        TextField("e.g. Update LinkedIn, message Sarah, open a savings account", text: $title)
                                            .textFieldStyle(.plain)
                                            .font(NoorFont.body)
                                            .foregroundStyle(.white)
                                            .padding(16)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))

                                        Text("Link (optional)")
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

                                        Text("One concrete step that moves you closer. Noor will remind you to act on it.")
                                            .font(NoorFont.bodyLarge)
                                            .foregroundStyle(Color.noorTextSecondary)
                                    }
                                }

                                // Link to journey (if goals exist)
                                if !goals.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Connect to a destination")
                                            .font(NoorFont.title)
                                            .foregroundStyle(.white)
                                        Text("Link this to a goal so Noor can guide your actions.")
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
                                        Text("Add to my vision")
                                            .font(NoorFont.button)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        canSave
                                            ? Color.noorOrange
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

// MARK: - Edit Vision Item Sheet
private struct EditVisionItemSheet: View {
    let item: VisionItem
    let goals: [Goal]
    let onDismiss: () -> Void
    let onSaved: () -> Void

    @State private var kind: VisionItemKind
    @State private var title: String
    @State private var url: String
    @State private var placeName: String
    @State private var selectedGoalID: String?
    @State private var isSaving = false

    init(item: VisionItem, goals: [Goal], onDismiss: @escaping () -> Void, onSaved: @escaping () -> Void) {
        self.item = item
        self.goals = goals
        self.onDismiss = onDismiss
        self.onSaved = onSaved
        _kind = State(initialValue: item.kind)
        _title = State(initialValue: item.title)
        _url = State(initialValue: item.url ?? "")
        _placeName = State(initialValue: item.placeName ?? "")
        _selectedGoalID = State(initialValue: item.goalID)
    }

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .pinterest, .instagram:
            let u = url.trimmingCharacters(in: .whitespaces)
            return !u.isEmpty
        case .destination:
            let p = placeName.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty || !p.isEmpty
        case .action:
            return !t.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Edit vision item")
                            .font(NoorFont.largeTitle)
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                        
                        // Type (read-only or allow change)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Type")
                                .font(NoorFont.title2)
                                .foregroundStyle(.white)
                            HStack(spacing: 10) {
                                Image(systemName: kind.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.noorOrange)
                                Text(kind.displayName)
                                    .font(NoorFont.body)
                                    .foregroundStyle(Color.noorTextSecondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        switch kind {
                        case .pinterest, .instagram:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                                TextField("Name", text: $title)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .tint(Color.noorOrange)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Link")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                                TextField("URL", text: $url)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .tint(Color.noorOrange)
                            }
                        case .destination:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Place name")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                                TextField("Where do you want to go?", text: $placeName)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .tint(Color.noorOrange)
                            }
                            .onChange(of: placeName) { _, new in
                                if title.isEmpty { title = new }
                            }
                        case .action:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Action step")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                                TextField("What action?", text: $title)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .tint(Color.noorOrange)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Link (optional)")
                                    .font(NoorFont.callout)
                                    .foregroundStyle(Color.noorTextSecondary)
                                TextField("URL", text: $url)
                                    .font(NoorFont.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .tint(Color.noorOrange)
                            }
                        }
                        
                        if !goals.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Link to journey")
                                    .font(NoorFont.title2)
                                    .foregroundStyle(.white)
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
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(Color.noorTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? Color.noorOrange : Color.noorTextSecondary)
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let t = title.trimmingCharacters(in: .whitespaces)
        let u = url.trimmingCharacters(in: .whitespaces)
        let p = placeName.trimmingCharacters(in: .whitespaces)
        
        var updated: VisionItem
        switch kind {
        case .pinterest:
            updated = VisionItem(id: item.id, kind: .pinterest, title: t.isEmpty ? (URL(string: u)?.host ?? "Pinterest") : t, url: u, goalID: selectedGoalID, completedAt: item.completedAt)
        case .instagram:
            updated = VisionItem(id: item.id, kind: .instagram, title: t.isEmpty ? "Instagram" : t, url: u, goalID: selectedGoalID, completedAt: item.completedAt)
        case .destination:
            let name = !p.isEmpty ? p : (t.isEmpty ? "Destination" : t)
            updated = VisionItem(id: item.id, kind: .destination, title: name, placeName: name, goalID: selectedGoalID, completedAt: item.completedAt)
        case .action:
            updated = VisionItem(id: item.id, kind: .action, title: t.isEmpty ? "Action" : t, url: u.isEmpty ? nil : u, goalID: selectedGoalID, completedAt: item.completedAt)
        }
        
        var list: [VisionItem] = []
        if let data = UserDefaults.standard.data(forKey: StorageKey.visionItems),
           let decoded = try? JSONDecoder().decode([VisionItem].self, from: data) {
            list = decoded
        }
        if let idx = list.firstIndex(where: { $0.id == item.id }) {
            list[idx] = updated
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: StorageKey.visionItems)
            }
        }
        isSaving = false
        onSaved()
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
                    .foregroundStyle(isSelected ? Color.noorOrange : Color.noorTextSecondary)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.noorOrange.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(kind.displayName)
                    .font(NoorFont.caption)
                    .foregroundStyle(isSelected ? Color.noorOrange : Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.noorOrange.opacity(0.15) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.noorOrange : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
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
                            .foregroundStyle(Color.noorOrange.opacity(0.9))
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
                            .foregroundStyle(Color.noorOrange)
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
                                    .foregroundStyle(Color.noorOrange.opacity(0.9))
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
