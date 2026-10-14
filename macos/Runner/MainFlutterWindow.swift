import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = true
    self.contentViewController = flutterViewController

    let windowSize = NSSize(width: 1200, height: 800)
    minSize = NSSize(width: 900, height: 620)
    if let screen = NSScreen.main {
      let visibleFrame = screen.visibleFrame
      let origin = NSPoint(
        x: visibleFrame.midX - windowSize.width / 2,
        y: visibleFrame.midY - windowSize.height / 2
      )
      setFrame(NSRect(origin: origin, size: windowSize), display: true)
    } else {
      setContentSize(windowSize)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
