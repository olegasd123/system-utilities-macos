import SwiftUI

struct ThresholdRowView: View {
    let label: String
    @Binding var enabled: Bool
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Toggle(label, isOn: $enabled)

            Spacer()

            TextField("", value: $value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .monospacedDigit()
                .frame(width: 62)
                .disabled(!enabled)
                .onChange(of: value) { _, newValue in
                    value = min(max(newValue, range.lowerBound), range.upperBound)
                }

            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}
