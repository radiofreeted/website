import SwiftUI

struct ContentView: View {
    @StateObject private var vm = MortgageViewModel()

    var body: some View {
        TabView {
            CalculatorView(vm: vm)
                .tabItem {
                    Label("Calculator", systemImage: "house.fill")
                }
            AmortizationView(vm: vm)
                .tabItem {
                    Label("Schedule", systemImage: "list.number")
                }
        }
    }
}

#Preview {
    ContentView()
}
