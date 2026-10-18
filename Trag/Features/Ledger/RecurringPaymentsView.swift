import Insights
import SwiftUI

/// All subscriptions and bills Trag found, with the next expected charge.
struct RecurringPaymentsView: View {
    let payments: [RecurringPayment]

    var body: some View {
        List {
            if payments.isEmpty {
                ContentUnavailableView(
                    "No recurring payments yet",
                    systemImage: "repeat",
                    description: Text("They appear once you have imported at least two months of statements.")
                )
            }
            section(Text("Subscriptions"), kind: .subscription)
            section(Text("Bills"), kind: .bill)
        }
        .navigationTitle("Subscriptions & bills")
    }

    @ViewBuilder
    private func section(_ title: Text, kind: RecurringPayment.Kind) -> some View {
        let items = payments.filter { $0.kind == kind }
        if !items.isEmpty {
            Section {
                ForEach(items) { RecurringPaymentRow(payment: $0) }
            } header: {
                title
            } footer: {
                let total = items.reduce(Decimal.zero) { $0 + $1.monthlyAmount }
                Text("\(total.moneyFormatted(currency: items[0].currency)) per month")
            }
        }
    }
}

struct RecurringPaymentRow: View {
    let payment: RecurringPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: payment.name)
                    .lineLimit(1)
                Text("Next charge \(payment.nextExpected.formatted(.dateTime.day().month()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.monthlyAmount.moneyFormatted(currency: payment.currency))
                    .monospacedDigit()
                if let original = payment.originalAmount {
                    Text(original.amount.moneyFormatted(currency: original.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        RecurringPaymentsView(payments: LedgerModel.preview().recurringPayments)
    }
}
