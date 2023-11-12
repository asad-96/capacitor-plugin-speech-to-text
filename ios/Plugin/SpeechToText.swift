import Foundation

@objc public class SpeechToText: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
