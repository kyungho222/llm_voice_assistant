package com.example.llm_voice_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log
import android.media.MediaRecorder
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "voice_assistant_channel"
    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null
    
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
                "startBackgroundService" -> {
                    startBackgroundService()
                    result.success("백그라운드 서비스 시작됨")
                }
                "stopBackgroundService" -> {
                    stopBackgroundService()
                    result.success("백그라운드 서비스 중지됨")
                }
                "performVirtualTouch" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    performVirtualTouch(x.toFloat(), y.toFloat())
                    result.success("가상 터치 실행됨")
                }
                "performScroll" -> {
                    val direction = call.argument<String>("direction") ?: "down"
                    performScroll(direction)
                    result.success("스크롤 실행됨")
                }
                "performType" -> {
                    val text = call.argument<String>("text") ?: ""
                    performType(text)
                    result.success("텍스트 입력 실행됨")
                }
                "checkAccessibilityService" -> {
                    val isEnabled = checkAccessibilityService()
                    result.success(isEnabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startRecording(result: MethodChannel.Result) {
        try {
            val tempDir = File(cacheDir, "recordings")
            if (!tempDir.exists()) {
                tempDir.mkdirs()
            }
            
            recordingFile = File(tempDir, "voice_recording.m4a")
            
            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)  // 더 높은 샘플링 레이트
                setAudioChannels(1)
                setAudioEncodingBitRate(256000)  // 더 높은 비트레이트
                setOutputFile(recordingFile!!.absolutePath)
            }
            
            mediaRecorder?.prepare()
            mediaRecorder?.start()
            
            Log.d("MainActivity", "녹음 시작: ${recordingFile!!.absolutePath}")
            result.success("녹음 시작됨")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "녹음 시작 오류: ${e.message}")
            result.error("RECORDING_ERROR", "녹음 시작 실패", e.message)
        }
    }
    
    private fun stopRecording(result: MethodChannel.Result) {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            
            val fileSize = recordingFile?.length() ?: 0
            val filePath = recordingFile?.absolutePath ?: ""
            
            Log.d("MainActivity", "녹음 중지: $filePath (크기: $fileSize bytes)")
            
            result.success(mapOf(
                "success" to true,
                "filePath" to filePath,
                "fileSize" to fileSize
            ))
            
        } catch (e: Exception) {
            Log.e("MainActivity", "녹음 중지 오류: ${e.message}")
            result.error("RECORDING_ERROR", "녹음 중지 실패", e.message)
        }
    }
    
    private fun startBackgroundService() {
        val intent = Intent(this, BackgroundService::class.java)
        startForegroundService(intent)
        Log.d("MainActivity", "백그라운드 서비스 시작")
    }
    
    private fun stopBackgroundService() {
        val intent = Intent(this, BackgroundService::class.java)
        stopService(intent)
        Log.d("MainActivity", "백그라운드 서비스 중지")
    }
    
    private fun performVirtualTouch(x: Float, y: Float) {
        Log.d("MainActivity", "가상 터치 호출됨: ($x, $y)")
        
        val accessibilityService = MyAccessibilityService.getInstance()
        if (accessibilityService != null) {
            Log.d("MainActivity", "접근성 서비스 인스턴스 찾음, 가상 터치 실행 중...")
            accessibilityService.performVirtualTouch(x, y)
            Log.d("MainActivity", "가상 터치 실행 완료: ($x, $y)")
        } else {
            Log.e("MainActivity", "접근성 서비스가 비활성화되어 가상 터치를 실행할 수 없습니다.")
        }
    }
    
    private fun checkAccessibilityService(): Boolean {
        try {
            // 접근성 서비스 상태 확인
            val accessibilityService = MyAccessibilityService.getInstance()
            val isEnabled = accessibilityService != null
            
            // 추가 검증: 실제로 서비스가 활성화되어 있는지 확인
            if (isEnabled) {
                Log.d("MainActivity", "접근성 서비스 활성화됨")
            } else {
                Log.w("MainActivity", "접근성 서비스 비활성화됨 - 설정에서 활성화 필요")
            }
            
            return isEnabled
        } catch (e: Exception) {
            Log.e("MainActivity", "접근성 서비스 확인 오류: ${e.message}")
            return false
        }
    }

    // 스크롤 액션 실행
    private fun performScroll(direction: String) {
        val accessibilityService = MyAccessibilityService.getInstance()
        if (accessibilityService != null) {
            accessibilityService.performScroll(direction)
            Log.d("MainActivity", "스크롤 실행: $direction")
        } else {
            Log.e("MainActivity", "접근성 서비스가 비활성화되어 스크롤을 실행할 수 없습니다.")
        }
    }

    // 텍스트 입력 액션 실행
    private fun performType(text: String) {
        val accessibilityService = MyAccessibilityService.getInstance()
        if (accessibilityService != null) {
            accessibilityService.performType(text)
            Log.d("MainActivity", "텍스트 입력 실행: $text")
        } else {
            Log.e("MainActivity", "접근성 서비스가 비활성화되어 텍스트 입력을 실행할 수 없습니다.")
        }
    }
}
