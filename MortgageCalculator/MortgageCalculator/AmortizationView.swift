import SwiftUI

// MARK: - Amortization Tab

struct AmortizationView: View {
    @ObservedObject var vm: MortgageViewModel
    @State private var expandedYears: Set<Int> = []

    var body: some View {
        NavigationStack {
            Group {
                if vm.schedule.isEmpty {
                    emptyState
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Amortization")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text("No Schedule Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Enter a home price and interest rate in the Calculator tab to see the full amortization schedule.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Schedule list

    private var scheduleList: some View {
        List {
            // Loan summary header
            Section {
                loanSummaryCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Year rows
            Section("Year-by-Year Breakdown") {
                ForEach(vm.schedule) { yr in
                    yearRow(yr)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loan summary card

    private var loanSummaryCard: some View {
        VStack(spacing: 0) {
            HStack {
                SummaryTile(label: "Loan Amount",    value: vm.loanAmount.currency)
                Divider().frame(height: 50)
                SummaryTile(label: "Monthly P&I",    value: vm.monthlyPI.currencyExact)
                Divider().frame(height: 50)
                SummaryTile(label: "Total Interest", value: vm.totalInterest.currency)
            }
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - Year row with expandable months

    @ViewBuilder
    private func yearRow(_ yr: AmortizationYear) -> some View {
        let isExpanded = expandedYears.contains(yr.year)
        let isARM      = vm.loanType.isARM
        let armYrs     = vm.loanType.armFixedYears ?? 0

        VStack(spacing: 0) {
            // Year summary header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedYears.remove(yr.year)
                    } else {
                        expandedYears.insert(yr.year)
                    }
                }
            } label: {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Year \(yr.year)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if isARM && yr.year == armYrs {
                                Text("Rate adjusts after this year")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Bal:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(yr.balance.currency)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        HStack(spacing: 8) {
                            AmountBadge(label: "P", value: yr.principal.currency, color: .blue)
                            AmountBadge(label: "I", value: yr.interest.currency,  color: .orange)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded monthly rows
            if isExpanded {
                Divider()
                    .padding(.leading, 18)

                ForEach(yr.months) { mo in
                    monthRow(mo)
                }
            }
        }
    }

    // MARK: - Month row

    private func monthRow(_ mo: AmortizationMonth) -> some View {
        HStack {
            Text("Month \(mo.month)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
                .padding(.leading, 18)

            Spacer()

            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Principal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mo.principal.currencyExact)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Interest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mo.interest.currencyExact)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mo.balance.currencyExact)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Supporting views

struct SummaryTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.footnote)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AmountBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    AmortizationView(vm: MortgageViewModel())
}
