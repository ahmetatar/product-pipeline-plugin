# Skeleton — SwiftUI tokens file

Path: `Sources/DesignSystem/Tokens.swift`

Two options for light/dark — pick one and document the choice in the spec's changelog.

## Option A (recommended) — Asset Catalog color sets

1. Create `DesignSystem.xcassets` with one color set per `color.*` token (`Primary`, `OnPrimary`, …).
2. Each color set has Light and Dark appearance variants with the hex values from the spec.

```swift
import SwiftUI

enum AppColor {
    static let primary = Color("Primary", bundle: .main)
    static let onPrimary = Color("OnPrimary", bundle: .main)
    static let background = Color("Background", bundle: .main)
    // ... one per spec token
}

enum AppFont {
    static let body = Font.system(size: 17, weight: .regular)
    static let title = Font.system(size: 22, weight: .semibold)
    static let caption = Font.system(size: 13, weight: .regular)
}

enum AppSpacing { static let xs: CGFloat = 4; static let sm: CGFloat = 8; static let md: CGFloat = 16; static let lg: CGFloat = 24 }
enum AppRadius  { static let sm: CGFloat = 8; static let md: CGFloat = 14; static let lg: CGFloat = 20; static let full: CGFloat = 999 }
```

## Option B — code-only via `@Environment(\.colorScheme)`

```swift
extension Color {
    static func token(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
enum AppColor {
    static let primary = Color.token(light: 0x2E5BFF, dark: 0x6B8EFF)
    // ...
}
```
