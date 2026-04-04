import SwiftUI

struct StatusBarView: View {
    var line: Int
    var column: Int
    var wordCount: Int
    var encoding: String

    var body: some View {
        HStack {
            Spacer()
            Text("行 \(line), 列 \(column)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider().frame(height: 12)

            Text("\(wordCount) 字")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider().frame(height: 12)

            Text(encoding)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
