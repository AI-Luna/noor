//
//  PrimaryButton.swift
//  leap
//
//  Pink primary CTA — 56pt height, fully rounded
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoorFont.title2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: NoorLayout.buttonHeight)
                .background(Color.noorPink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoorFont.callout)
                .foregroundStyle(Color.noorPink)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Start 7-Day Free Trial", action: {})
        SecondaryButton(title: "Restore Purchases", action: {})
    }
    .padding()
}
