import SwiftUI

// MARK: - Models

struct AmortizationMonth: Identifiable {
    let id = UUID()
    let month: Int
    let principal: Double
    let interest: Double
    let balance: Double
}

struct AmortizationYear: Identifiable {
    let id = UUID()
    let year: Int
    let principal: Double
    let interest: Double
    let balance: Double
    let months: [AmortizationMonth]
}

enum LoanType: String, CaseIterable, Identifiable {
    case fixed30 = "30yr Fixed"
    case arm5    = "5/6 ARM"
    case arm7    = "7/6 ARM"
    case arm10   = "10/6 ARM"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .fixed30: return "30yr"
        case .arm5:    return "5/6"
        case .arm7:    return "7/6"
        case .arm10:   return "10/6"
        }
    }

    var isARM: Bool { self != .fixed30 }

    var armFixedYears: Int? {
        switch self {
        case .arm5:    return 5
        case .arm7:    return 7
        case .arm10:   return 10
        case .fixed30: return nil
        }
    }
}

// MARK: - ViewModel

class MortgageViewModel: ObservableObject {
    @Published var homePriceText:    String = "1500000"
    @Published var interestRateText: String = "6.750"
    @Published var additionalDown:   String = ""
    @Published var taxRateText:      String = "1.17"
    @Published var insuranceText:    String = ""
    @Published var loanType:         LoanType = .fixed30

    // MARK: Parsed inputs

    var homePrice: Double {
        Double(homePriceText.filter { $0.isNumber || $0 == "." }) ?? 0
    }
    var interestRate: Double { Double(interestRateText) ?? 0 }
    var addlDown: Double {
        Double(additionalDown.filter { $0.isNumber || $0 == "." }) ?? 0
    }
    var taxRate: Double { Double(taxRateText) ?? 1.17 }

    // MARK: Down payment logic
    // Use 30% when a 20% down payment would still leave a loan > $3M (home > $3.75M)
    var defaultDownPercent: Double {
        homePrice * 0.80 > 3_000_000 ? 0.30 : 0.20
    }

    var baseDown:   Double { homePrice * defaultDownPercent }
    var totalDown:  Double { baseDown + addlDown }
    var loanAmount: Double { max(homePrice - totalDown, 0) }
    var ltv:        Double { homePrice > 0 ? loanAmount / homePrice : 0 }

    // MARK: Insurance

    var defaultInsurance: Double { homePrice * 0.005 / 12 }
    var insurance: Double {
        if insuranceText.isEmpty { return defaultInsurance }
        return Double(insuranceText.filter { $0.isNumber || $0 == "." }) ?? defaultInsurance
    }

    // MARK: Monthly payment (amortized over 30 years)

    var monthlyPI: Double {
        guard loanAmount > 0, interestRate > 0 else { return 0 }
        let r = interestRate / 100.0 / 12.0
        let n = 360.0
        return loanAmount * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
    }

    var monthlyTax:   Double { homePrice * taxRate / 100.0 / 12.0 }
    var totalMonthly: Double { monthlyPI + monthlyTax + insurance }

    // Proportions for the breakdown bar
    var piProportion:  Double { totalMonthly > 0 ? monthlyPI  / totalMonthly : 0 }
    var taxProportion: Double { totalMonthly > 0 ? monthlyTax / totalMonthly : 0 }
    var insProportion: Double { totalMonthly > 0 ? insurance  / totalMonthly : 0 }

    // MARK: Amortization schedule

    var schedule: [AmortizationYear] {
        guard loanAmount > 0, interestRate > 0 else { return [] }
        let r       = interestRate / 100.0 / 12.0
        let payment = monthlyPI
        var balance = loanAmount
        var result: [AmortizationYear] = []
        var monthNum = 0

        for yr in 1...30 {
            var months: [AmortizationMonth] = []
            var yrPrin = 0.0
            var yrInt  = 0.0

            for _ in 0..<12 {
                guard balance > 0.01 else { break }
                let intPmt  = balance * r
                let prinPmt = min(payment - intPmt, balance)
                balance     = max(balance - prinPmt, 0)
                yrPrin  += prinPmt
                yrInt   += intPmt
                monthNum += 1
                months.append(AmortizationMonth(
                    month:     monthNum,
                    principal: prinPmt,
                    interest:  intPmt,
                    balance:   balance
                ))
            }

            guard !months.isEmpty else { break }
            result.append(AmortizationYear(
                year:      yr,
                principal: yrPrin,
                interest:  yrInt,
                balance:   balance,
                months:    months
            ))
            if balance < 0.01 { break }
        }
        return result
    }

    var totalInterest:  Double { schedule.reduce(0) { $0 + $1.interest } }
    var totalCostOfLoan: Double { loanAmount + totalInterest }
}

// MARK: - Formatting helpers

extension Double {
    var currency: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    var currencyExact: String {
        formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
    var pct1: String { String(format: "%.1f%%", self) }
    var pct2: String { String(format: "%.2f%%", self) }
    var pct3: String { String(format: "%.3f%%", self) }
}
