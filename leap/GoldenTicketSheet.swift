//
//  GoldenTicketSheet.swift
//  leap
//
//  Golden Ticket: gift 30 days free (guest pass) to someone else.
//  Pro users can gift one pass per year.
//

import SwiftUI
import MessageUI

struct GoldenTicketSheet: View {
    let guestPassCount: Int
    let onDismiss: () -> Void
    let onGift: () -> Void

    @State private var showShareSheet = false
    @State private var showMailUnavailable = false

    private var canGift: Bool {
        guestPassCount > 0
    }

    private let appLink = "https://testflight.apple.com/join/YOUR_TESTFLIGHT_CODE"

    private var shareMessage: String {
        "You've been gifted a Noor Pro Guest Pass — 30 days of unlimited access, completely free.\n\nNoor is a goal-tracking app that helps you build the life you've been dreaming of, one step at a time.\n\nClaim your pass here: \(appLink)"
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
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

                Spacer().frame(height: 16)

                // Golden ticket image — large & centered
                Image("GoldenTicket")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .shadow(color: Color.noorRoseGold.opacity(0.4), radius: 20, x: 0, y: 10)

                Spacer().frame(height: 24)

                // Gift description
                if canGift {
                    Text("You have 1 guest pass to gift this year.\nGive someone 30 days of Noor Pro, free.")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("You've already gifted your guest pass this year.\nCheck back next year to share again.")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 20)

                // Gift button — pink
                Button {
                    if MFMessageComposeViewController.canSendText() {
                        showShareSheet = true
                    } else {
                        // Fallback to system share sheet
                        showMailUnavailable = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                        Text("Gift Guest Pass")
                            .font(NoorFont.button)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        canGift ?
                        Color.noorAccent :
                        Color.white.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!canGift)
                .padding(.horizontal, 24)

                Spacer()

                // FOMO dismiss
                Button {
                    onDismiss()
                } label: {
                    Text("Keep this blessing to myself")
                        .font(NoorFont.caption)
                        .foregroundStyle(Color.noorTextSecondary.opacity(0.6))
                        .italic()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            MessageComposeView(
                message: shareMessage,
                onComplete: { result in
                    showShareSheet = false
                    if result == .sent {
                        onGift()
                    }
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMailUnavailable) {
            // Fallback: system share sheet if Messages unavailable
            ActivityShareSheet(items: [shareMessage])
                .onDisappear {
                    onGift()
                }
        }
    }
}

// MARK: - Messages Compose View
struct MessageComposeView: UIViewControllerRepresentable {
    let message: String
    let onComplete: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.body = message
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onComplete: (MessageComposeResult) -> Void

        init(onComplete: @escaping (MessageComposeResult) -> Void) {
            self.onComplete = onComplete
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            onComplete(result)
        }
    }
}

// MARK: - Fallback Share Sheet
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GoldenTicketSheet(guestPassCount: 1, onDismiss: {}, onGift: {})
}
