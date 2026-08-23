package com.example.jordan_bus_tracker

import android.app.Activity
import android.content.IntentSender
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
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
    private var pendingResult: MethodChannel.Result? = null

    /** Modern replacement for the deprecated startActivityForResult / onActivityResult. */
    private val locationSettingsLauncher: ActivityResultLauncher<IntentSenderRequest> =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            pendingResult?.success(result.resultCode == Activity.RESULT_OK)
            pendingResult = null
        }

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
                        // System one-tap dialog to enable location
                        val intentSenderRequest =
                            IntentSenderRequest.Builder(exception.resolution).build()
                        locationSettingsLauncher.launch(intentSenderRequest)
                    } catch (sendEx: IntentSender.SendIntentException) {
                        pendingResult?.success(false)
                        pendingResult = null
                    } catch (e: Exception) {
                        pendingResult?.success(false)
                        pendingResult = null
                    }
                } else {
                    pendingResult?.success(false)
                    pendingResult = null
                }
            }
    }

    override fun onDestroy() {
        // Avoid stuck pendingResult if Activity is destroyed while the dialog is showing
        // (rotation, low memory, process death). Resolves the Flutter Future so it does not hang.
        pendingResult?.success(false)
        pendingResult = null
        super.onDestroy()
    }
}
