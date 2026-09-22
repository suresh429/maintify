package com.maintify.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MaintifyUPI"
        private const val UPI_CHANNEL = "com.maintify.upi/launcher"
        private const val PHONEPE_PACKAGE = "com.phonepe.app"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAvailableUpiApps" -> handleGetAvailableUpiApps(result)
                    "launchUpi"           -> handleLaunchUpi(call, result)
                    // Legacy "launch" kept for backward compatibility
                    "launch" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        launchIntent(uri, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Discovers UPI apps available on this device.
     *
     * Strategy:
     * 1. Query PackageManager for all apps that handle the standard `upi://pay` intent.
     * 2. If PhonePe (com.phonepe.app) is installed but NOT found in the standard list,
     *    add it with `scheme=phonePe` so it is launched via `ppe://pay` instead.
     *    This handles Android 16 (API 36) Realme/ColorOS/Xiaomi devices where PhonePe
     *    registers `ppe://` but does not respond to the generic `upi://` intent query.
     * 3. Never hard-codes internal activity class names — always uses ACTION_VIEW.
     */
    private fun handleGetAvailableUpiApps(result: MethodChannel.Result) {
        try {
            val apps = mutableListOf<Map<String, String>>()
            val seenPackages = mutableSetOf<String>()

            // ── Step 1: Standard upi:// resolvers ──────────────────────────────────
            val upiIntent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
            @Suppress("DEPRECATION")
            val upiActivities = packageManager.queryIntentActivities(upiIntent, 0)
            Log.d(TAG, "Standard upi:// query returned ${upiActivities.size} resolver(s)")

            for (ri in upiActivities) {
                val pkg  = ri.activityInfo.packageName
                val name = ri.loadLabel(packageManager).toString()
                Log.d(TAG, "  upi:// resolver: $pkg ($name)")
                if (seenPackages.add(pkg)) {
                    apps.add(mapOf("packageName" to pkg, "appName" to name, "scheme" to "standard"))
                }
            }

            // ── Step 2: PhonePe ppe:// fallback ────────────────────────────────────
            // Only add if PhonePe is installed but didn't show up in the upi:// query.
            if (isPackageInstalled(PHONEPE_PACKAGE) && !seenPackages.contains(PHONEPE_PACKAGE)) {
                Log.d(TAG, "PhonePe installed but not in upi:// resolvers — checking ppe:// scheme")

                @Suppress("DEPRECATION")
                val ppeActivities = packageManager.queryIntentActivities(
                    Intent(Intent.ACTION_VIEW, Uri.parse("ppe://pay")), 0
                )
                Log.d(TAG, "ppe:// query returned ${ppeActivities.size} resolver(s)")

                // Add PhonePe regardless of queryIntentActivities result.
                // startActivity(ppe://pay?...) is confirmed working on Android 16
                // even when queryIntentActivities returns 0 due to strict visibility rules.
                val phonePeLabel = try {
                    val appInfo = packageManager.getApplicationInfo(PHONEPE_PACKAGE, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: PackageManager.NameNotFoundException) { "PhonePe" }

                apps.add(mapOf(
                    "packageName" to PHONEPE_PACKAGE,
                    "appName"     to phonePeLabel,
                    "scheme"      to "phonePe",
                ))
                seenPackages.add(PHONEPE_PACKAGE)
                Log.d(TAG, "PhonePe added with ppe:// scheme (label=$phonePeLabel)")
            }

            Log.d(TAG, "Total UPI apps discovered: ${apps.size}")
            result.success(apps)

        } catch (e: Exception) {
            Log.e(TAG, "getAvailableUpiApps failed: ${e.message}")
            result.error("UPI_DISCOVERY_ERROR", e.message, null)
        }
    }

    /**
     * Launches a UPI payment intent for the given payment parameters.
     *
     * Uses [Uri.Builder] for safe, correct-encoding URI construction.
     * - scheme=standard  → upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
     * - scheme=phonePe   → ppe://pay?pa=...&pn=...&am=...&cu=INR&tn=...
     *
     * Never references any internal Activity by class name.
     */
    private fun handleLaunchUpi(call: MethodCall, result: MethodChannel.Result) {
        val upiId     = call.argument<String>("upiId")    ?: return result.error("BAD_ARGS", "upiId missing", null)
        val payeeName = call.argument<String>("payeeName") ?: ""
        val amount    = call.argument<String>("amount")    ?: return result.error("BAD_ARGS", "amount missing", null)
        val txnNote   = call.argument<String>("txnNote")   ?: "Maintify"
        val scheme    = call.argument<String>("scheme")    ?: "standard"

        val schemeStr = if (scheme == "phonePe") "ppe" else "upi"

        val uri = Uri.Builder()
            .scheme(schemeStr)
            .authority("pay")
            .appendQueryParameter("pa", upiId)
            .appendQueryParameter("pn", payeeName)
            .appendQueryParameter("am", amount)
            .appendQueryParameter("cu", "INR")
            .appendQueryParameter("tn", txnNote)
            .build()
            .toString()

        val logUri = uri.replace(Regex("pa=[^&]+"), "pa=***")
        Log.d(TAG, "launchUpi scheme=$schemeStr uri=$logUri")
        launchIntent(uri, result)
    }

    /** Fires ACTION_VIEW for [uriString] via startActivity(). Returns true/false or error. */
    private fun launchIntent(uriString: String, result: MethodChannel.Result) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uriString)))
            Log.d(TAG, "Intent launched successfully")
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "ActivityNotFoundException — no activity for URI")
            result.success(false)
        } catch (e: Exception) {
            Log.e(TAG, "Intent launch error: ${e.message}")
            result.error("UPI_ERROR", e.message, null)
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
