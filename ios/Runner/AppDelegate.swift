import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let ledgerPrivacyChannel = "dev.nedhuohuo.personalfinancespro/ledger_privacy"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      FlutterMethodChannel(
        name: ledgerPrivacyChannel,
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "prepareLedgerDirectory" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.prepareLedgerDirectory(result: result)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func prepareLedgerDirectory(result: FlutterResult) {
    do {
      let support = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      let ledger = support.appendingPathComponent("ledger", isDirectory: true)
      try FileManager.default.createDirectory(
        at: ledger,
        withIntermediateDirectories: true
      )
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableLedger = ledger
      try mutableLedger.setResourceValues(values)
      let readback = try mutableLedger.resourceValues(
        forKeys: [.isExcludedFromBackupKey]
      ).isExcludedFromBackup == true
      let path = mutableLedger.resolvingSymlinksInPath().path
      guard readback else {
        result(FlutterError(
          code: "ledger_privacy_unverified",
          message: "无法确认账本已排除系统自动备份",
          details: nil
        ))
        return
      }
      result(["path": path, "backupExcludedVerified": true])
    } catch {
      result(FlutterError(
        code: "ledger_privacy_failed",
        message: "无法确认账本已排除系统自动备份",
        details: String(describing: error)
      ))
    }
  }
}
