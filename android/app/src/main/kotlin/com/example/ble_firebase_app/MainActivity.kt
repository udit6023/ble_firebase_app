package com.example.ble_firebase_app

import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val ADVERTISE_CHANNEL = "ble_advertise"
    private val SCAN_CHANNEL = "ble_scan"
    private val SCAN_EVENT_CHANNEL = "com.example.ble_firebase_app/ble_scan_updates"

    companion object {
        var scanEventSink: EventChannel.EventSink? = null
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Advertising methods
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADVERTISE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAdvertising" -> {
                        ContextCompat.startForegroundService(this, Intent(this, BleAdvertiseService::class.java))
                        result.success("Advertising started")
                    }
                    "stopAdvertising" -> {
                        stopService(Intent(this, BleAdvertiseService::class.java))
                        result.success("Advertising stopped")
                    }
                    else -> result.notImplemented()
                }
            }

        // Scanning methods
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScanning" -> {
                        ContextCompat.startForegroundService(this, Intent(this, BleScanService::class.java))
                        result.success("Scanning started")
                    }
                    "stopScanning" -> {
                        stopService(Intent(this, BleScanService::class.java))
                        result.success("Scanning stopped")
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel to receive scan results
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    BleScanService.events = events
                }

                override fun onCancel(arguments: Any?) {
                    BleScanService.events = null

                }
            })
    }
}
