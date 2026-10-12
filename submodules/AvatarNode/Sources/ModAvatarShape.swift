import Foundation
import UIKit
import ModSettings

// MARK: Mod - square avatars

/// Round avatars become rounded rects when square avatars are enabled.
func modEffectiveClipStyle(_ clipStyle: AvatarNodeClipStyle) -> AvatarNodeClipStyle {
    if ModSettings.squareAvatars, case .round = clipStyle {
        return .roundedRect
    }
    return clipStyle
}

/// Corner radius for `.roundedRect` avatars (forums by default).
public func modAvatarRoundedRectRadius(_ width: CGFloat) -> CGFloat {
    if ModSettings.squareAvatars {
        return floor(width * CGFloat(max(0.0, min(0.5, ModSettings.avatarCornerRatio))))
    }
    return floor(width * 0.25)
}

/// Corner radius for an avatar that would otherwise be a circle of the given width.
public func modAvatarCircleRadius(_ width: CGFloat) -> CGFloat {
    if ModSettings.squareAvatars {
        return modAvatarRoundedRectRadius(width)
    }
    return width * 0.5
}

/// Adds the avatar outline (circle or rounded square) to the context path.
func modAddAvatarPath(context: CGContext, rect: CGRect) {
    if ModSettings.squareAvatars {
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: modAvatarRoundedRectRadius(rect.width)).cgPath)
    } else {
        context.addEllipse(in: rect)
    }
}
