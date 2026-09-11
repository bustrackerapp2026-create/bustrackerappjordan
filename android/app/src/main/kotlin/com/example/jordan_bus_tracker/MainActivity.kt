package com.example.jordan_bus_tracker

import android.app.Activity
import android.content.Intent
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * نافذة تفعيل الموقع عبر Google Settings API.
 * النتائج:
 * - success(true)  = الموقع مفعّل أو وافق المستخدم
 * - success(false) = ظهر الحوار ورفض/أغلق المستخدم (لا تعرض حوار Flutter)
 * - error(UNRESOLVABLE) = تعذر عرض حوار النظام → يسمح لـ Flutter بعرض حوار واحد
 */
class MainActivity : FlutterFragmentActivity() {
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
            // طلب جارٍ — لا تفتح حواراً ثانياً
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
                pendingResult?.success(true)
                pendingResult = null
            }
            .addOnFailureListener { exception ->
                if (exception is ResolvableApiException) {
                    try {
                        exception.startResolutionForResult(this, requestCheckSettings)
                        // النتيجة تُرسل من onActivityResult
                    } catch (e: Exception) {
                        val r = pendingResult
                        pendingResult = null
                        r?.error("UNRESOLVABLE", e.message, null)
                    }
                } else {
                    val r = pendingResult
                    pendingResult = null
                    r?.error(
                        "UNRESOLVABLE",
                        exception.message ?: "Location settings cannot be resolved",
                        null,
                    )
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

    override fun onDestroy() {
        pendingResult?.success(false)
        pendingResult = null
        super.onDestroy()
    }
}
