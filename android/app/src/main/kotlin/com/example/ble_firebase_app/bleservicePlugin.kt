package com.example.ble_firebase_app

import io.flutter.plugin.common.EventChannel

object BleScanPlugin {
    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun sendScanResult(device: Map<String, Any>) {
        eventSink?.success(device)
    }
}
