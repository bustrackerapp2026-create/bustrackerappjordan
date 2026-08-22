package com.example.jordan_bus_tracker

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.jordan_bus_tracker/location_service"
    private val requestCheckSettings = 2404
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableLocationService" -> enableLocationService(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableLocationService(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another location-settings request is in progress", null)
            return
        }
        pendingResult = result

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            1000L,
        ).build()

        val settingsRequest = LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest)
            .setAlwaysShow(true)
            .build()

        LocationServices.getSettingsClient(this)
            .checkLocationSettings(settingsRequest)
            .addOnSuccessListener {
                // Location already on
                pendingResult?.success(true)
                pendingResult = null
            }
            .addOnFailureListener { exception ->
                if (exception is ResolvableApiException) {
                    try {
                        // Shows the system dialog: turn on location with one tap
                        exception.startResolutionForResult(this, requestCheckSettings)
                    } catch (sendEx: IntentSender.SendIntentException) {
                        pendingResult?.success(false)
                        pendingResult = null
                    }
                } else {
                    pendingResult?.success(false)
                    pendingResult = null
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCheckSettings) {
            pendingResult?.success(resultCode == Activity.RESULT_OK)
            pendingResult = null
        }
    }
}
