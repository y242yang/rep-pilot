import WatchKit

enum Haptics {
    static func tap() {
        WKInterfaceDevice.current().play(.click)
    }
}
