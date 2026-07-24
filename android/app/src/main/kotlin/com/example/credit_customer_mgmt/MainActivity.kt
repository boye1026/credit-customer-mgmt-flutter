package com.example.credit_customer_mgmt

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.credit_customer_mgmt/sms"
    private val SMS_PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> handleSendSms(call, result)
                "hasSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> handleRequestPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSendSms(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")
        val message = call.argument<String>("message")
        if (phone == null || message == null) {
            result.error("invalid_args", "phone and message are required", null)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error("no_permission", "SEND_SMS permission not granted", null)
            return
        }
        try {
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("send_failed", e.message, null)
        }
    }

    private var permissionLatch: CountDownLatch? = null
    private var permissionGranted = false

    private fun handleRequestPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        permissionLatch = CountDownLatch(1)
        permissionGranted = false
        requestPermissions(arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST_CODE)
        Thread {
            try {
                permissionLatch?.await(30, TimeUnit.SECONDS)
            } catch (_: InterruptedException) {}
            runOnUiThread {
                result.success(permissionGranted)
            }
        }.start()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            permissionGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionLatch?.countDown()
        }
    }
}
