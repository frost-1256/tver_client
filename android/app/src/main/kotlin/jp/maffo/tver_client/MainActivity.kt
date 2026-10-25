package jp.maffo.tver_client

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pipChannelName = "jp.maffo.tver_client/pip"
    private var pipChannel: MethodChannel? = null
    private var pipAutoEnter = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        pipChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> result.success(enterPip())
                "setAutoEnter" -> {
                    pipAutoEnter = call.arguments as? Boolean ?: false
                    applyPipParams()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("pipModeChanged", isInPictureInPictureMode)
    }

    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(pipAutoEnter)
        }
        return builder.build()
    }

    private fun applyPipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                setPictureInPictureParams(buildPipParams())
            } catch (_: Exception) {
                // Best effort only.
            }
        }
    }

    private fun enterPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            enterPictureInPictureMode(buildPipParams())
        } catch (_: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 12+ handles this via setAutoEnterEnabled; older versions
        // enter PiP manually when the user leaves during playback.
        if (pipAutoEnter && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPip()
        }
    }
}
