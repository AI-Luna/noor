//
//  ContentView.swift
//  leap
//
//  Main tab navigation: Home, Categories, Settings
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "flame.fill")
                }
            CategoriesView()
                .tabItem {
                    Label("Categories", systemImage: "square.grid.2x2.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.noorPink)
    }
}

#Preview {
    ContentView()
}
