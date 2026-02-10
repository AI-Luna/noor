//
//  GoldenTicketSheet.swift
//  leap
//
//  Golden Ticket: gift 30 days free (guest pass) to someone else.
//

import SwiftUI

struct GoldenTicketSheet: View {
    let guestPassCount: Int
    let onDismiss: () -> Void
    let onGift: () -> Void

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.noorTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                Spacer().frame(height: 24)

                Image("GoldenTicket")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: Color.noorRoseGold.opacity(0.3), radius: 16, x: 0, y: 8)

                Button(action: onGift) {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                        Text("Gift Guest Pass")
                            .font(NoorFont.button)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.noorRoseGold.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Text("You have \(guestPassCount) guest pass\(guestPassCount == 1 ? "" : "es") to gift. A guest pass gives someone 30 days of Noor Pro completely free.")
                    .font(NoorFont.caption)
                    .foregroundStyle(Color.noorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                Spacer()

                Button("Not now") {
                    onDismiss()
                }
                .font(NoorFont.callout)
                .foregroundStyle(Color.noorTextSecondary)
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    GoldenTicketSheet(guestPassCount: 5, onDismiss: {}, onGift: {})
}
