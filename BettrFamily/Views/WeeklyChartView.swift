import SwiftUI
import SwiftData
import Charts

struct WeeklyChartView: View {
    @EnvironmentObject var authService: AuthService
    @Query(sort: \DailyScore.date) private var allScores: [DailyScore]

    private var myWeekScores: [DailyScore] {
        guard let memberID = authService.memberID else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        return allScores.filter { $0.memberID == memberID && $0.date >= weekAgo }
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
    }

    private var weekTotal: Double {
        myWeekScores.reduce(0) { $0 + $1.finalScore }
    }

    private var averageScore: Double {
        guard !myWeekScores.isEmpty else { return 0 }
        return weekTotal / Double(myWeekScores.count)
    }

    private var positiveDays: Int {
        myWeekScores.filter { $0.isPositiveDay }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage")
                .font(.headline)

            // Chart
            Chart {
                ForEach(weekDays, id: \.self) { day in
                    let score = myWeekScores.first { $0.date == day }
                    let value = score?.finalScore ?? 0

                    BarMark(
                        x: .value("Tag", day, unit: .day),
                        y: .value("Punkte", value)
                    )
                    .foregroundStyle(value >= 0 ? .green : .red)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)

            // Summary stats
            HStack(spacing: 24) {
                VStack {
                    Text("\(Int(weekTotal))")
                        .font(.title3.bold())
                        .foregroundStyle(weekTotal >= 0 ? .green : .red)
                    Text("Gesamt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f", averageScore))
                        .font(.title3.bold())
                    Text("Durchschnitt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(positiveDays)/7")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    Text("Positive Tage")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
