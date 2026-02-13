//
//  PassportView.swift
//  leap
//
//  Noor Passport: World map with real vacation pins and lifetime travel metrics
//

import SwiftUI

struct PassportView: View {
    @Environment(DataManager.self) private var dataManager
    @State private var pins: [TravelPin] = []
    @State private var isLoading = true
    @State private var selectedPin: TravelPin?
    @State private var showAddVacation = false

    // MARK: - Computed Metrics
    private var placesVisited: Int { pins.count }

    private var uniqueCountries: Int {
        Set(pins.map { $0.country }).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // World Map with airplane banner
                        worldMapSection

                        // Passport Header
                        passportHeader
                            .padding(.top, 20)

                        // Metrics Grid
                        metricsSection
                            .padding(.top, 16)

                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 4)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        Text("Noor Passport")
                            .font(NoorFont.title2)
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAddVacation = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(item: $selectedPin) { pin in
                VacationDetailSheet(pin: pin, onDelete: {
                    deletePin(pin)
                })
            }
            .sheet(isPresented: $showAddVacation) {
                AddVacationSheet(onSave: { pin in
                    savePin(pin)
                })
            }
        }
    }

    // MARK: - World Map Section
    private var worldMapSection: some View {
        VStack(spacing: 0) {
            PassportAirplaneBanner()
                .padding(.bottom, 8)
            PassportWorldMap(pins: pins, onPinTap: { pin in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                selectedPin = pin
            })
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Passport Header
    private var passportHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MY NOOR PASSPORT")
                    .font(NoorFont.title)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.system(size: 10))
                    Text("PASSPORT \u{2022} VOYAGE \u{2022} DESTINO")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundStyle(Color.noorAccent)
            }

            Spacer()

            // Journey count badge
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.noorViolet.opacity(0.6), Color.noorAccent.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    VStack(spacing: 1) {
                        Text("\(placesVisited)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("PINS")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                )
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    // MARK: - Metrics Section
    private var metricsSection: some View {
        HStack(spacing: 12) {
            metricTile(
                label: "PLACES VISITED",
                value: "\(placesVisited)",
                suffix: nil
            )
            metricTile(
                label: "COUNTRIES",
                value: "\(uniqueCountries)",
                suffix: nil
            )
        }
        .padding(.horizontal, NoorLayout.horizontalPadding)
    }

    private func metricTile(label: String, value: String, suffix: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(NoorFont.caption)
                .foregroundStyle(Color.noorTextSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data
    private func loadData() {
        Task { @MainActor in
            do {
                pins = try await dataManager.fetchTravelPins()
                isLoading = false
            } catch {
                print("Failed to load travel pins: \(error)")
                isLoading = false
            }
        }
    }

    private func savePin(_ pin: TravelPin) {
        Task { @MainActor in
            do {
                try await dataManager.saveTravelPin(pin)
                pins = try await dataManager.fetchTravelPins()
            } catch {
                print("Failed to save travel pin: \(error)")
            }
        }
    }

    private func deletePin(_ pin: TravelPin) {
        Task { @MainActor in
            do {
                try await dataManager.deleteTravelPin(pin.id)
                pins = try await dataManager.fetchTravelPins()
                selectedPin = nil
            } catch {
                print("Failed to delete travel pin: \(error)")
            }
        }
    }
}

// MARK: - Add Vacation Sheet
private struct AddVacationSheet: View {
    let onSave: (TravelPin) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var destination = ""
    @State private var country = ""
    @State private var dateVisited = Date()

    private var canSave: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        !country.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.noorBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        inputField(label: "DESTINATION", placeholder: "Paris", text: $destination)
                        inputField(label: "COUNTRY", placeholder: "France", text: $country)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE VISITED")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.noorTextSecondary)
                            DatePicker("", selection: $dateVisited, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.noorAccent)
                                .colorScheme(.dark)
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        let pin = TravelPin(
                            destination: destination.trimmingCharacters(in: .whitespaces),
                            country: country.trimmingCharacters(in: .whitespaces),
                            dateVisited: dateVisited
                        )
                        onSave(pin)
                        dismiss()
                    } label: {
                        Text("Pin It")
                            .font(NoorFont.body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSave ? Color.noorAccent : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSave)

                    Spacer()
                }
                .padding(.horizontal, NoorLayout.horizontalPadding)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Vacation")
                        .font(NoorFont.title2)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.noorTextSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.noorTextSecondary)
            TextField(placeholder, text: text)
                .font(NoorFont.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Vacation Detail Sheet (shown when tapping a map pin)
private struct VacationDetailSheet: View {
    let pin: TravelPin
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: pin.dateVisited)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.noorAccent)
                    Text(pin.country.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.noorAccent)
                }

                Text(pin.destination)
                    .font(NoorFont.title)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Info
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "mappin.and.ellipse", label: "DESTINATION", value: pin.destination)
                infoRow(icon: "globe.americas.fill", label: "COUNTRY", value: pin.country)
                infoRow(icon: "calendar", label: "VISITED", value: formattedDate)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Delete button
            Button(role: .destructive) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDelete()
                }
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Remove Pin")
                        .font(NoorFont.body)
                }
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.noorBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.noorAccent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.noorTextSecondary)
                Text(value)
                    .font(NoorFont.body)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Dainty airplane banner (above the world map)
private struct PassportAirplaneBanner: View {
    private let pastelColors: [Color] = [
        Color(red: 1.0, green: 0.85, blue: 0.75),   // peach
        Color(red: 0.98, green: 0.75, blue: 0.85),  // light pink
        Color(red: 0.85, green: 0.88, blue: 1.0),   // light blue
        Color(red: 0.82, green: 0.92, blue: 0.88),  // mint/teal
        Color(red: 0.95, green: 0.88, blue: 0.98),  // lavender
        Color(white: 0.92),                          // light gray
    ]
    private let pastelPlaneItems: [(isDash: Bool, isHighlighted: Bool, colorIndex: Int)] = [
        (false, false, 0), (false, false, 1), (false, true, 2),
        (true, false, 0), (true, false, 0),
        (false, false, 3), (false, false, 4), (false, true, 5),
        (true, false, 0), (true, false, 0),
        (false, false, 0), (false, false, 1), (false, false, 2),
        (false, false, 3), (false, false, 4),
    ]

    var body: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 4)
            ForEach(Array(pastelPlaneItems.enumerated()), id: \.offset) { index, item in
                if item.isDash {
                    Text("\u{2013}")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                } else {
                    let color = pastelColors[item.colorIndex % pastelColors.count]
                    Group {
                        if item.isHighlighted {
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.5))
                                    .frame(width: 18, height: 18)
                                Image(systemName: "airplane")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(color)
                            }
                        } else {
                            Image(systemName: "airplane")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(color)
                        }
                    }
                }
            }
            Spacer(minLength: 4)
        }
    }
}

// MARK: - Passport World Map (purple map with tappable vacation pins)
private struct PassportWorldMap: View {
    let pins: [TravelPin]
    let onPinTap: (TravelPin) -> Void

    // Land positions (x%, y%) on purple map — spread across continents
    private let landPositions: [(CGFloat, CGFloat)] = [
        (0.20, 0.32), (0.16, 0.38), (0.26, 0.42),  // Americas
        (0.24, 0.58), (0.28, 0.68), (0.20, 0.72),  // South America
        (0.48, 0.30), (0.54, 0.26), (0.52, 0.36),  // Europe
        (0.56, 0.48), (0.60, 0.55), (0.52, 0.58),  // Africa
        (0.72, 0.32), (0.80, 0.38), (0.76, 0.48),  // Asia
        (0.86, 0.42), (0.88, 0.52), (0.82, 0.28),  // East Asia
        (0.78, 0.70), (0.84, 0.76), (0.72, 0.78),  // Australia
        (0.62, 0.40), (0.68, 0.44), (0.58, 0.52),  // Middle East / India
        (0.32, 0.35), (0.18, 0.50), (0.38, 0.62),
    ]

    private func positionForPin(_ pin: TravelPin, at index: Int) -> (CGFloat, CGFloat) {
        var hasher = Hasher()
        hasher.combine(pin.id)
        let hash = abs(hasher.finalize())
        let idx = (hash + index) % landPositions.count
        return landPositions[idx]
    }

    var body: some View {
        GeometryReader { outerGeo in
            ZStack {
                Image("PassportWorldMapPurple")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Vacation pins — tappable, all accent color
                ForEach(Array(pins.enumerated()), id: \.element.id) { index, pin in
                    let pos = positionForPin(pin, at: index)
                    Button {
                        onPinTap(pin)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.noorAccent.opacity(0.4))
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(Color.noorAccent)
                                .frame(width: 10, height: 10)
                                .shadow(color: .black.opacity(0.4), radius: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: outerGeo.size.width * pos.0,
                        y: outerGeo.size.height * pos.1
                    )
                }
            }
        }
    }
}

#Preview {
    PassportView()
}
