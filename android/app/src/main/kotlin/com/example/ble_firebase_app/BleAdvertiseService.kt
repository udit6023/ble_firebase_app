package com.example.ble_firebase_app

import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.UUID
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager

class BleAdvertiseService : Service() {

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(1, getNotification())
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e("BLE", "Bluetooth is OFF or unsupported")
            stopSelf()
            return
        }

        if (!bluetoothAdapter.isMultipleAdvertisementSupported) {
            Log.e("BLE", "Device does not support BLE advertising")
            stopSelf()
            return
        }

        advertiser = bluetoothAdapter.bluetoothLeAdvertiser

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()

        val serviceUuid = ParcelUuid(UUID.fromString("0000180D-0000-1000-8000-00805f9b34fb"))
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(serviceUuid)
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                super.onStartSuccess(settingsInEffect)
                Log.d("BLE", "Advertising started ✅")
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                Log.e("BLE", "Advertising failed ❌ $errorCode")
            }
        }

        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ble_channel",
                "BLE Advertising",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun getNotification(): Notification {
        return NotificationCompat.Builder(this, "ble_channel")
            .setContentTitle("BLE Advertising")
            .setContentText("Your device is discoverable via BLE")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        advertiser?.stopAdvertising(advertiseCallback)
        Log.d("BLE", "Advertising stopped")
    }
}

