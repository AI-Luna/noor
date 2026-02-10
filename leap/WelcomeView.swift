import SwiftUI

struct WelcomeView: View {
    var onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.pink)
            
            VStack(spacing: 16) {
                Text("Welcome to Noor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your daily companion for focus and growth.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // The "Let's Go" Button
            Button(action: onFinish) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}
