import Foundation

let check = Process()
check.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
check.arguments = ["swift", "run", "--quiet", "-Xswiftc", "-warnings-as-errors", "RendererCheck"]
try check.run()
check.waitUntilExit()
exit(check.terminationStatus)
