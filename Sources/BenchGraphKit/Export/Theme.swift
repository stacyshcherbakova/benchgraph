import Foundation

/// A visual preset for figures: the palette and ink used by every renderer
/// (SVG, CoreGraphics, and the live SwiftUI chart) so a figure looks identical
/// across formats and the app can offer "journal-style" output presets.
///
/// Colors are hex strings (`#RRGGBB`); each renderer converts them to its own
/// color type. The `default` preset reproduces the original hard-coded look.
public struct Theme: Sendable, Equatable, Codable {
    public let name: String
    /// Cycled across box/violin groups and multi-series scatter.
    public let palette: [String]
    /// Fill for bars and the single-series scatter points.
    public let primaryColor: String
    /// Fitted curves / regression lines.
    public let curveColor: String
    /// Axes, ticks, whiskers, and category labels.
    public let axisColor: String
    /// Titles and emphasis text (slightly darker than the axis ink).
    public let textColor: String
    public let backgroundColor: String
    /// CSS font stack for SVG output.
    public let fontFamily: String
    /// CoreText font names for raster/PDF output.
    public let fontName: String
    public let boldFontName: String

    public init(name: String, palette: [String], primaryColor: String, curveColor: String,
                axisColor: String, textColor: String, backgroundColor: String,
                fontFamily: String, fontName: String, boldFontName: String) {
        self.name = name
        self.palette = palette
        self.primaryColor = primaryColor
        self.curveColor = curveColor
        self.axisColor = axisColor
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.fontFamily = fontFamily
        self.fontName = fontName
        self.boldFontName = boldFontName
    }

    /// Palette color for the i-th group/series, cycling if there are more
    /// groups than palette entries.
    public func color(at i: Int) -> String {
        palette.isEmpty ? primaryColor : palette[i % palette.count]
    }

    // MARK: - Presets

    /// The original look: blue data, red curves, Helvetica. Kept byte-stable so
    /// existing snapshot expectations hold.
    public static let `default` = Theme(
        name: "Default",
        palette: ["#2C6FBB", "#D1495B", "#E3A72F", "#3C8D5B", "#7E5BBE", "#4FA3C7"],
        primaryColor: "#2C6FBB",
        curveColor: "#D1495B",
        axisColor: "#333333",
        textColor: "#222222",
        backgroundColor: "#ffffff",
        fontFamily: "Helvetica, Arial, sans-serif",
        fontName: "Helvetica",
        boldFontName: "Helvetica-Bold"
    )

    /// Muted, colour-blind-friendly palette in the spirit of Nature figures.
    public static let nature = Theme(
        name: "Nature",
        palette: ["#4878A8", "#E1812C", "#3A923A", "#C03D3E", "#8C61B0", "#7F7F7F"],
        primaryColor: "#4878A8",
        curveColor: "#C03D3E",
        axisColor: "#2B2B2B",
        textColor: "#1A1A1A",
        backgroundColor: "#ffffff",
        fontFamily: "Helvetica, Arial, sans-serif",
        fontName: "Helvetica",
        boldFontName: "Helvetica-Bold"
    )

    /// Grayscale for print-economy / single-channel journals.
    public static let grayscale = Theme(
        name: "Grayscale",
        palette: ["#3A3A3A", "#6E6E6E", "#9C9C9C", "#5A5A5A", "#828282", "#B4B4B4"],
        primaryColor: "#4D4D4D",
        curveColor: "#1A1A1A",
        axisColor: "#1A1A1A",
        textColor: "#000000",
        backgroundColor: "#ffffff",
        fontFamily: "Helvetica, Arial, sans-serif",
        fontName: "Helvetica",
        boldFontName: "Helvetica-Bold"
    )

    /// High-contrast palette for slides and posters.
    public static let vibrant = Theme(
        name: "Vibrant",
        palette: ["#2274A5", "#F75C03", "#00A878", "#D90368", "#7B2CBF", "#F5B700"],
        primaryColor: "#2274A5",
        curveColor: "#D90368",
        axisColor: "#222222",
        textColor: "#111111",
        backgroundColor: "#ffffff",
        fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
        fontName: "HelveticaNeue",
        boldFontName: "HelveticaNeue-Bold"
    )

    /// All built-in presets, in menu order.
    public static let presets: [Theme] = [.default, .nature, .grayscale, .vibrant]

    /// Look a preset up by name (case-insensitive), for the CLI `--theme` flag.
    public static func named(_ raw: String) -> Theme? {
        let key = raw.lowercased()
        return presets.first { $0.name.lowercased() == key }
    }
}
