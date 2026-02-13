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
    @State private var showFallbackShare = false
    @State private var isPulsing = false

    private var canGift: Bool {
        guestPassCount > 0
    }

    private let appLink = "https://testflight.apple.com/join/BJkkK6N6"

    private var shareMessage: String {
        "Hey! I wanted you to have this — it's a free 30-day pass to Noor, the app I've been using to actually follow through on my goals. It's been a game-changer for me and I think you'd love it too.\n\n\(appLink)"
    }

    var body: some View {
        ZStack {
            Color.noorBackground
                .ignoresSafeArea()

            ScrollView {
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
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 12)

                    Spacer().frame(height: 12)

                    // Golden ticket image — large & centered
                    Image("GoldenTicket")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .shadow(color: Color.noorRoseGold.opacity(0.4), radius: 20, x: 0, y: 10)

                    Spacer().frame(height: 12)

                    // Description — bordered card
                    VStack(spacing: 14) {
                        if canGift {
                            Text("Gift 30 Days of Noor Pro")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .scaleEffect(isPulsing ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)

                            Text("You have 1 guest pass this year.\nHere's what they'll unlock:")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                                .multilineTextAlignment(.center)
                                .scaleEffect(isPulsing ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3), value: isPulsing)
                        } else {
                            Text("Guest Pass Already Gifted")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text("You've shared your pass this year.\nCheck back next year to gift again.")
                                .font(NoorFont.body)
                                .foregroundStyle(Color.noorTextSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Pro features list
                        VStack(alignment: .leading, spacing: 10) {
                            featureRow(icon: "airplane", text: "Unlimited dream journeys")
                            featureRow(icon: "flame.fill", text: "Streak tracking & celebrations")
                            featureRow(icon: "eye.fill", text: "Full vision board")
                            featureRow(icon: "leaf.fill", text: "Unlimited habit tracking")
                            featureRow(icon: "sparkles", text: "AI-powered challenges")
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.noorRoseGold.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)

                    // Gift button — pink, pulsing
                    Button {
                        if MFMessageComposeViewController.canSendText() {
                            showShareSheet = true
                        } else {
                            showFallbackShare = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                            Text("Gift Guest Pass")
                                .font(.system(size: 20, weight: .bold, design: .serif))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canGift ? Color.noorAccent : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: canGift ? Color.noorAccent.opacity(isPulsing ? 0.6 : 0.2) : .clear, radius: isPulsing ? 16 : 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGift)
                    .scaleEffect(canGift && isPulsing ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 28)

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
        }
        .onAppear { isPulsing = true }
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
        .sheet(isPresented: $showFallbackShare) {
            ActivityShareSheet(items: [shareMessage])
                .onDisappear {
                    onGift()
                }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.noorRoseGold)
                .frame(width: 22)
            Text(text)
                .font(NoorFont.body)
                .foregroundStyle(Color.noorTextSecondary)
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
