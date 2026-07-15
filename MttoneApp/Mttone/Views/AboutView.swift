import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 图标区域
            VStack(spacing: 16) {
                if let icon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 96, height: 96)
                }

                Text(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "AuraNote")
                    .font(.title)
                    .fontWeight(.bold)

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 40)

            // 功能描述
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("about_feature_desc"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                Text(loc("about_feature_desc_en"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            // 版权
            Text(loc("about_copyright"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 16)
        }
        .frame(width: 460, height: 440)
        .fixedSize()
    }
}

#Preview {
    AboutView()
}
