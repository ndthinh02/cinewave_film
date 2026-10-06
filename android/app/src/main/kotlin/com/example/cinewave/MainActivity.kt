package com.example.cinewave


import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "movie_app/pip"

    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler { call, result ->

            when (call.method) {

                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()

                            val success =
                                enterPictureInPictureMode(params)

                            result.success(success)

                        } catch (e: Exception) {
                            result.error(
                                "PIP_ERROR",
                                e.message,
                                null
                            )
                        }

                    } else {
                        result.success(false)
                    }
                }

                "isInPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        result.success(
                            isInPictureInPictureMode
                        )
                    } else {
                        result.success(false)
                    }
                }

                "enableAutoPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

                        val params =
                            PictureInPictureParams.Builder()
                                .setAspectRatio(
                                    Rational(16, 9)
                                )
                                .setAutoEnterEnabled(true)
                                .build()

                        setPictureInPictureParams(params)
                    }

                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(
            isInPictureInPictureMode,
            newConfig
        )

        if (::channel.isInitialized) {
            channel.invokeMethod(
                "pipChanged",
                isInPictureInPictureMode
            )
        }
    }
}