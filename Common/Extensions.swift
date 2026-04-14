/*
 *  GenericColorExtension.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 18/06/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation
import Cocoa


extension NSColor {

    /**
     Convert a colour's internal representation into an RGB+A hex string.
     */
    var hexString: String {

        guard let rgbColour = usingColorSpace(.sRGB) else {
            return BUFFOON_CONSTANTS.HEX_COLOUR.KEYS
        }

        let red: Int = Int(round(rgbColour.redComponent * 0xFF))
        let green: Int = Int(round(rgbColour.greenComponent * 0xFF))
        let blue: Int = Int(round(rgbColour.blueComponent * 0xFF))
        let alpha: Int = Int(round(rgbColour.alphaComponent * 0xFF))

        let hexString: NSString = NSString(format: "%02X%02X%02X%02X", red, green, blue, alpha)
        return hexString as String
    }


    /**
     Generate a new NSColor from an RGB+A hex string..

     - Parameters:
        - hex: The RGB+A hex string, eg.`AABBCCFF`.

     - Returns: An NSColor instance.
     */
    static func hexToColour(_ hex: String) -> NSColor {

        if hex.count != 8 {
            return NSColor.red
        }

        func hexToFloat(_ hs: String) -> CGFloat {
            return CGFloat(UInt8(hs, radix: 16) ?? 0)
        }

        let hexns: NSString = hex as NSString
        let red: CGFloat = hexToFloat(hexns.substring(with: NSRange(location: 0, length: 2))) / 255
        let green: CGFloat = hexToFloat(hexns.substring(with: NSRange(location: 2, length: 2))) / 255
        let blue: CGFloat = hexToFloat(hexns.substring(with: NSRange(location: 4, length: 2))) / 255
        let alpha: CGFloat = hexToFloat(hexns.substring(with: NSRange(location: 6, length: 2))) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}


extension NSAttributedString {

    /**
     Return the width of the rendered string in points.
     */
    var width: CGFloat {
        let rectA = boundingRect(
          with: NSSize(width: Double.infinity, height: Double.infinity),
          options: [.usesLineFragmentOrigin]
        )

        let textStorage = NSTextStorage(attributedString: self)
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0.0
        layoutManager.glyphRange(for: textContainer)

        let rectB = layoutManager.usedRect(for: textContainer)
        return ceil(max(rectA.width, rectB.width))
    }
}


extension CGFloat {

    /**
     Determine if the instance is near enough the specified value as makes no odds.

     - Parameters
        - value: The float value we're comparing the instance to.

     - Returns `true` if the values are proximate, otherwise `false`.
     */
    func isClose(to value: CGFloat) -> Bool {

        let rndA = (self * 100).rounded() / 100
        let rndB = (value * 100).rounded() / 100

        if self == value || rndA == rndB {
            return true
        }

        let absA: CGFloat = abs(self)
        let absB: CGFloat = abs(value)
        let diff: CGFloat = abs(self - value)

        if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}


extension Double {

    /**
     Determine if the instance is near enough the specified value as makes no odds.

     - Parameters
        - value: The float value we're comparing the instance to.

     - Returns `true` if the values are proximate, otherwise `false`.
     */
    func isClose(to value: CGFloat) -> Bool {

        let rndA = (self * 100).rounded() / 100
        let rndB = (value * 100).rounded() / 100

        if self == value || rndA == rndB {
            return true
        }

        let absA: CGFloat = abs(self)
        let absB: CGFloat = abs(value)
        let diff: CGFloat = abs(self - value)

        if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}


extension Data {

    var stringEncoding: String.Encoding? {
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: nil,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


extension NSApplication {

    var inLightMode: Bool {
        get {
            return (self.effectiveAppearance.name.rawValue == "NSAppearanceNameAqua")
        }
    }
}
