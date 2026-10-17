import Insights
import SwiftUI

/// Lets the user choose a category for a merchant; the choice applies to all of its transactions.
struct CategoryPickerView: View {
    let merchant: String
    @State var selection: SpendingCategory
    let onSelect: (SpendingCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SpendingCategory.assignable) { category in
                        Button {
                            selection = category
                            onSelect(category)
                            dismiss()
                        } label: {
                            HStack {
                                Label {
                                    Text(category.title)
                                } icon: {
                                    Image(systemName: category.systemImage).foregroundStyle(category.tint)
                                }
                                Spacer()
                                if category == selection {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(category == selection ? .isSelected : [])
                    }
                } footer: {
                    Text("Applies to all transactions from \(merchant).")
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CategoryPickerView(merchant: "AMKO KOMERC D.O.O. SAR", selection: .groceries) { _ in }
}
