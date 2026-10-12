import Foundation
import UIKit
import CoreImage
import Vision
import ModSettings

public enum ModFaceMaskMode: String, CaseIterable {
    case photo
    case blur
    case pixelate

    public var title: String {
        switch self {
        case .photo: return "Своё фото"
        case .blur: return "Размытие"
        case .pixelate: return "Пиксели"
        }
    }

    public static var current: ModFaceMaskMode {
        return ModFaceMaskMode(rawValue: ModSettings.maskMode) ?? .photo
    }
}

/// Hides the face in video messages: finds it with Vision on every frame and covers it
/// with the user's photo, a blur or pixelation.
public final class ModFaceMask {
    public static let shared = ModFaceMask()

    /// Where the mask currently is, in normalized coordinates of the output frame
    /// (origin at the bottom left, like Vision / Core Image). Read by the preview overlay.
    public struct Placement {
        public var rect: CGRect
        public var roll: CGFloat
        public var coversWholeFrame: Bool
    }

    private let lock = NSLock()
    private var currentPlacement: Placement?
    private var placementTimestamp: Double = 0.0

    private var smoothedRect: CGRect?
    private var smoothedRoll: CGFloat = 0.0
    private var lastFaceTimestamp: Double = 0.0
    private var frameIndex: Int = 0

    private var loadedImageVersion: Int = -1
    private var loadedCircle: Bool?
    private var maskImage: CIImage?
    private var maskUIImage: UIImage?

    private init() {
    }

    // MARK: Storage of the photo

    private static var imageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ModMask", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("mask.png")
    }

    /// Saves the photo (cropped to a square 512x512) as the mask.
    public static func saveMaskPhoto(_ image: UIImage) {
        let side: CGFloat = 512.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let normalized = renderer.image { _ in
            let scale = max(side / image.size.width, side / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (side - size.width) / 2.0, y: (side - size.height) / 2.0, width: size.width, height: size.height))
        }
        if let data = normalized.pngData() {
            try? data.write(to: self.imageURL, options: .atomic)
            ModSettings.maskImageVersion += 1
        }
    }

    public static func storedMaskPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: self.imageURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    public static var isActive: Bool {
        if !ModSettings.maskEnabled {
            return false
        }
        if ModFaceMaskMode.current == .photo {
            return FileManager.default.fileExists(atPath: self.imageURL.path)
        }
        return true
    }

    /// The mask photo with the configured shape, for the preview overlay.
    public func previewImage() -> UIImage? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        self.reloadImageIfNeeded()
        return self.maskUIImage
    }

    private func reloadImageIfNeeded() {
        let version = ModSettings.maskImageVersion
        let circle = ModSettings.maskCircle
        if version == self.loadedImageVersion && circle == self.loadedCircle {
            return
        }
        self.loadedImageVersion = version
        self.loadedCircle = circle
        self.maskImage = nil
        self.maskUIImage = nil
        guard let source = ModFaceMask.storedMaskPhoto() else {
            return
        }
        let shaped: UIImage
        if circle {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = false
            let rect = CGRect(origin: .zero, size: source.size)
            shaped = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
                UIBezierPath(ovalIn: rect).addClip()
                source.draw(in: rect)
            }
        } else {
            shaped = source
        }
        self.maskUIImage = shaped
        if let cgImage = shaped.cgImage {
            self.maskImage = CIImage(cgImage: cgImage)
        }
    }

    public func latestPlacement() -> Placement? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if CACurrentMediaTime() - self.placementTimestamp > 0.5 {
            return nil
        }
        return self.currentPlacement
    }

    // MARK: Frame processing

    /// Applies the mask to a square video message frame. Returns the image unchanged when the mask is off.
    public func apply(to image: CIImage) -> CIImage {
        if !ModFaceMask.isActive {
            return image
        }
        let extent = image.extent
        if extent.isEmpty || extent.isInfinite {
            return image
        }
        let now = CACurrentMediaTime()
        let mode = ModFaceMaskMode.current

        self.frameIndex += 1
        if self.frameIndex % 2 == 0 || self.smoothedRect == nil {
            self.detectFace(in: image, now: now)
        }

        var placement: Placement?
        if let rect = self.smoothedRect, now - self.lastFaceTimestamp < 0.6 {
            placement = Placement(rect: rect, roll: ModSettings.maskFollowRotation ? self.smoothedRoll : 0.0, coversWholeFrame: false)
        } else if ModSettings.maskCoverWhenLost {
            placement = Placement(rect: CGRect(x: -0.1, y: -0.1, width: 1.2, height: 1.2), roll: 0.0, coversWholeFrame: true)
        }

        self.lock.lock()
        self.currentPlacement = placement
        self.placementTimestamp = now
        self.reloadImageIfNeeded()
        let maskImage = self.maskImage
        self.lock.unlock()

        guard let placement else {
            return image
        }
        let rect = CGRect(
            x: extent.minX + placement.rect.minX * extent.width,
            y: extent.minY + placement.rect.minY * extent.height,
            width: placement.rect.width * extent.width,
            height: placement.rect.height * extent.height
        )

        switch mode {
        case .photo:
            guard let maskImage else {
                return image
            }
            let side = max(rect.width, rect.height)
            let scale = side / max(1.0, maskImage.extent.width)
            var transform = CGAffineTransform(translationX: -maskImage.extent.midX, y: -maskImage.extent.midY)
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            if placement.roll != 0.0 {
                transform = transform.concatenating(CGAffineTransform(rotationAngle: placement.roll))
            }
            transform = transform.concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))
            let overlay = maskImage.transformed(by: transform)
            if placement.coversWholeFrame {
                let background = CIImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.0)).cropped(to: extent)
                return overlay.composited(over: background).cropped(to: extent)
            }
            return overlay.composited(over: image).cropped(to: extent)
        case .blur, .pixelate:
            let effect: CIImage
            if mode == .blur {
                effect = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(12.0, rect.width / 6.0)]).cropped(to: extent)
            } else {
                effect = image.applyingFilter("CIPixellate", parameters: [
                    kCIInputScaleKey: max(10.0, rect.width / 7.0),
                    kCIInputCenterKey: CIVector(x: rect.midX, y: rect.midY)
                ]).cropped(to: extent)
            }
            if placement.coversWholeFrame {
                return effect
            }
            let radius = max(rect.width, rect.height) / 2.0
            let gradient = CIImage.empty().applyingFilter("CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: rect.midX, y: rect.midY),
                "inputRadius0": radius * 0.92,
                "inputRadius1": radius,
                "inputColor0": CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
                "inputColor1": CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            ]).cropped(to: extent)
            return effect.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: gradient
            ]).cropped(to: extent)
        }
    }

    private func detectFace(in image: CIImage, now: Double) {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }
        guard let results = request.results, !results.isEmpty else {
            return
        }
        let face = results.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
        let box = face.boundingBox
        let scale = CGFloat(max(1.0, min(2.5, ModSettings.maskScale)))
        let side = max(box.width, box.height) * scale
        // The face box ends at the eyebrows; move the mask up a bit to cover the forehead.
        let center = CGPoint(x: box.midX, y: box.midY + box.height * 0.08)
        let target = CGRect(x: center.x - side / 2.0, y: center.y - side / 2.0, width: side, height: side)
        let roll = CGFloat(face.roll?.doubleValue ?? 0.0)

        if let previous = self.smoothedRect, now - self.lastFaceTimestamp < 0.6 {
            let k: CGFloat = 0.55
            self.smoothedRect = CGRect(
                x: previous.minX + (target.minX - previous.minX) * k,
                y: previous.minY + (target.minY - previous.minY) * k,
                width: previous.width + (target.width - previous.width) * k,
                height: previous.height + (target.height - previous.height) * k
            )
            self.smoothedRoll += (roll - self.smoothedRoll) * k
        } else {
            self.smoothedRect = target
            self.smoothedRoll = roll
        }
        self.lastFaceTimestamp = now
    }
}

/// Overlay for the live camera preview: shows the mask where it will be in the recorded video.
public final class ModFaceMaskPreviewView: UIView {
    private final class DisplayLinkTarget {
        weak var view: ModFaceMaskPreviewView?

        init(view: ModFaceMaskPreviewView) {
            self.view = view
        }

        @objc func tick() {
            self.view?.update()
        }
    }

    private let imageView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private var displayLink: CADisplayLink?

    /// Returns whether the preview layer below is mirrored (front camera).
    public var isMirrored: () -> Bool = { false }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFill
        self.blurView.clipsToBounds = true
        self.addSubview(self.blurView)
        self.addSubview(self.imageView)
        self.imageView.isHidden = true
        self.blurView.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            if self.displayLink == nil {
                let displayLink = CADisplayLink(target: DisplayLinkTarget(view: self), selector: #selector(DisplayLinkTarget.tick))
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            }
        } else {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }

    fileprivate func update() {
        guard ModFaceMask.isActive, let placement = ModFaceMask.shared.latestPlacement() else {
            self.imageView.isHidden = true
            self.blurView.isHidden = true
            return
        }
        let bounds = self.bounds
        var rect = CGRect(
            x: placement.rect.minX * bounds.width,
            y: (1.0 - placement.rect.maxY) * bounds.height,
            width: placement.rect.width * bounds.width,
            height: placement.rect.height * bounds.height
        )
        var roll = placement.roll
        if self.isMirrored() {
            rect.origin.x = bounds.width - rect.maxX
            roll = -roll
        }
        let targetView: UIView
        if ModFaceMaskMode.current == .photo {
            self.imageView.image = ModFaceMask.shared.previewImage()
            self.imageView.backgroundColor = placement.coversWholeFrame ? .black : .clear
            targetView = self.imageView
            self.blurView.isHidden = true
        } else {
            targetView = self.blurView
            self.blurView.layer.cornerRadius = placement.coversWholeFrame ? 0.0 : min(rect.width, rect.height) / 2.0
            self.imageView.isHidden = true
        }
        if placement.coversWholeFrame {
            rect = bounds.insetBy(dx: -2.0, dy: -2.0)
            roll = 0.0
        }
        targetView.isHidden = false
        // Core Image rotates counterclockwise in a y-up space, UIKit is y-down.
        targetView.transform = .identity
        targetView.frame = rect
        targetView.transform = CGAffineTransform(rotationAngle: -roll)
    }
}
