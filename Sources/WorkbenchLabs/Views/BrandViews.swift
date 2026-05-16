import AppKit
import SwiftUI

struct WorkbenchLabsLogoMark: View {
  var size: CGFloat = 32
  var prefersVectorMark = false
  var showsShadow = true

  var body: some View {
    if !prefersVectorMark, let image = Self.logoImage {
      Image(nsImage: image)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous))
        .shadow(color: .accentColor.opacity(showsShadow ? 0.14 : 0), radius: showsShadow ? size * 0.22 : 0, y: showsShadow ? size * 0.08 : 0)
    } else {
      fallbackMark
    }
  }

  private static var logoImage: NSImage? {
    let subdirectories = [
      "WorkbenchLabs_WorkbenchLabs.bundle/Resources/Assets",
      "../WorkbenchLabs_WorkbenchLabs.bundle/Resources/Assets",
      "Resources/Assets"
    ]
    for subdirectory in subdirectories {
      if let resourceURL = Bundle.main.url(
        forResource: "workbench-labs-logo",
        withExtension: "png",
        subdirectory: subdirectory
      ),
         let image = NSImage(contentsOf: resourceURL) {
        return image
      }
    }
    if let resourceURL = Bundle.main.url(forResource: "workbench-labs-logo", withExtension: "png"),
       let image = NSImage(contentsOf: resourceURL) {
      return image
    }
    if let moduleURL = Bundle.module.url(
      forResource: "workbench-labs-logo",
      withExtension: "png",
      subdirectory: "Resources/Assets"
    ),
       let image = NSImage(contentsOf: moduleURL) {
      return image
    }
    if let image = NSImage(named: "workbench-labs-logo") ?? NSImage(named: "WorkbenchLabs") {
      return image
    }
    return nil
  }

  private var fallbackMark: some View {
    ZStack {
      RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.36),
              Color.primary.opacity(0.10),
              Color.secondary.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous))
        }
        .overlay {
          RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous)
            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }

      WorkbenchLabsGlyph()
        .stroke(
          LinearGradient(
            colors: [.primary.opacity(0.95), .accentColor.opacity(0.86)],
            startPoint: .leading,
            endPoint: .trailing
          ),
          style: StrokeStyle(lineWidth: max(1.8, size * 0.075), lineCap: .round, lineJoin: .round)
        )
        .frame(width: size * 0.62, height: size * 0.48)
    }
    .frame(width: size, height: size)
    .shadow(color: .accentColor.opacity(showsShadow ? 0.12 : 0), radius: showsShadow ? size * 0.22 : 0, y: showsShadow ? size * 0.08 : 0)
  }
}

struct WorkbenchLabsWordmark: View {
  var compact = false

  var body: some View {
    HStack(spacing: 10) {
      WorkbenchLabsLogoMark(size: compact ? 24 : 34)

      VStack(alignment: .leading, spacing: compact ? 0 : 2) {
        Text("Workbench Labs")
          .font(compact ? .headline.weight(.semibold) : .title3.weight(.semibold))
          .lineLimit(1)

        if !compact {
          Text("Native local workbench")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
  }
}

struct SidebarBrandHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      WorkbenchLabsWordmark()

      HStack(spacing: 8) {
        WorkbenchStatusPill("Local", systemImage: "internaldrive")
        WorkbenchStatusPill("No cloud", systemImage: "lock.shield")
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 12)
  }
}

struct WorkbenchChromeTitle: View {
  var body: some View {
    HStack(spacing: 6) {
      WorkbenchLabsLogoMark(size: 18, prefersVectorMark: true, showsShadow: false)
      Text("Workbench Labs")
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
  }
}

struct WorkbenchStatusPill: View {
  let title: String
  let systemImage: String

  init(_ title: String, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(.secondary)
      .labelStyle(.titleAndIcon)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.quaternary.opacity(0.35), in: Capsule())
  }
}

struct ToolWorkspaceHeader<Trailing: View>: View {
  let title: String
  let subtitle: String
  let systemImage: String
  @ViewBuilder var trailing: Trailing

  init(
    title: String,
    subtitle: String,
    systemImage: String,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(.thinMaterial)
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
          }

        Image(systemName: systemImage)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.primary, .secondary)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.title2.weight(.semibold))
          .lineLimit(1)
        Text(subtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 16)
      trailing
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 13)
    .background {
      ZStack {
        Rectangle().fill(.bar)
        LinearGradient(
          colors: [
            Color.accentColor.opacity(0.09),
            Color.clear,
            Color.primary.opacity(0.025)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
  }
}

extension ToolWorkspaceHeader where Trailing == EmptyView {
  init(title: String, subtitle: String, systemImage: String) {
    self.init(title: title, subtitle: subtitle, systemImage: systemImage) {
      EmptyView()
    }
  }
}

struct WorkbenchPaneBackground: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background {
        ZStack {
          Rectangle().fill(.background)
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.045),
              Color.clear,
              Color.primary.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
      }
  }
}

extension View {
  func workbenchPaneBackground() -> some View {
    modifier(WorkbenchPaneBackground())
  }
}

private struct WorkbenchLabsGlyph: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let minX = rect.minX
    let maxX = rect.maxX
    let minY = rect.minY
    let maxY = rect.maxY
    let midY = rect.midY

    path.move(to: CGPoint(x: minX + rect.width * 0.30, y: minY))
    path.addLine(to: CGPoint(x: minX, y: midY))
    path.addLine(to: CGPoint(x: minX + rect.width * 0.30, y: maxY))

    path.move(to: CGPoint(x: maxX - rect.width * 0.30, y: minY))
    path.addLine(to: CGPoint(x: maxX, y: midY))
    path.addLine(to: CGPoint(x: maxX - rect.width * 0.30, y: maxY))

    path.move(to: CGPoint(x: rect.midX + rect.width * 0.12, y: minY - rect.height * 0.04))
    path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.12, y: maxY + rect.height * 0.04))

    return path
  }
}
