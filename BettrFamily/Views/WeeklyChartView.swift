import SwiftUI
import SwiftData
import Charts

struct IdentifiableDate: Identifiable {
    let date: Date
    var id: Date { date }
}

struct WeeklyChartView: View {
    @Query(sort: \DailyScore.date) private var allScores: [DailyScore]
    @Query private var familyMembers: [FamilyMember]

    @State private var selectedDay: Date?
    @State private var sheetDay: IdentifiableDate?

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
    }

    private func familyScoreForDay(_ day: Date) -> Double {
        allScores.filter { $0.date == day }.reduce(0) { $0 + $1.finalScore }
    }

    private var weekTotal: Double {
        weekDays.reduce(0) { $0 + familyScoreForDay($1) }
    }

    private var averageScore: Double {
        let daysWithData = weekDays.filter { day in allScores.contains { $0.date == day } }.count
        guard daysWithData > 0 else { return 0 }
        return weekTotal / Double(daysWithData)
    }

    private var positiveDays: Int {
        weekDays.filter { familyScoreForDay($0) > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text("Family Health — Letzte 7 Tage")
                    .font(.headline)
            }

            // Chart
            Chart {
                ForEach(weekDays, id: \.self) { day in
                    let value = familyScoreForDay(day)

                    BarMark(
                        x: .value("Tag", day, unit: .day),
                        y: .value("Punkte", value)
                    )
                    .foregroundStyle(value >= 0 ? .green : .red)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXSelection(value: $selectedDay)
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
        .onChange(of: selectedDay) { _, newDay in
            if let newDay {
                let snapped = Calendar.current.startOfDay(for: newDay)
                if weekDays.contains(snapped) {
                    sheetDay = IdentifiableDate(date: snapped)
                }
                selectedDay = nil
            }
        }
        .sheet(item: $sheetDay) { item in
            DayDetailView(date: item.date)
        }
    }
}
