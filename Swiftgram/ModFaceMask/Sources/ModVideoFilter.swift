import Foundation
import CoreImage
import ModSettings

/// Color filters for video messages.
public enum ModVideoFilter: String, CaseIterable {
    case none
    case mono
    case noir
    case sepia
    case chrome
    case fade
    case instant
    case warm
    case cold
    case vhs
    case comic
    case thermal
    case xray
    case invert
    case pixel

    public static let settingsKey = "mod.video.filter"
    public static let mirrorKey = "mod.video.mirror"

    public static var current: ModVideoFilter {
        get { return ModVideoFilter(rawValue: UserDefaults.standard.string(forKey: self.settingsKey) ?? "") ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: self.settingsKey) }
    }

    public static var mirror: Bool {
        get { return UserDefaults.standard.bool(forKey: self.mirrorKey) }
        set { UserDefaults.standard.set(newValue, forKey: self.mirrorKey) }
    }

    public var title: String {
        switch self {
        case .none: return "Без фильтра"
        case .mono: return "Ч/Б"
        case .noir: return "Нуар"
        case .sepia: return "Сепия"
        case .chrome: return "Хром"
        case .fade: return "Выцветание"
        case .instant: return "Полароид"
        case .warm: return "Тёплый"
        case .cold: return "Холодный"
        case .vhs: return "VHS"
        case .comic: return "Комикс"
        case .thermal: return "Тепловизор"
        case .xray: return "Рентген"
        case .invert: return "Негатив"
        case .pixel: return "Пиксели"
        }
    }

    public func apply(to image: CIImage) -> CIImage {
        let extent = image.extent
        let result: CIImage
        switch self {
        case .none:
            return image
        case .mono:
            result = image.applyingFilter("CIPhotoEffectMono")
        case .noir:
            result = image.applyingFilter("CIPhotoEffectNoir")
        case .sepia:
            result = image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])
        case .chrome:
            result = image.applyingFilter("CIPhotoEffectChrome")
        case .fade:
            result = image.applyingFilter("CIPhotoEffectFade")
        case .instant:
            result = image.applyingFilter("CIPhotoEffectInstant")
        case .warm:
            result = image.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500.0, y: 0.0), "inputTargetNeutral": CIVector(x: 4500.0, y: 0.0)])
        case .cold:
            result = image.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500.0, y: 0.0), "inputTargetNeutral": CIVector(x: 9500.0, y: 0.0)])
        case .vhs:
            // Shifted red / blue channels + noise + a bit of blur and saturation.
            let base = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.3, kCIInputContrastKey: 1.1])
            let red = base.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
                "inputGVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
                "inputBVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
            ]).transformed(by: CGAffineTransform(translationX: 3.0, y: 0.0))
            let greenBlue = base.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
            ]).transformed(by: CGAffineTransform(translationX: -2.0, y: 0.0))
            let combined = red.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: greenBlue])
            let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
                    "inputGVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
                    "inputBVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
                    "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.08),
                    "inputBiasVector": CIVector(x: 1.0, y: 1.0, z: 1.0, w: 0.0)
                ])
                .transformed(by: CGAffineTransform(translationX: CGFloat.random(in: 0.0 ..< 100.0), y: CGFloat.random(in: 0.0 ..< 100.0)))
            var output = combined.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8])
            if let noise {
                output = noise.composited(over: output)
            }
            result = output
        case .comic:
            result = image.applyingFilter("CIComicEffect")
        case .thermal:
            result = image.applyingFilter("CIThermal")
        case .xray:
            result = image.applyingFilter("CIXRay")
        case .invert:
            result = image.applyingFilter("CIColorInvert")
        case .pixel:
            result = image.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(6.0, extent.width / 50.0), kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY)])
        }
        return result.cropped(to: extent)
    }
}

/// Everything the mod does with a video message frame: face mask, mirror, color filter.
public func modProcessRoundVideoFrame(_ image: CIImage) -> CIImage {
    var result = ModFaceMask.shared.apply(to: image)
    if ModVideoFilter.mirror {
        let extent = result.extent
        result = result.transformed(by: CGAffineTransform(scaleX: -1.0, y: 1.0).concatenating(CGAffineTransform(translationX: extent.minX * 2.0 + extent.width, y: 0.0)))
    }
    return ModVideoFilter.current.apply(to: result)
}
