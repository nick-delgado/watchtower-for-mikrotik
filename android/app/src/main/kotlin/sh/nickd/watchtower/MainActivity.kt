package sh.nickd.watchtower

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingRequest: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> requestLocalNetwork(result)
                    "openSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Android 17 blocks connections to the local network unless the user
    // grants ACCESS_LOCAL_NETWORK. Earlier versions allow them implicitly.
    private fun requestLocalNetwork(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < ANDROID_17 ||
            checkSelfPermission(LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingRequest?.success(false)
        pendingRequest = result
        requestPermissions(arrayOf(LOCAL_NETWORK), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        pendingRequest?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        pendingRequest = null
    }

    private companion object {
        const val CHANNEL = "sh.nickd.watchtower/local_network"
        const val LOCAL_NETWORK = "android.permission.ACCESS_LOCAL_NETWORK"
        const val ANDROID_17 = 37
        const val REQUEST_CODE = 4201
    }
}
