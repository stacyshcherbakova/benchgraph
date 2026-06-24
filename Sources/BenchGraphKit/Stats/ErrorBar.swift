import Foundation

/// Which spread statistic a bar's error bar represents.
///
/// Prism lets the user pick what an error bar means before they read a figure,
/// because SD, SEM, and a 95% CI tell very different stories from the same data.
/// All three are symmetric about the mean here (the 95% CI of the mean is
/// mean ± t·SEM), so a single half-length describes the bar.
public enum ErrorBarKind: String, CaseIterable, Sendable, Codable {
    case sd   = "SD"
    case sem  = "SEM"
    case ci95 = "95% CI"

    /// The symmetric half-length of the error bar for a sample summary.
    public func halfLength(_ s: Descriptive.Summary) -> Double {
        switch self {
        case .sd:   return s.sd
        case .sem:  return s.sem
        case .ci95: return (s.ci95Upper - s.ci95Lower) / 2
        }
    }

    /// Axis caption describing what the bars show, e.g. "Mean ± SEM".
    public var caption: String {
        switch self {
        case .sd:   return "Mean ± SD"
        case .sem:  return "Mean ± SEM"
        case .ci95: return "Mean with 95% CI"
        }
    }
}
