import SwiftUI

// MARK: - Calculator Tab

struct CalculatorView: View {
    @ObservedObject var vm: MortgageViewModel
    @FocusState private var activeField: Field?

    enum Field: Hashable {
        case homePrice, rate, additionalDown, taxRate, insurance
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Summary card ──────────────────────────────────────────
                Section {
                    SummaryCardView(vm: vm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // ── ARM notice ────────────────────────────────────────────
                if vm.loanType.isARM, let yrs = vm.loanType.armFixedYears {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("**\(yrs)/6 ARM:** Rate is fixed for \(yrs) years, then adjusts every 6 months based on a market index. Payments shown reflect the initial fixed-rate period only.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Property & Loan ───────────────────────────────────────
                Section("Property & Loan") {
                    InputRow(label: "Home Price", prefix: "$") {
                        TextField("1,500,000", text: $vm.homePriceText)
                            .keyboardType(.numberPad)
                            .focused($activeField, equals: .homePrice)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Loan Type", selection: $vm.loanType) {
                            ForEach(LoanType.allCases) { lt in
                                Text(lt.shortName).tag(lt)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    InputRow(label: "Interest Rate", suffix: "%") {
                        TextField("6.750", text: $vm.interestRateText)
                            .keyboardType(.decimalPad)
                            .focused($activeField, equals: .rate)
                    }
                }

                // ── Down Payment ──────────────────────────────────────────
                Section("Down Payment") {
                    // Base down (read-only, auto-calculated)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Base Down Payment")
                                .font(.subheadline)
                            Text(vm.homePrice > 0
                                 ? "\(Int(vm.defaultDownPercent * 100))% of \(vm.homePrice.currency)"
                                 : "Enter a home price above")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vm.defaultDownPercent == 0.30
                                 ? "Jumbo >$3M loan target"
                                 : "Conventional jumbo target")
                                .font(.caption2)
                                .foregroundStyle(vm.defaultDownPercent == 0.30 ? .blue : .green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(vm.baseDown.currency)
                                .fontWeight(.semibold)
                            Text("\(Int(vm.defaultDownPercent * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(vm.defaultDownPercent == 0.30
                                            ? Color.blue.opacity(0.12)
                                            : Color.green.opacity(0.12))
                                .foregroundStyle(vm.defaultDownPercent == 0.30 ? .blue : .green)
                                .clipShape(Capsule())
                        }
                    }

                    InputRow(label: "Additional Down Payment", prefix: "$") {
                        TextField("0", text: $vm.additionalDown)
                            .keyboardType(.numberPad)
                            .focused($activeField, equals: .additionalDown)
                    }

                    // Loan summary rows
                    SummaryRow(label: "Total Down (\(vm.homePrice > 0 ? (vm.totalDown / vm.homePrice * 100).pct1 : "—"))",
                               value: vm.totalDown.currency)
                    SummaryRow(label: "Loan Amount", value: vm.loanAmount.currency, accent: true)
                    SummaryRow(label: "LTV", value: (vm.ltv * 100).pct1)
                }

                // ── Taxes & Insurance ─────────────────────────────────────
                Section("Taxes & Insurance") {
                    VStack(alignment: .leading, spacing: 2) {
                        InputRow(label: "Property Tax Rate", suffix: "%/yr") {
                            TextField("1.17", text: $vm.taxRateText)
                                .keyboardType(.decimalPad)
                                .focused($activeField, equals: .taxRate)
                        }
                        Text("SF effective rate ~1.17% (Prop 13 base 1% + bonds/assessments)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        InputRow(label: "Home Insurance", prefix: "$", suffix: "/mo") {
                            TextField("\(Int(vm.defaultInsurance))", text: $vm.insuranceText)
                                .keyboardType(.numberPad)
                                .focused($activeField, equals: .insurance)
                        }
                        Text("Default: 0.5% of home value/yr (\(vm.defaultInsurance.currency)/mo)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("SF Mortgage")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { activeField = nil }
                }
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCardView: View {
    @ObservedObject var vm: MortgageViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Hero total
            VStack(spacing: 6) {
                Text("Monthly Payment (PITI)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(vm.totalMonthly.currencyExact)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(vm.loanType.isARM
                     ? "\(vm.loanType.armFixedYears!)-year fixed initial rate period"
                     : "30-year fixed rate")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.24, green: 0.36, blue: 0.90),
                             Color(red: 0.14, green: 0.22, blue: 0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Three-way breakdown
            VStack(spacing: 12) {
                // Proportional bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * vm.piProportion)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * vm.taxProportion)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: max(geo.size.width * vm.insProportion, 0))
                    }
                }
                .frame(height: 8)

                // Labels
                HStack {
                    BreakdownPill(color: .blue,   label: "P&I",       value: vm.monthlyPI.currencyExact)
                    Spacer()
                    BreakdownPill(color: .orange, label: "Tax",       value: vm.monthlyTax.currencyExact)
                    Spacer()
                    BreakdownPill(color: .green,  label: "Insurance", value: vm.insurance.currencyExact)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct BreakdownPill: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Reusable input row

struct InputRow<Content: View>: View {
    let label: String
    var prefix: String? = nil
    var suffix: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack(spacing: 2) {
                if let prefix {
                    Text(prefix)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                content
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                if let suffix {
                    Text(suffix)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Summary row

struct SummaryRow: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(accent ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(accent ? .bold : .regular)
                .foregroundStyle(accent ? Color.blue : .secondary)
        }
    }
}

#Preview {
    CalculatorView(vm: MortgageViewModel())
}
