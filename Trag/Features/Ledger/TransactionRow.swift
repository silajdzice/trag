import Insights
import StatementParsing
import SwiftUI

struct TransactionRow: View {
    let transaction: BankTransaction
    let category: SpendingCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .foregroundStyle(category.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: transaction.counterparty)
                    .lineLimit(1)
                Text(transaction.bookingDate, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amount.moneyFormatted(currency: transaction.currency))
                .monospacedDigit()
                .foregroundStyle(transaction.isExpense ? Color.primary : Color.green)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        let amount = transaction.amount.magnitude.moneyFormatted(currency: transaction.currency)
        return transaction.isExpense
            ? Text("\(transaction.counterparty), spent \(amount)")
            : Text("\(transaction.counterparty), received \(amount)")
    }
}
