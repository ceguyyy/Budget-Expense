
//
//  DashboardView.swift
//  Budget Expense
//

import SwiftUI
import Charts

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        netWorthCard
                        metricsGrid
                        if store.monthlyChartData.contains(where: { $0.outflow > 0 || $0.inflow > 0 }) {
                            cashflowChartCard
                        }
                        if !store.creditCards.isEmpty { ccSummaryCard }
                        if store.activeDebtCount > 0 { piutangCard }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Overview")
        }
    }

    // MARK: Net Worth Hero

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Net Worth IDR", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.glassText)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption2)
                    .foregroundStyle(.dimText)
            }

            Text(formatIDR(store.netWorthIDR))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(store.netWorthIDR >= 0 ? .neonGreen : .neonRed)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            Divider().background(Color(white: 0.15))

            HStack(spacing: 0) {
                breakdownPill("Wallets", formatIDR(max(0, store.totalDebitIDR)), .neonGreen)
                breakdownPill("Piutang", formatIDR(store.totalReceivablesIDR), Color(red: 0.3, green: 0.6, blue: 1))
                breakdownPill("CC Debt", "−" + formatIDR(store.totalOutstandingCC), .neonRed)
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 22))
    }

    // MARK: Metrics Grid (2×2)

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(
                icon: "calendar.badge.exclamationmark",
                title: "Tagihan Bulan Ini",
                value: formatIDR(store.totalMonthlyPayable),
                color: .neonRed
            )
            MetricTile(
                icon: "clock.badge.fill",
                title: "Cicilan/Bulan",
                value: formatIDR(store.totalMonthlyInstallments),
                color: Color(red: 0.92, green: 0.66, blue: 0.10)
            )
            MetricTile(
                icon: "person.2.fill",
                title: "Piutang Aktif",
                value: formatIDR(store.totalReceivablesIDR),
                color: Color(red: 0.3, green: 0.6, blue: 1.0)
            )
            MetricTile(
                icon: "drop.fill",
                title: "Likuiditas",
                value: formatIDR(store.liquidityIDR),
                color: store.liquidityIDR >= 0 ? .neonGreen : .neonRed
            )
        }
    }

    // MARK: Cashflow Chart

    private var cashflowChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CASHFLOW 6 BULAN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.glassText)
                    .kerning(1.0)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(.neonGreen, "Masuk")
                    legendDot(.neonRed,   "Keluar")
                }
            }

            Chart(store.monthlyChartData) { item in
                BarMark(x: .value("Bulan", item.month), y: .value("Keluar", item.outflow))
                    .foregroundStyle(Color.neonRed.opacity(0.75).gradient)
                    .cornerRadius(5)
                BarMark(x: .value("Bulan", item.month), y: .value("Masuk", item.inflow))
                    .foregroundStyle(Color.neonGreen.opacity(0.65).gradient)
                    .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color(white: 0.45)).font(.caption2)
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 130)
        }
        .padding(18)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: CC Summary

    private var ccSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("KARTU KREDIT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.glassText)
                .kerning(1.0)

            ForEach(store.creditCards) { card in
                CCDashboardRow(card: card, store: store)
            }
        }
        .padding(18)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: Piutang Summary

    private var piutangCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "person.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Piutang Aktif")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(store.activeDebtCount) orang · \(formatIDR(store.totalReceivablesIDR))")
                    .font(.caption).foregroundStyle(.glassText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.dimText)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 18))
    }

    // MARK: Helpers

    private func breakdownPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.dimText)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.glassText)
        }
    }
}

// MARK: - CC Dashboard Row

struct CCDashboardRow: View {
    let card: CreditCard
    let store: AppStore

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(card.cardColor.opacity(0.2)).frame(width: 36, height: 36)
                    Text(card.initials).font(.caption.bold()).foregroundStyle(card.cardColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(card.bank).font(.caption2).foregroundStyle(.glassText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tagihan: \(formatIDR(store.totalDueThisMonth(for: card)))")
                        .font(.caption.bold()).foregroundStyle(.neonRed)
                    Text("Sisa: \(formatIDR(card.remainingLimit))")
                        .font(.caption2).foregroundStyle(.glassText)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.12)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(card.usedPercent > 0.8 ? Color.neonRed : card.cardColor)
                        .frame(width: geo.size.width * card.usedPercent, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Metric Tile

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(title)
                .font(.caption2).foregroundStyle(.dimText).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
