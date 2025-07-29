package com.example.llm_voice_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import android.os.Build
import android.provider.Settings.Secure
import android.media.MediaRecorder
import android.media.MediaPlayer
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "voice_assistant_channel"
    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var isRecording = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    startRecording(result)
                }
                "stopRecording" -> {
                    stopRecording(result)
                }
                "performScroll" -> {
                    val direction = call.argument<String>("direction") ?: "down"
                    val scrollAmount = call.argument<Int>("scrollAmount") ?: 300
                    
                    MyAccessibilityService.instance?.performScroll(direction, scrollAmount)
                    result.success(true)
                }
                "performVirtualTouch" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    
                    MyAccessibilityService.instance?.performTouch(x, y)
                    result.success(true)
                }
                "performTextInput" -> {
                    val text = call.argument<String>("text") ?: ""
                    
                    MyAccessibilityService.instance?.performTextInput(text)
                    result.success(true)
                }
                "checkAccessibilityServiceStatus" -> {
                    val isEnabled = isAccessibilityServiceEnabled()
                    result.success(isEnabled)
                }
                "setHintEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    MyAccessibilityService.instance?.setHintEnabled(enabled)
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startRecording(result: MethodChannel.Result) {
        try {
            if (isRecording) {
                result.error("ALREADY_RECORDING", "이미 녹음 중입니다.", null)
                return
            }

            // 녹음 파일 생성
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            recordingFile = File(externalCacheDir, "recording_$timestamp.m4a")
            
            // MediaRecorder 설정
            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioChannels(1)
                setAudioEncodingBitRate(256000)
                setOutputFile(recordingFile!!.absolutePath)
            }

            // 녹음 시작
            mediaRecorder?.prepare()
            mediaRecorder?.start()
            isRecording = true

            result.success(true)
        } catch (e: Exception) {
            result.error("RECORDING_ERROR", "녹음 시작 실패: ${e.message}", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        try {
            if (!isRecording) {
                result.error("NOT_RECORDING", "녹음 중이 아닙니다.", null)
                return
            }

            // 녹음 중지
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false

            // 결과 반환
            val fileSize = recordingFile?.length() ?: 0
            val resultMap = mapOf(
                "success" to true,
                "filePath" to (recordingFile?.absolutePath ?: ""),
                "fileSize" to fileSize
            )

            result.success(resultMap)
        } catch (e: Exception) {
            result.error("STOP_RECORDING_ERROR", "녹음 중지 실패: ${e.message}", null)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED, 0
        )
        
        if (accessibilityEnabled == 1) {
            val service = "${packageName}/.MyAccessibilityService"
            val settingValue = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            return settingValue?.contains(service) == true
        }
        return false
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
}
