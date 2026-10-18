import Charts
import Insights
import StatementParsing
import SwiftUI

/// Donut of the month's spending by category, with the total in the middle.
struct CategoryDonutChart: View {
    let lines: [SpendingSummary.Line<SpendingCategory>]
    let total: Decimal
    let currency: String

    var body: some View {
        Chart(lines) { line in
            SectorMark(
                angle: .value("Amount", line.total.doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(line.key.tint)
            .accessibilityLabel(Text(line.key.title))
            .accessibilityValue(Text(line.total.moneyFormatted(currency: currency)))
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let frame = proxy.plotFrame {
                    VStack(spacing: 2) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(total.moneyFormatted(currency: currency))
                            .font(.headline)
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .frame(width: geometry[frame].width * 0.55)
                    .position(x: geometry[frame].midX, y: geometry[frame].midY)
                }
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
        .accessibilityLabel(Text("Spending by category"))
    }
}

/// Bars of total spending per month, highlighting the selected month.
struct MonthlyTrendChart: View {
    let history: [MonthlySpending]
    let selected: Month?
    let currency: String

    var body: some View {
        Chart(history) { entry in
            BarMark(
                x: .value("Month", entry.month.startDate(), unit: .month),
                y: .value("Spent", entry.spent.doubleValue)
            )
            .cornerRadius(4)
            .foregroundStyle(entry.month == selected ? Color.accentColor : Color.accentColor.opacity(0.3))
            .accessibilityLabel(Text(entry.month.startDate(), format: .dateTime.month(.wide).year()))
            .accessibilityValue(Text(entry.spent.moneyFormatted(currency: currency)))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.notation(.compactName))
                    }
                }
            }
        }
        .frame(height: 160)
        .padding(.vertical, 8)
        .accessibilityLabel(Text("Spending by month"))
    }
}

#Preview("Donut") {
    let summary = SpendingSummary(transactions: ParsedStatement.preview.transactions)
    return List { CategoryDonutChart(lines: summary.byCategory, total: summary.totalSpent, currency: "BAM") }
}

#Preview("Trend") {
    List {
        MonthlyTrendChart(
            history: MonthlySpending.history(ParsedStatement.preview.transactions),
            selected: Month(year: 2026, month: 9), currency: "BAM")
    }
}
