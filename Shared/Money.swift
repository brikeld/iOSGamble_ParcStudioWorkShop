import SwiftUI

extension Int {
    var dollars: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(Locale(identifier: "en_US")))
    }
}

func profitText(_ profit: Int) -> String {
    profit == 0 ? 0.dollars : (profit > 0 ? "+" : "−") + abs(profit).dollars
}

func profitColor(_ profit: Int) -> Color {
    profit > 0 ? .green : profit < 0 ? .orange : .secondary
}
