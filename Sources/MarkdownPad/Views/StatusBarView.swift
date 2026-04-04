import SwiftUI

struct StatusBarView: View {
    var documentName: String?
    var line: Int
    var column: Int
    var wordCount: Int
    var encoding: String

    var body: some View {
        HStack {
            // Document name on the left
            if let name = documentName {
                Text(name)
                    .font(.system(size: Constants.StatusBar.fontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text("行 \(line), 列 \(column)")
                .font(.system(size: Constants.StatusBar.fontSize))
                .foregroundStyle(.secondary)

            Divider().frame(height: 12)

            Text("\(wordCount) 字")
                .font(.system(size: Constants.StatusBar.fontSize))
                .foregroundStyle(.secondary)

            Divider().frame(height: 12)

            Text(encoding)
                .font(.system(size: Constants.StatusBar.fontSize))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
