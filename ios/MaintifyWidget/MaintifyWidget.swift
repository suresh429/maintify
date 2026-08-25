import WidgetKit
import SwiftUI

// MARK: - App Group
// Derives the shared App Group ID from this extension's bundle ID.
// Handles both flavors automatically:
//   com.maintify.app.MaintifyWidget     → group.com.maintify.app
//   com.maintify.app.dev.MaintifyWidget → group.com.maintify.app.dev
private var sharedAppGroupId: String {
    let ext = Bundle.main.bundleIdentifier ?? "com.maintify.app.MaintifyWidget"
    let suffix = ".MaintifyWidget"
    let mainId = ext.hasSuffix(suffix)
        ? String(ext.dropLast(suffix.count))
        : "com.maintify.app"
    return "group.\(mainId)"
}

private let widgetDataKey = "widgetData"

// MARK: - Data Model

struct MaintifyWidgetData: Codable {
    let isLoggedIn: Bool
    let apartmentName: String
    let residentName: String
    let userRole: String
    let pendingBillCount: Int
    let pendingAmount: String
    let lastUpdated: String

    static let loggedOut = MaintifyWidgetData(
        isLoggedIn: false, apartmentName: "", residentName: "",
        userRole: "", pendingBillCount: 0, pendingAmount: "", lastUpdated: ""
    )

    static let placeholder = MaintifyWidgetData(
        isLoggedIn: true,
        apartmentName: "Green Valley Residency",
        residentName: "Srikanth",
        userRole: "resident",
        pendingBillCount: 2,
        pendingAmount: "₹2,400",
        lastUpdated: ""
    )
}

// MARK: - Provider

struct MaintifyProvider: TimelineProvider {

    func placeholder(in context: Context) -> MaintifyEntry {
        MaintifyEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MaintifyEntry) -> Void) {
        completion(MaintifyEntry(date: Date(), data: context.isPreview ? .placeholder : loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MaintifyEntry>) -> Void) {
        let entry = MaintifyEntry(date: Date(), data: loadData())
        // Passive refresh every 30 minutes; the Flutter app triggers reloads on data changes.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadData() -> MaintifyWidgetData {
        guard
            let defaults = UserDefaults(suiteName: sharedAppGroupId),
            let json = defaults.string(forKey: widgetDataKey),
            let data = json.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(MaintifyWidgetData.self, from: data)
        else { return .loggedOut }
        return decoded
    }
}

// MARK: - Entry

struct MaintifyEntry: TimelineEntry {
    let date: Date
    let data: MaintifyWidgetData
}

// MARK: - Brand Colours

extension Color {
    /// Brand gold  #C39A51
    static let maintifyGold = Color(red: 0.765, green: 0.604, blue: 0.318)
    /// Dark navy   #0F172A
    static let maintifyDark = Color(red: 0.059, green: 0.090, blue: 0.165)
    /// Dark surface #1E293B
    static let maintifyDarkSurface = Color(red: 0.118, green: 0.161, blue: 0.231)
    /// Paid green  #22C55E
    static let maintifyGreen = Color(red: 0.133, green: 0.773, blue: 0.369)
    /// Pending red #EF4444
    static let maintifyRed = Color(red: 0.937, green: 0.267, blue: 0.267)
    /// Secondary text #64748B
    static let maintifySecondary = Color(red: 0.392, green: 0.455, blue: 0.545)
}

// MARK: - Logo Mark

private struct MLogoMark: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color.maintifyGold)
                .frame(width: size, height: size)
            Text("M")
                .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Widget Header

private struct WidgetHeader: View {
    var logoSize: CGFloat = 20
    var fontSize: CGFloat = 11
    var body: some View {
        HStack(spacing: 5) {
            MLogoMark(size: logoSize)
            Text("Maintify")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.maintifyGold)
            Spacer()
        }
    }
}

// MARK: - Bill Status

private struct BillStatusPill: View {
    let count: Int
    let role: String
    let amount: String

    private var isPending: Bool { count > 0 }
    private var label: String {
        if !isPending { return "All Paid" }
        return role == "president"
            ? (count == 1 ? "1 Flat Pending" : "\(count) Flats Pending")
            : (count == 1 ? "1 Bill Due" : "\(count) Bills Due")
    }
    private var dotColor: Color { isPending ? .maintifyRed : .maintifyGreen }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(dotColor).frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(dotColor)
            }
            if isPending && !amount.isEmpty {
                Text(amount)
                    .font(.system(size: 10))
                    .foregroundColor(dotColor.opacity(0.85))
            }
        }
    }
}

// MARK: - Small Widget

private struct SmallView: View {
    let data: MaintifyWidgetData
    @Environment(\.colorScheme) var scheme

    private var bg: Color { scheme == .dark ? .maintifyDark : .white }
    private var titleColor: Color {
        scheme == .dark ? Color(red: 0.945, green: 0.961, blue: 0.976) : .maintifyDark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader()
            Spacer()
            if data.isLoggedIn {
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.apartmentName.isEmpty ? "Your Apartment" : data.apartmentName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(titleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    BillStatusPill(count: data.pendingBillCount, role: data.userRole, amount: data.pendingAmount)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open Maintify")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.maintifyGold)
                    Text("to manage your\napartment")
                        .font(.system(size: 11))
                        .foregroundColor(.maintifySecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(bg)
    }
}

// MARK: - Medium Widget

private struct MediumView: View {
    let data: MaintifyWidgetData
    @Environment(\.colorScheme) var scheme

    private var bg: Color { scheme == .dark ? .maintifyDark : .white }
    private var dividerColor: Color { scheme == .dark ? .maintifyDarkSurface : Color.gray.opacity(0.2) }
    private var titleColor: Color {
        scheme == .dark ? Color(red: 0.945, green: 0.961, blue: 0.976) : .maintifyDark
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left column
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(logoSize: 22, fontSize: 13)
                Spacer()
                if data.isLoggedIn {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.apartmentName.isEmpty ? "Your Apartment" : data.apartmentName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(titleColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if !data.residentName.isEmpty {
                            Text(data.residentName)
                                .font(.system(size: 11))
                                .foregroundColor(.maintifySecondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sign in to Maintify")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(titleColor)
                            .lineLimit(2)
                        Text("View your apartment\nbills and updates")
                            .font(.system(size: 11))
                            .foregroundColor(.maintifySecondary)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if data.isLoggedIn {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: 1)
                    .padding(.vertical, 4)

                // Right column — bill summary
                VStack(alignment: .leading, spacing: 0) {
                    Text("BILLS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.maintifySecondary)
                        .kerning(0.5)
                    Spacer()
                    if data.pendingBillCount > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(data.pendingBillCount)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.maintifyRed)
                            Text(data.userRole == "president"
                                 ? (data.pendingBillCount == 1 ? "flat pending" : "flats pending")
                                 : (data.pendingBillCount == 1 ? "bill pending" : "bills pending"))
                                .font(.system(size: 10))
                                .foregroundColor(.maintifySecondary)
                            if !data.pendingAmount.isEmpty {
                                Text(data.pendingAmount)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.maintifyRed)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.maintifyGreen)
                            Text("All paid")
                                .font(.system(size: 10))
                                .foregroundColor(.maintifySecondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: 90, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(bg)
    }
}

// MARK: - Entry View

struct MaintifyWidgetEntryView: View {
    let entry: MaintifyEntry
    @Environment(\.widgetFamily) var family

    private var deepLink: URL {
        let path = (entry.data.isLoggedIn && entry.data.pendingBillCount > 0)
            ? "maintify://bills"
            : "maintify://home"
        return URL(string: path) ?? URL(string: "maintify://home")!
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumView(data: entry.data)
            default:
                SmallView(data: entry.data)
            }
        }
        .widgetURL(deepLink)
    }
}

// MARK: - Widget
// Note: @main is in MaintifyWidgetBundle.swift — do not add it here.

struct MaintifyWidget: Widget {
    let kind = "MaintifyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaintifyProvider()) { entry in
            if #available(iOS 17.0, *) {
                MaintifyWidgetEntryView(entry: entry)
                    .containerBackground(.background, for: .widget)
            } else {
                MaintifyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Maintify")
        .description("See your apartment status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
// Uses PreviewProvider (not #Preview macro) so it coexists with @main in MaintifyWidgetBundle.

struct MaintifyWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MaintifyWidgetEntryView(entry: MaintifyEntry(date: .now, data: .placeholder))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small – Logged In")
            MaintifyWidgetEntryView(entry: MaintifyEntry(date: .now, data: .loggedOut))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small – Logged Out")
            MaintifyWidgetEntryView(entry: MaintifyEntry(date: .now, data: .placeholder))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – Logged In")
            MaintifyWidgetEntryView(entry: MaintifyEntry(date: .now, data: .loggedOut))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – Logged Out")
        }
    }
}
