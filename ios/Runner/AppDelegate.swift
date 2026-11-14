import Flutter
import MeshMindInference
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let inferenceChannel = FlutterMethodChannel(
      name: "meshmind.inference",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    inferenceChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "runtime_status":
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel < 0
          ? NSNull()
          : Int(UIDevice.current.batteryLevel * 100)
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        result([
          "available": true,
          "backend": MeshMindRuntime.backendName,
          "batteryPercent": battery,
          "thermalState": thermal
        ])
      case "generate":
        guard
          let arguments = call.arguments as? [String: Any],
          let modelPath = arguments["modelPath"] as? String,
          let prompt = arguments["prompt"] as? String,
          !modelPath.isEmpty,
          !prompt.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "A modelPath and prompt are required for local inference.",
            details: nil
          ))
          return
        }

        let maxTokens = (arguments["maxTokens"] as? NSNumber)?.int32Value ?? 256
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let output = try MeshMindRuntime.generate(
              modelPath: modelPath,
              prompt: prompt,
              maxTokens: maxTokens
            )
            DispatchQueue.main.async { result(output) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "INFERENCE_FAILED",
                message: "The local llama.cpp runtime could not generate output.",
                details: "(error)"
              ))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
