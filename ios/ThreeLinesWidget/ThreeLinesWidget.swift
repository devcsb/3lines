import SwiftUI
import WidgetKit

private let appGroupId = "group.com.threelines.threeLines"

struct ThreeLinesEntry: TimelineEntry {
  let date: Date
  let streakLabel: String
  let statusMessage: String
  let prompt: String
  let isCompleted: Bool
  let emotionLabel: String?
  let family: WidgetFamily
}

struct ThreeLinesProvider: TimelineProvider {
  func placeholder(in context: Context) -> ThreeLinesEntry {
    ThreeLinesEntry(
      date: Date(),
      streakLabel: "3일",
      statusMessage: "오늘 아직이에요 · 스트릭 유지 중",
      prompt: "오늘 감사한 작은 것 하나는?",
      isCompleted: false,
      emotionLabel: nil,
      family: context.family
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (ThreeLinesEntry) -> Void) {
    completion(loadEntry(family: context.family))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ThreeLinesEntry>) -> Void) {
    let entry = loadEntry(family: context.family)
    // Refresh around next local midnight so day rollover updates without app open.
    let calendar = Calendar.current
    let nextMidnight =
      calendar.nextDate(
        after: Date(),
        matching: DateComponents(hour: 0, minute: 0, second: 5),
        matchingPolicy: .nextTime
      ) ?? Date().addingTimeInterval(3600)
    completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
  }

  private func loadEntry(family: WidgetFamily) -> ThreeLinesEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let streakLabel = defaults?.string(forKey: "streak_label") ?? "시작해볼까요"
    let status = defaults?.string(forKey: "status_message") ?? "앱을 열어 오늘을 기록해보세요"
    let prompt = defaults?.string(forKey: "prompt") ?? "오늘 감사한 작은 것 하나는?"
    let isCompleted = (defaults?.string(forKey: "is_completed") ?? "false") == "true"
    let emotionRaw = defaults?.string(forKey: "emotion") ?? ""
    let emotionLabel = Self.label(for: emotionRaw)

    return ThreeLinesEntry(
      date: Date(),
      streakLabel: streakLabel,
      statusMessage: status,
      prompt: prompt,
      isCompleted: isCompleted,
      emotionLabel: emotionLabel,
      family: family
    )
  }

  private static func label(for emotion: String) -> String? {
    switch emotion {
    case "1": return "힘듦"
    case "2": return "불안"
    case "3": return "보통"
    case "4": return "평온"
    case "5": return "감사"
    default: return nil
    }
  }
}

struct ThreeLinesWidgetEntryView: View {
  var entry: ThreeLinesEntry

  private let sage = Color(red: 0.357, green: 0.431, blue: 0.365)
  private let ink = Color(red: 0.110, green: 0.106, blue: 0.102)
  private let muted = Color(red: 0.361, green: 0.353, blue: 0.341)
  private let chipFill = Color(red: 0.910, green: 0.941, blue: 0.914)

  var body: some View {
    switch entry.family {
    case .systemMedium:
      mediumBody
    default:
      smallBody
    }
  }

  private var smallBody: some View {
    Link(destination: URL(string: "threelines://today")!) {
      VStack(alignment: .leading, spacing: 6) {
        Text("3Lines")
          .font(.caption.weight(.semibold))
          .foregroundStyle(sage)
        Text(entry.streakLabel)
          .font(.title2.weight(.bold))
          .foregroundStyle(ink)
        Text(entry.statusMessage)
          .font(.caption2)
          .foregroundStyle(muted)
          .lineLimit(2)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var mediumBody: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("3Lines")
          .font(.caption.weight(.semibold))
          .foregroundStyle(sage)
        Spacer()
        Text(entry.streakLabel)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(ink)
      }

      Text(entry.statusMessage)
        .font(.caption2)
        .foregroundStyle(muted)
        .lineLimit(1)

      Link(destination: URL(string: "threelines://today")!) {
        Text(entry.prompt)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(ink)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      if entry.isCompleted {
        Text(completedHint)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.357, green: 0.541, blue: 0.416))
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        HStack(spacing: 4) {
          emotionChip(1, "힘듦")
          emotionChip(2, "불안")
          emotionChip(3, "보통")
          emotionChip(4, "평온")
          emotionChip(5, "감사")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var completedHint: String {
    if let emotionLabel = entry.emotionLabel {
      return "기록 완료 · \(emotionLabel)"
    }
    return "오늘 기록 완료"
  }

  private func emotionChip(_ value: Int, _ title: String) -> some View {
    Link(destination: URL(string: "threelines://today?emotion=\(value)")!) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 0.239, green: 0.310, blue: 0.247))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(chipFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }
}

struct ThreeLinesWidget: Widget {
  let kind: String = "ThreeLinesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ThreeLinesProvider()) { entry in
      ThreeLinesWidgetEntryView(entry: entry)
        .widgetBackground(
          Color(red: 0.969, green: 0.961, blue: 0.941)
        )
    }
    .configurationDisplayName("3Lines")
    .description("오늘 질문, 스트릭, 빠른 감정 선택")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private extension View {
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      background(color)
    }
  }
}
