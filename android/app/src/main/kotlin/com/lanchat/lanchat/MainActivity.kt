package com.lanchat.lanchat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meshmind.inference")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runtime_status" -> {
                        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
                        val battery = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val power = getSystemService(POWER_SERVICE) as PowerManager
                            when (power.currentThermalStatus) {
                                PowerManager.THERMAL_STATUS_NONE -> "nominal"
                                PowerManager.THERMAL_STATUS_LIGHT -> "fair"
                                PowerManager.THERMAL_STATUS_MODERATE -> "fair"
                                PowerManager.THERMAL_STATUS_SEVERE -> "serious"
                                PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
                                PowerManager.THERMAL_STATUS_EMERGENCY -> "critical"
                                PowerManager.THERMAL_STATUS_SHUTDOWN -> "critical"
                                else -> "unknown"
                            }
                        } else "unknown"
                        result.success(mapOf(
                            "available" to false,
                            "backend" to "none",
                            "batteryPercent" to battery,
                            "thermalState" to thermal
                        ))
                    }
                    "generate" -> result.error("UNAVAILABLE", "No native GGUF runtime is bundled yet.", null)
                    else -> result.notImplemented()
                }
            }
    }
}
