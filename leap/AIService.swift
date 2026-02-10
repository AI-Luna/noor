//
//  AIService.swift
//  leap
//
//  Claude API integration for AI-generated challenge itineraries
//  "Travel agency for life" - personalized micro-actions
//

import Foundation

// MARK: - AI Generated Challenge
struct AIChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let estimatedTime: String
    var completed: Bool
    var unlocked: Bool
    var completedAt: Date?

    init(id: String, title: String, description: String, estimatedTime: String, completed: Bool = false, unlocked: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.estimatedTime = estimatedTime
        self.completed = completed
        self.unlocked = unlocked
        self.completedAt = completedAt
    }
}

// MARK: - AI Response
struct AIGenerationResponse: Codable {
    let challenges: [ChallengeData]
    let boardingPass: String

    struct ChallengeData: Codable {
        let title: String
        let description: String
        let estimatedTime: String
    }
}

// MARK: - AI Service
@Observable
final class AIService {
    static let shared = AIService()

    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    var isGenerating = false
    var errorMessage: String?

    private init() {
        // API key should be stored securely - for hackathon using bundled key
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
    }

    // MARK: - Generate Challenges
    func generateChallenges(
        category: GoalCategory,
        destination: String,
        timeline: String,
        userStory: String
    ) async -> (challenges: [AIChallenge], encouragement: String)? {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let prompt = buildPrompt(category: category, destination: destination, timeline: timeline, userStory: userStory)

        do {
            let response = try await callClaudeAPI(prompt: prompt)
            return parseResponse(response, category: category)
        } catch {
            print("AI generation failed: \(error)")
            errorMessage = "Couldn't generate your itinerary. Using template instead."
            return generateFallbackChallenges(category: category, destination: destination)
        }
    }

    // MARK: - Build Prompt
    private func buildPrompt(category: GoalCategory, destination: String, timeline: String, userStory: String) -> String {
        switch category {
        case .travel:
            return """
            You are a travel agent for life. This woman is already a solo traveler—you're just helping her book the logistics for her next trip.

            DESTINATION: \(destination)
            TIMELINE: \(timeline)
            HER STORY: "\(userStory)"

            Generate 7 micro-actions that:
            - Start TINY (5-15 min each, first one should be 5 min max)
            - Build sequentially (each unlocks next)
            - Use travel agency language ("confirm", "reserve", "book", not "try" or "hope")
            - Assume she's ALREADY the woman who does this
            - Frame as inevitable, just handling logistics
            - Make first action ridiculously easy (builds momentum)

            Return ONLY valid JSON (no markdown, no backticks):
            {
              "challenges": [
                {
                  "title": "Confirm your dates",
                  "description": "Open your calendar and block \(timeline). This trip is happening.",
                  "estimatedTime": "5 min"
                }
              ],
              "boardingPass": "Your flight to the woman who travels solo is boarding."
            }
            """

        case .career:
            return """
            You are a career strategist. This woman is already qualified for this role—you're mapping the path to claim it.

            ROLE: \(destination)
            TIMELINE: \(timeline)
            HER STORY: "\(userStory)"

            Generate 7 micro-actions (5-20 min each) that bridge where she is to where she's going. Use confident language ("schedule", "update", "document"). Assume competence, just need logistics. Start tiny.

            Return ONLY valid JSON (no markdown, no backticks):
            {
              "challenges": [
                {
                  "title": "Update your LinkedIn headline",
                  "description": "Change it to your target role. You're already her.",
                  "estimatedTime": "5 min"
                }
              ],
              "boardingPass": "Your promotion to \(destination) is processing."
            }
            """

        case .finance:
            return """
            You are a financial planning agent. She's building wealth—you're creating the system.

            GOAL: \(destination)
            TIMELINE: \(timeline)
            HER STORY: "\(userStory)"

            Generate 7 micro-actions. Start small (track spending for 3 days) and build to bigger (open investment account). Use language of inevitability. First action should be 5 min max.

            Return ONLY valid JSON (no markdown, no backticks):
            {
              "challenges": [
                {
                  "title": "Calculate your current position",
                  "description": "Open your bank app. Note your balance. This is your starting point.",
                  "estimatedTime": "5 min"
                }
              ],
              "boardingPass": "Your path to financial freedom is mapped."
            }
            """

        case .growth:
            return """
            You are a personal development strategist. She's evolving—you're structuring the transformation.

            GOAL: \(destination)
            TIMELINE: \(timeline)
            HER STORY: "\(userStory)"

            Generate 7 micro-actions for internal growth. Make tangible and trackable. Start tiny. Use language that assumes she's already becoming this person.

            Return ONLY valid JSON (no markdown, no backticks):
            {
              "challenges": [
                {
                  "title": "Define your transformation",
                  "description": "Write one sentence: 'I am becoming someone who...'",
                  "estimatedTime": "5 min"
                }
              ],
              "boardingPass": "Your journey to \(destination) is underway."
            }
            """

        case .relationship:
            return """
            You are a relationship coach. She already deserves love—you're helping her prepare to receive it.

            GOAL: \(destination)
            TIMELINE: \(timeline)
            HER STORY: "\(userStory)"

            Generate 7 micro-actions that prepare her emotionally and practically. Start with self-work, build to action. Use language of worthiness and inevitability.

            Return ONLY valid JSON (no markdown, no backticks):
            {
              "challenges": [
                {
                  "title": "Define your non-negotiables",
                  "description": "Write down 3 things you won't compromise on. You deserve them.",
                  "estimatedTime": "10 min"
                }
              ],
              "boardingPass": "Your path to love is open."
            }
            """
        }
    }

    // MARK: - Call Claude API
    private func callClaudeAPI(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1500,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIServiceError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    // MARK: - Parse Response
    private func parseResponse(_ response: String, category: GoalCategory) -> (challenges: [AIChallenge], encouragement: String)? {
        // Clean up response - remove any markdown formatting
        var cleanedResponse = response
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if cleanedResponse.hasPrefix("```") {
            if let startIndex = cleanedResponse.firstIndex(of: "{"),
               let endIndex = cleanedResponse.lastIndex(of: "}") {
                cleanedResponse = String(cleanedResponse[startIndex...endIndex])
            }
        }

        guard let data = cleanedResponse.data(using: .utf8) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(AIGenerationResponse.self, from: data)

            let challenges = decoded.challenges.enumerated().map { index, challenge in
                AIChallenge(
                    id: "challenge_\(index + 1)",
                    title: challenge.title,
                    description: challenge.description,
                    estimatedTime: challenge.estimatedTime,
                    completed: false,
                    unlocked: index == 0 // Only first challenge unlocked
                )
            }

            return (challenges, decoded.boardingPass)
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }

    // MARK: - Fallback Challenges
    private func generateFallbackChallenges(category: GoalCategory, destination: String) -> (challenges: [AIChallenge], encouragement: String) {
        let fallbackData: [(title: String, description: String, time: String)]

        switch category {
        case .travel:
            fallbackData = [
                ("Confirm your dates", "Open your calendar and block your travel dates. This trip is happening.", "5 min"),
                ("Research stays", "Browse Airbnb in \(destination). You're staying somewhere beautiful.", "15 min"),
                ("Price flights", "Check Google Flights. Get a sense of the investment.", "10 min"),
                ("Join a travel community", "Find a solo female travel group for \(destination).", "10 min"),
                ("Plan your first 3 days", "Outline what you'll do. The details make it real.", "20 min"),
                ("Book a refundable stay", "Reserve your accommodation. You can adjust later.", "15 min"),
                ("Tell someone", "Share your plan with one person. Make it accountable.", "5 min")
            ]

        case .career:
            fallbackData = [
                ("Update your headline", "Change your LinkedIn to your target role.", "5 min"),
                ("Identify 5 target companies", "List companies where you'd thrive.", "15 min"),
                ("Audit your resume", "Does it reflect who you're becoming?", "20 min"),
                ("Reach out to one person", "Message someone at a target company.", "10 min"),
                ("Practice your story", "Write your 30-second pitch.", "15 min"),
                ("Apply to one role", "Submit one application. Start the momentum.", "20 min"),
                ("Schedule a coffee chat", "Book a conversation with someone in your target role.", "10 min")
            ]

        case .finance:
            fallbackData = [
                ("Check your current position", "Note your bank balance. Know your starting point.", "5 min"),
                ("Track 3 days of spending", "Write down everything you spend.", "5 min/day"),
                ("Identify one expense to cut", "Find something you won't miss.", "10 min"),
                ("Set up auto-transfer", "Even $10/week builds the habit.", "15 min"),
                ("Research one investment option", "Learn about index funds or savings accounts.", "20 min"),
                ("Open a high-yield savings", "Your money should work for you.", "15 min"),
                ("Calculate your freedom number", "What monthly income = freedom for you?", "15 min")
            ]

        case .growth:
            fallbackData = [
                ("Define your transformation", "Write: 'I am becoming someone who...'", "5 min"),
                ("Identify one limiting belief", "What story is holding you back?", "10 min"),
                ("Rewrite the belief", "Create a new narrative that serves you.", "10 min"),
                ("Take one small action", "Do something the 'new you' would do.", "15 min"),
                ("Document your evidence", "Write down proof you're already her.", "10 min"),
                ("Share your growth", "Tell someone about your transformation.", "10 min"),
                ("Plan your next level", "What's the next version of you?", "15 min")
            ]

        case .relationship:
            fallbackData = [
                ("Define your non-negotiables", "Write 3 things you won't compromise on.", "10 min"),
                ("Clear old energy", "Unfollow/delete anything that doesn't serve you.", "15 min"),
                ("Practice receiving", "Let someone do something nice for you today.", "5 min"),
                ("Update your dating profile", "Or prepare one that reflects who you are now.", "20 min"),
                ("Plan a solo date", "Show yourself you're worth the effort.", "15 min"),
                ("Reach out or respond", "Make one move toward connection.", "10 min"),
                ("Visualize your partnership", "Write about your ideal Sunday morning together.", "10 min")
            ]
        }

        let challenges = fallbackData.enumerated().map { index, data in
            AIChallenge(
                id: "challenge_\(index + 1)",
                title: data.title,
                description: data.description,
                estimatedTime: data.time,
                completed: false,
                unlocked: index == 0
            )
        }

        let encouragement: String
        switch category {
        case .travel: encouragement = "Your flight to \(destination) is boarding."
        case .career: encouragement = "Your promotion to \(destination) is processing."
        case .finance: encouragement = "Your path to financial freedom is mapped."
        case .growth: encouragement = "Your journey to \(destination) is underway."
        case .relationship: encouragement = "Your path to love is open."
        }

        return (challenges, encouragement)
    }
}

// MARK: - Errors
enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case apiError
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API key not configured"
        case .invalidURL: return "Invalid API URL"
        case .apiError: return "API request failed"
        case .invalidResponse: return "Invalid response from AI"
        }
    }
}
