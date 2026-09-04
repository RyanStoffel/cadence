import CadenceCore
import SwiftUI

struct ManualEntryView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var label = ""
  @State private var note = ""
  @State private var endedAt = Date()
  @State private var hours = 0
  @State private var minutes = 30

  private let minuteOptions = Array(stride(from: 0, through: 55, by: 5))

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Add time")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
          Text("Capture work that happened away from the timer.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 28))
          .foregroundStyle(CadencePalette.orange)
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("WORK LABEL")
          .fieldLabel()
        HStack {
          TextField("Client call, design review, writing...", text: $label)
            .textFieldStyle(.roundedBorder)
          if !model.recentLabels.isEmpty {
            Menu {
              ForEach(model.recentLabels.prefix(8), id: \.self) { value in
                Button(value) { label = value }
              }
            } label: {
              Image(systemName: "clock.arrow.circlepath")
            }
            .help("Use a recent label")
          }
        }
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("DETAIL")
          .fieldLabel()
        TextField("Optional one-line detail", text: $note)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("ENDED")
          .fieldLabel()
        DatePicker(
          "", selection: $endedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.field)
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("DURATION")
          .fieldLabel()
        HStack(spacing: 12) {
          Stepper(value: $hours, in: 0...12) {
            Text("\(hours) hr")
              .frame(width: 52, alignment: .leading)
          }
          Picker("Minutes", selection: $minutes) {
            ForEach(minuteOptions, id: \.self) { minute in
              Text("\(minute) min").tag(minute)
            }
          }
          .frame(width: 105)
        }
      }

      Spacer()

      HStack {
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Add to Log") {
          let duration = TimeInterval((hours * 60 + minutes) * 60)
          let startedAt = endedAt.addingTimeInterval(-duration)
          if model.addManualSession(
            label: label, note: note, startedAt: startedAt, duration: duration)
          {
            dismiss()
          }
        }
        .buttonStyle(CadencePrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(
          label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (hours == 0 && minutes == 0))
      }
    }
    .padding(24)
    .frame(width: 470, height: 450)
  }
}

struct WorkLogView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  private var filteredSessions: [WorkSession] {
    guard !search.isEmpty else { return model.recentSessions }
    return model.recentSessions.filter {
      $0.label.localizedCaseInsensitiveContains(search)
        || $0.note.localizedCaseInsensitiveContains(search)
    }
  }

  private var totalSeconds: TimeInterval {
    model.sessions.reduce(0) { $0 + $1.duration }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Work log")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
          Text("\(model.sessions.count) sessions · \(model.durationText(totalSeconds)) total")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        HStack(spacing: 7) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.tertiary)
          TextField("Search labels and details", text: $search)
            .textFieldStyle(.plain)
            .frame(width: 185)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
          Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        Button("Export CSV") { model.exportCSV() }
          .buttonStyle(.bordered)
        Button("Done") { dismiss() }
          .buttonStyle(.borderedProminent)
          .tint(CadencePalette.orange)
          .keyboardShortcut(.defaultAction)
      }
      .padding(20)

      Divider()

      if filteredSessions.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: search.isEmpty ? "tray" : "magnifyingglass")
            .font(.system(size: 28, weight: .light))
            .foregroundStyle(.tertiary)
          Text(search.isEmpty ? "No sessions logged yet" : "No matching sessions")
            .font(.headline)
          Text(
            search.isEmpty
              ? "Completed focus blocks and manual entries will collect here."
              : "Try a different label or detail."
          )
          .font(.callout)
          .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(filteredSessions) { session in
              SessionRow(session: session)
                .padding(.horizontal, 20)
              Divider().padding(.leading, 68)
            }
          }
          .padding(.vertical, 6)
        }
      }
    }
    .frame(width: 760, height: 580)
  }
}

extension Text {
  fileprivate func fieldLabel() -> some View {
    font(.system(size: 10, weight: .bold))
      .tracking(1.0)
      .foregroundStyle(.secondary)
  }
}
