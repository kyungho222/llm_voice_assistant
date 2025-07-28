package com.example.llm_voice_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import androidx.core.app.NotificationCompat

class BackgroundService : Service() {
    
    companion object {
        private const val TAG = "BackgroundService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "voice_assistant_channel"
    }
    
    private lateinit var windowManager: WindowManager
    private lateinit var floatingButton: View
    private var isFloatingButtonVisible = false
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "백그라운드 서비스 생성")
        
        createNotificationChannel()
        setupFloatingButton()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "백그라운드 서비스 시작")
        
        // 포그라운드 서비스로 시작
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Voice Assistant Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "LLM 음성 비서 백그라운드 서비스"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LLM 음성 비서")
            .setContentText("백그라운드에서 음성 인식 중...")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    private fun setupFloatingButton() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // 플로팅 버튼 레이아웃 생성
        floatingButton = LayoutInflater.from(this).inflate(R.layout.floating_button, null)
        
        // 플로팅 버튼 클릭 리스너
        val micButton = floatingButton.findViewById<ImageButton>(R.id.floatingButton)
        micButton.setOnClickListener {
            Log.d(TAG, "플로팅 버튼 클릭됨: 음성인식 시작")
            startVoiceRecognition()
        }
        
        // 닫기 버튼 클릭 리스너
        val closeButton = floatingButton.findViewById<ImageButton>(R.id.closeButton)
        closeButton.setOnClickListener {
            Log.d(TAG, "플로팅 버튼 닫기")
            hideFloatingButton()
        }
    }
    
    fun showFloatingButton() {
        if (!isFloatingButtonVisible) {
            try {
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSLUCENT
                )
                
                params.gravity = Gravity.BOTTOM or Gravity.END
                params.x = 50
                params.y = 100
                
                windowManager.addView(floatingButton, params)
                isFloatingButtonVisible = true
                
                Log.d(TAG, "플로팅 버튼 표시됨")
            } catch (e: Exception) {
                Log.e(TAG, "플로팅 버튼 표시 오류: $e")
            }
        }
    }
    
    fun hideFloatingButton() {
        if (isFloatingButtonVisible) {
            try {
                windowManager.removeView(floatingButton)
                isFloatingButtonVisible = false
                
                Log.d(TAG, "플로팅 버튼 숨김")
            } catch (e: Exception) {
                Log.e(TAG, "플로팅 버튼 숨김 오류: $e")
            }
        }
    }
    
    private fun startVoiceRecognition() {
        Log.d(TAG, "백그라운드 음성 인식 시작")
        
        // Flutter 앱으로 음성 인식 시작 신호 전송
        val intent = Intent("START_VOICE_RECOGNITION")
        sendBroadcast(intent)
        
        // 펄스 애니메이션 시작
        startPulseAnimation()
    }
    
    private fun startPulseAnimation() {
        val micButton = floatingButton.findViewById<ImageButton>(R.id.floatingButton)
        
        // 간단한 펄스 애니메이션
        micButton.animate()
            .scaleX(1.2f)
            .scaleY(1.2f)
            .setDuration(500)
            .withEndAction {
                micButton.animate()
                    .scaleX(1.0f)
                    .scaleY(1.0f)
                    .setDuration(500)
                    .start()
            }
            .start()
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "백그라운드 서비스 종료")
        
        if (isFloatingButtonVisible) {
            hideFloatingButton()
        }
    }
} 