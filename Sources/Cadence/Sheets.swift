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
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Add time")
          .font(.system(size: 17, weight: .semibold))
        Text("Capture work that happened away from the timer.")
          .font(CadenceType.body)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 6) {
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
            .frame(width: 44)
            .help("Use a recent label")
          }
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("DETAIL")
          .fieldLabel()
        TextField("Optional one-line detail", text: $note)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("ENDED")
          .fieldLabel()
        DatePicker(
          "", selection: $endedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.field)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("DURATION")
          .fieldLabel()
        HStack(spacing: 12) {
          Stepper(value: $hours, in: 0...12) {
            Text("\(hours) hr")
              .frame(width: 48, alignment: .leading)
          }
          Picker("Minutes", selection: $minutes) {
            ForEach(minuteOptions, id: \.self) { minute in
              Text("\(minute) min").tag(minute)
            }
          }
          .labelsHidden()
          .frame(width: 100)
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
    .padding(20)
    .frame(width: 440, height: 420)
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
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Work log")
            .font(.system(size: 17, weight: .semibold))
          Text("\(model.sessions.count) sessions · \(model.durationText(totalSeconds)) total")
            .font(CadenceType.body)
            .foregroundStyle(.secondary)
        }
        Spacer()
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.tertiary)
          TextField("Search labels and details", text: $search)
            .textFieldStyle(.plain)
            .font(CadenceType.body)
            .frame(width: 170)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .cadenceFieldChrome()
        Button("Export CSV") { model.exportCSV() }
          .buttonStyle(.bordered)
        Button("Done") { dismiss() }
          .buttonStyle(CadencePrimaryButtonStyle())
          .keyboardShortcut(.defaultAction)
      }
      .padding(16)

      Divider()

      if filteredSessions.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: search.isEmpty ? "tray" : "magnifyingglass")
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.tertiary)
          Text(search.isEmpty ? "No sessions logged yet" : "No matching sessions")
            .font(CadenceType.emphasis)
          Text(
            search.isEmpty
              ? "Completed focus blocks and manual entries will collect here."
              : "Try a different label or detail."
          )
          .font(CadenceType.body)
          .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(filteredSessions) { session in
              SessionRow(session: session)
                .padding(.horizontal, 16)
              Divider().padding(.leading, 42)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .frame(width: 720, height: 540)
  }
}

extension Text {
  fileprivate func fieldLabel() -> some View {
    font(CadenceType.eyebrow)
      .tracking(CadenceType.eyebrowTracking)
      .foregroundStyle(.secondary)
  }
}
