package com.ciberradar.ciber_radar

import android.content.Context
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoWcdma
import android.telephony.CellInfoNr
import android.telephony.CellIdentityNr
import android.telephony.CellSignalStrengthNr
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.TelephonyManager
import android.telephony.TelephonyCallback
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.ciberradar/cell"
    private val EVENT_CHANNEL = "com.ciberradar/cell_updates"

    private var eventSink: EventChannel.EventSink? = null
    private var telephonyCallback: Any? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getCells") {
                val cells = getCells()
                if (cells != null) {
                    result.success(cells)
                } else {
                    result.error("UNAVAILABLE", "Cell info unavailable", null)
                }
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startListening()
                }

                override fun onCancel(arguments: Any?) {
                    stopListening()
                    eventSink = null
                }
            }
        )
    }

    private fun startListening() {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Use TelephonyCallback for Android 12+ (API 31+)
            try {
                val callback = TelephonyCallbackImpl()
                telephonyCallback = callback
                if (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    @Suppress("UNCHECKED_CAST")
                    telephonyManager.registerTelephonyCallback(mainExecutor, callback as TelephonyCallback)
                }
            } catch (e: Exception) {
                // Fallback to deprecated PhoneStateListener
                telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
            }
        } else {
            // PhoneStateListener for Android < 12
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
        }
    }

    private fun stopListening() {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && telephonyCallback != null) {
            try {
                @Suppress("UNCHECKED_CAST")
                telephonyManager.unregisterTelephonyCallback(telephonyCallback as TelephonyCallback)
            } catch (e: Exception) {
                // ignore
            }
            telephonyCallback = null
        } else {
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        }
    }

    // TelephonyCallback for Android 12+
    private inner class TelephonyCallbackImpl : TelephonyCallback(),
        TelephonyCallback.SignalStrengthsListener {
        override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
            val cells = getCells()
            if (cells != null && eventSink != null) {
                eventSink!!.success(cells)
            }
        }
    }

    private val phoneStateListener = object : PhoneStateListener() {
        override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
            super.onSignalStrengthsChanged(signalStrength)
            val cells = getCells()
            if (cells != null && eventSink != null) {
                eventSink!!.success(cells)
            }
        }
    }

    private fun getCells(): List<Map<String, Any>>? {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        try {
            val cellList = telephonyManager.allCellInfo
            if (cellList == null) return null

            val operatorName = telephonyManager.networkOperatorName ?: "Unknown"

            val results = mutableListOf<Map<String, Any>>()
            for (info in cellList) {
                val data = mutableMapOf<String, Any>()
                data["isRegistered"] = info.isRegistered
                data["timestamp"] = info.timeStamp
                data["operator"] = operatorName

                if (info is CellInfoLte) {
                    data["type"] = "LTE"
                    data["cid"] = info.cellIdentity.ci
                    data["lac"] = info.cellIdentity.tac
                    data["dbm"] = info.cellSignalStrength.dbm
                    data["asu"] = info.cellSignalStrength.asuLevel
                } else if (info is CellInfoGsm) {
                    data["type"] = "GSM"
                    data["cid"] = info.cellIdentity.cid
                    data["lac"] = info.cellIdentity.lac
                    data["dbm"] = info.cellSignalStrength.dbm
                    data["asu"] = info.cellSignalStrength.asuLevel
                } else if (info is CellInfoWcdma) {
                    data["type"] = "WCDMA"
                    data["cid"] = info.cellIdentity.cid
                    data["lac"] = info.cellIdentity.lac
                    data["dbm"] = info.cellSignalStrength.dbm
                    data["asu"] = info.cellSignalStrength.asuLevel
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && info is CellInfoNr) {
                    // Real 5G NR support -- no more fake data
                    data["type"] = "NR"
                    val nrIdentity = info.cellIdentity as CellIdentityNr
                    val nrSignal = info.cellSignalStrength as CellSignalStrengthNr
                    data["nci"] = nrIdentity.nci
                    data["pci"] = nrIdentity.pci
                    data["tac"] = nrIdentity.tac
                    data["dbm"] = nrSignal.dbm
                    data["asu"] = nrSignal.asuLevel
                    data["ssRsrp"] = nrSignal.ssRsrp
                    data["ssRsrq"] = nrSignal.ssRsrq
                    data["ssSinr"] = nrSignal.ssSinr
                } else {
                     data["type"] = "UNKNOWN"
                }

                if (data.containsKey("type") && data["type"] != "UNKNOWN") {
                    results.add(data)
                }
            }
            return results
        } catch (e: SecurityException) {
            return null
        } catch (e: Exception) {
            return null
        }
    }
}