package com.example.llm_voice_assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Path
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.TextView
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

class MyAccessibilityService : AccessibilityService() {
    private var windowManager: WindowManager? = null
    private var hintViews = mutableListOf<View>()
    private var isHintEnabled = false
    private var lastScreenHash = 0
    private val updateHandler = Handler(Looper.getMainLooper())
    private val updateRunnable = Runnable { updateHintsIfNeeded() }
    
    companion object {
        private const val TAG = "MyAccessibilityService"
        var instance: MyAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        val info = AccessibilityServiceInfo()
        info.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        serviceInfo = info
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED,
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_VIEW_SELECTED -> {
                if (isHintEnabled) {
                    // UI 변경 감지 시 지연된 업데이트 예약
                    scheduleHintUpdate()
                }
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                // 클릭 이벤트 발생 시 힌트 숨기기
                hideAllHints()
            }
        }
    }

    override fun onInterrupt() {
        // 서비스 중단 시 힌트 정리
        hideAllHints()
        updateHandler.removeCallbacks(updateRunnable)
    }

    override fun onDestroy() {
        super.onDestroy()
        hideAllHints()
        updateHandler.removeCallbacks(updateRunnable)
        instance = null
    }

    fun setHintEnabled(enabled: Boolean) {
        isHintEnabled = enabled
        if (enabled) {
            updateHintsIfNeeded()
        } else {
            hideAllHints()
        }
    }

    private fun scheduleHintUpdate() {
        // 이전 예약된 업데이트 취소
        updateHandler.removeCallbacks(updateRunnable)
        // 500ms 후에 업데이트 실행 (UI 변경이 완료된 후)
        updateHandler.postDelayed(updateRunnable, 500)
    }

    private fun updateHintsIfNeeded() {
        val rootNode = rootInActiveWindow ?: return
        val currentHash = calculateScreenHash(rootNode)
        
        // 화면 구조가 변경된 경우에만 힌트 업데이트
        if (currentHash != lastScreenHash) {
            lastScreenHash = currentHash
            showHintsForClickableElements()
        }
    }

    private fun calculateScreenHash(rootNode: AccessibilityNodeInfo): Int {
        val elements = mutableListOf<String>()
        collectElementInfo(rootNode, elements)
        return elements.joinToString("|").hashCode()
    }

    private fun collectElementInfo(node: AccessibilityNodeInfo, elements: MutableList<String>) {
        if (node.isClickable && node.isEnabled) {
            val text = node.text?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            val rect = Rect()
            node.getBoundsInScreen(rect)
            
            elements.add("${text}_${contentDesc}_${rect.left}_${rect.top}_${rect.width()}_${rect.height()}")
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectElementInfo(child, elements)
            child.recycle()
        }
    }

    private fun showHintsForClickableElements() {
        hideAllHints()
        
        val rootNode = rootInActiveWindow ?: return
        val clickableElements = findClickableElements(rootNode)
        
        for (element in clickableElements) {
            val hintText = generateHintText(element)
            if (hintText.isNotEmpty()) {
                showHintOverlay(element, hintText)
            }
        }
    }

    private fun findClickableElements(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val elements = mutableListOf<AccessibilityNodeInfo>()
        
        if (node.isClickable && node.isEnabled) {
            elements.add(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            elements.addAll(findClickableElements(child))
            child.recycle()
        }
        
        return elements
    }

    private fun generateHintText(element: AccessibilityNodeInfo): String {
        val text = element.text?.toString() ?: ""
        val contentDesc = element.contentDescription?.toString() ?: ""
        
        return when {
            text.isNotEmpty() -> "\"$text\""
            contentDesc.isNotEmpty() -> "\"$contentDesc\""
            else -> ""
        }
    }

    private fun showHintOverlay(element: AccessibilityNodeInfo, hintText: String) {
        val rect = Rect()
        element.getBoundsInScreen(rect)
        
        if (rect.width() == 0 || rect.height() == 0) return
        
        val hintView = createHintView(hintText)
        val params = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = rect.left
            y = rect.bottom + 10
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.START
        }
        
        try {
            windowManager?.addView(hintView, params)
            hintViews.add(hintView)
        } catch (e: Exception) {
            Log.e(TAG, "힌트 오버레이 표시 실패: ${e.message}")
        }
    }

    private fun createHintView(hintText: String): View {
        val hintView = TextView(this).apply {
            text = hintText
            setTextColor(0xFF666666.toInt())
            textSize = 10f
            setPadding(8, 4, 8, 4)
            setBackgroundColor(0x80FFFFFF.toInt())
            alpha = 0.8f
        }
        return hintView
    }

    private fun hideAllHints() {
        for (view in hintViews) {
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
                Log.e(TAG, "힌트 오버레이 제거 실패: ${e.message}")
            }
        }
        hintViews.clear()
    }

    // 기존 스크롤 기능
    fun performScroll(direction: String, scrollAmount: Int = 300) {
        val rootNode = rootInActiveWindow ?: return
        
        when (direction.lowercase()) {
            "up", "올려" -> performSmoothScroll(rootNode, scrollAmount, true)
            "down", "내려" -> performSmoothScroll(rootNode, scrollAmount, false)
            else -> performSmoothScroll(rootNode, scrollAmount, false)
        }
    }

    private fun performSmoothScroll(rootNode: AccessibilityNodeInfo, scrollAmount: Int, isUp: Boolean) {
        val screenHeight = resources.displayMetrics.heightPixels
        val centerX = resources.displayMetrics.widthPixels / 2
        val startY = if (isUp) screenHeight * 3 / 4 else screenHeight / 4
        val endY = if (isUp) screenHeight / 4 else screenHeight * 3 / 4
        
        val path = Path().apply {
            moveTo(centerX.toFloat(), startY.toFloat())
            quadTo(centerX.toFloat(), (startY + endY) / 2f, centerX.toFloat(), endY.toFloat())
        }
        
        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 500))
        
        val gesture = gestureBuilder.build()
        dispatchGesture(gesture, null, null)
    }

    // 기존 터치 기능
    fun performTouch(x: Float, y: Float) {
        val path = Path()
        path.moveTo(x, y)
        
        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
        
        val gesture = gestureBuilder.build()
        dispatchGesture(gesture, null, null)
    }

    // 기존 텍스트 입력 기능
    fun performTextInput(text: String) {
        val rootNode = rootInActiveWindow ?: return
        
        val editableNodes = findEditableNodes(rootNode)
        if (editableNodes.isNotEmpty()) {
            val firstEditable = editableNodes.first()
            val bundle = android.os.Bundle()
            bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            firstEditable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
        }
    }

    private fun findEditableNodes(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val nodes = mutableListOf<AccessibilityNodeInfo>()
        
        if (node.isEditable) {
            nodes.add(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            nodes.addAll(findEditableNodes(child))
            child.recycle()
        }
        
        return nodes
    }
} 