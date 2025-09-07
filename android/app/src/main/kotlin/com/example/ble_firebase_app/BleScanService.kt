package com.example.ble_firebase_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import java.util.UUID

class BleScanService : Service() {

    private var bluetoothAdapter: BluetoothAdapter? = null
    private val serviceUuid = ParcelUuid(UUID.fromString("0000180D-0000-1000-8000-00805f9b34fb"))
    private var scanCallback: ScanCallback? = null

    companion object {
        // static reference to push events
        var events: EventChannel.EventSink? = null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, "ble_scan_channel")
            .setContentTitle("BLE Scanning")
            .setContentText("Scanning for nearby devices")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .build()

        startForeground(2, notification)
        startScanning()
        return START_STICKY
    }

    private fun startScanning() {
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            Log.e("BLE", "BLE Scanner not available")
            stopSelf()
            return
        }

        // Ensure permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                Log.e("BLE", "BLE scan permission missing")
                stopSelf()
                return
            }
        }

        val filter = ScanFilter.Builder()
            .setServiceUuid(serviceUuid)
            .build()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                result?.device?.let { device ->
                    val name = device.name ?: "Unknown"
                    val address = device.address
                    val deviceMap = mapOf("name" to name, "address" to address)
                    // Debug log
                    Log.d("BLE_SCAN", "Device found: $name - $address")

                    // Send to Flutter
                    events?.success(deviceMap) ?: Log.e("BLE_SCAN", "EventSink is null")
                }
            }

        }

        scanner.startScan(listOf(filter), settings, scanCallback)
        Log.d("BLE_SCAN", "Scan started")
    }

    override fun onDestroy() {
        super.onDestroy()
        bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
        Log.d("BLE_SCAN", "Scanning stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ble_scan_channel",
                "BLE Scanning",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
