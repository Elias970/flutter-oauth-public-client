package com.example.oauth_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.pkceauth.ios/auth"
	private var methodChannel: MethodChannel? = null

	companion object {
		@JvmStatic
		var pendingUrl: String? = null
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
		methodChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"getInitialUrl" -> {
					result.success(pendingUrl)
					pendingUrl = null
				}
				else -> result.notImplemented()
			}
		}
		// Handle the launch intent if it contains a deep link
		handleIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleIntent(intent)
	}

	private fun handleIntent(intent: Intent?) {
		val data: Uri? = intent?.data
		val url = data?.toString()
		if (!url.isNullOrEmpty()) {
			pendingUrl = url
			methodChannel?.invokeMethod("onAuthRedirect", url)
		}
	}
}
