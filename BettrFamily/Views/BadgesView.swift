import SwiftUI
import SwiftData

struct BadgesView: View {
    @EnvironmentObject var authService: AuthService
    @Query private var allBadges: [Badge]
    @Environment(\.dismiss) private var dismiss

    private var myBadges: [Badge] {
        guard let memberID = authService.memberID else { return [] }
        return allBadges.filter { $0.memberID == memberID }
    }

    private var earnedIDs: Set<String> {
        Set(myBadges.map { $0.badgeType })
    }

    private var groupedDefinitions: [(BadgeDefinition.BadgeCategory, [BadgeDefinition])] {
        BadgeDefinition.BadgeCategory.allCases.map { category in
            (category, BadgeDefinition.all.filter { $0.category == category })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(myBadges.count)")
                                .font(.title.bold())
                            Text("Verdient")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(BadgeDefinition.all.count)")
                                .font(.title.bold())
                                .foregroundStyle(.secondary)
                            Text("Insgesamt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()

                    // Badge grid by category
                    ForEach(groupedDefinitions, id: \.0) { category, definitions in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                ForEach(definitions) { definition in
                                    badgeCell(definition)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Badges")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func badgeCell(_ definition: BadgeDefinition) -> some View {
        let isEarned = earnedIDs.contains(definition.id)
        let earnedDate = myBadges.first { $0.badgeType == definition.id }?.earnedDate

        return VStack(spacing: 4) {
            Text(definition.emoji)
                .font(.system(size: 36))
                .grayscale(isEarned ? 0 : 1)
                .opacity(isEarned ? 1 : 0.3)

            Text(definition.name)
                .font(.caption2.bold())
                .lineLimit(1)
                .foregroundStyle(isEarned ? .primary : .secondary)

            if let earnedDate {
                Text(earnedDate, format: .dateTime.day().month())
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            } else {
                Text(definition.description)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 80, height: 90)
    }
}

// MARK: - Badge Earned Toast

struct BadgeEarnedToast: View {
    let badge: BadgeDefinition
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(badge.emoji)
                .font(.system(size: 64))

            Text("Badge verdient!")
                .font(.title2.bold())

            Text(badge.name)
                .font(.headline)
                .foregroundStyle(.orange)

            Text(badge.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Weiter") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
    }
}
