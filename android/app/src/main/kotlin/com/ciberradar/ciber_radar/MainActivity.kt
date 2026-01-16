
package com.ciberradar.ciber_radar

import android.content.Context
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoWcdma
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.ciberradar/cell"
    private val EVENT_CHANNEL = "com.ciberradar/cell_updates"
    
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. Method Channel (On Demand)
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

        // 2. Event Channel (Real-time Stream)
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
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
    }

    private fun stopListening() {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
    }

    private val phoneStateListener = object : PhoneStateListener() {
        override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
            super.onSignalStrengthsChanged(signalStrength)
            // On signal change, fetch fresh info and push to sink
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
                } else {
                     data["type"] = "UNKNOWN"
                     // 5G Mock for build safety
                     if (Build.VERSION.SDK_INT >= 29 && info.toString().contains("CellInfoNr")) {
                          data["type"] = "NR"
                          data["dbm"] = -65 
                          data["asu"] = 70
                     }
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
