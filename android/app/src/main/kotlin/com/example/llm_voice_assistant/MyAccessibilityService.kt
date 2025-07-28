package com.example.llm_voice_assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

class MyAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "MyAccessibilityService"
        private var instance: MyAccessibilityService? = null
        
        fun getInstance(): MyAccessibilityService? = instance
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "접근성 서비스가 연결되었습니다.")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                Log.d(TAG, "클릭 이벤트 감지")
                processClickEvent(event)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                Log.d(TAG, "화면 내용 변경 감지")
                processContentChange(event)
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                Log.d(TAG, "스크롤 이벤트 감지")
                processScrollEvent(event)
            }
        }
    }
    
    private fun processClickEvent(event: AccessibilityEvent) {
        val source = event.source
        if (source != null) {
            val clickInfo = JSONObject().apply {
                put("type", "click")
                put("text", source.text?.toString() ?: "")
                put("contentDescription", source.contentDescription?.toString() ?: "")
                put("className", source.className?.toString() ?: "")
                put("viewId", source.viewIdResourceName ?: "")
                put("clickable", source.isClickable)
                put("enabled", source.isEnabled)
            }
            
            Log.d(TAG, "클릭 정보: $clickInfo")
            sendToFlutter(clickInfo.toString())
        }
    }
    
    private fun processContentChange(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            val screenInfo = analyzeScreenElements(rootNode)
            Log.d(TAG, "화면 요소 분석: $screenInfo")
            sendToFlutter(screenInfo)
        }
    }
    
    private fun processScrollEvent(event: AccessibilityEvent) {
        val scrollInfo = JSONObject().apply {
            put("type", "scroll")
            put("scrollX", event.scrollX)
            put("scrollY", event.scrollY)
            put("maxScrollX", event.maxScrollX)
            put("maxScrollY", event.maxScrollY)
        }
        
        Log.d(TAG, "스크롤 정보: $scrollInfo")
        sendToFlutter(scrollInfo.toString())
    }
    
    private fun analyzeScreenElements(rootNode: AccessibilityNodeInfo): String {
        val elements = mutableListOf<JSONObject>()
        
        fun traverseNode(node: AccessibilityNodeInfo) {
            if (node != null) {
                val element = JSONObject().apply {
                    put("text", node.text?.toString() ?: "")
                    put("contentDescription", node.contentDescription?.toString() ?: "")
                    put("className", node.className?.toString() ?: "")
                    put("viewId", node.viewIdResourceName ?: "")
                    put("clickable", node.isClickable)
                    put("enabled", node.isEnabled)
                    put("focusable", node.isFocusable)
                    put("focused", node.isFocused)
                    
                    // 좌표 정보
                    val rect = Rect()
                    node.getBoundsInScreen(rect)
                    put("x", rect.centerX())
                    put("y", rect.centerY())
                    put("width", rect.width())
                    put("height", rect.height())
                }
                
                if (node.isClickable || node.text?.isNotEmpty() == true) {
                    elements.add(element)
                }
                
                // 자식 노드들도 탐색
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i)
                    if (child != null) {
                        traverseNode(child)
                        child.recycle()
                    }
                }
            }
        }
        
        traverseNode(rootNode)
        
        val screenInfo = JSONObject().apply {
            put("type", "screen_analysis")
            put("elements", elements)
            put("timestamp", System.currentTimeMillis())
        }
        
        return screenInfo.toString()
    }
    
    fun performVirtualTouch(x: Float, y: Float) {
        Log.d(TAG, "가상 터치 시작: ($x, $y)")
        
        val path = Path()
        path.moveTo(x, y)
        
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 200)) // 터치 시간을 200ms로 증가
            .build()
        
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                Log.d(TAG, "가상 터치 완료: ($x, $y)")
                
                val touchInfo = JSONObject().apply {
                    put("type", "virtual_touch")
                    put("x", x)
                    put("y", y)
                    put("success", true)
                }
                
                sendToFlutter(touchInfo.toString())
            }
            
            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.e(TAG, "가상 터치 취소됨: ($x, $y)")
                
                val touchInfo = JSONObject().apply {
                    put("type", "virtual_touch")
                    put("x", x)
                    put("y", y)
                    put("success", false)
                }
                
                sendToFlutter(touchInfo.toString())
            }
        }, null)
    }

    // 스크롤 액션 실행
    fun performScroll(direction: String) {
        try {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                // 스크롤 가능한 요소 찾기
                val scrollableNode = findScrollableNode(rootNode)
                if (scrollableNode != null) {
                    val scrollAction = if (direction == "up") {
                        AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                    } else {
                        AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                    }
                    
                    val success = scrollableNode.performAction(scrollAction)
                    
                    val scrollInfo = JSONObject().apply {
                        put("type", "scroll")
                        put("direction", direction)
                        put("success", success)
                    }
                    
                    Log.d(TAG, "스크롤 실행 완료: $direction, 성공: $success")
                    sendToFlutter(scrollInfo.toString())
                    
                    scrollableNode.recycle()
                } else {
                    Log.w(TAG, "스크롤 가능한 요소를 찾을 수 없습니다.")
                }
                rootNode.recycle()
            }
        } catch (e: Exception) {
            Log.e(TAG, "스크롤 실행 오류: ${e.message}")
        }
    }

    // 텍스트 입력 액션 실행
    fun performType(text: String) {
        try {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                // 편집 가능한 요소 찾기
                val editableNode = findEditableNode(rootNode)
                if (editableNode != null) {
                    // 기존 텍스트 지우기
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                    editableNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    
                    val typeInfo = JSONObject().apply {
                        put("type", "text_input")
                        put("text", text)
                        put("success", true)
                    }
                    
                    Log.d(TAG, "텍스트 입력 완료: $text")
                    sendToFlutter(typeInfo.toString())
                    
                    editableNode.recycle()
                } else {
                    Log.w(TAG, "편집 가능한 요소를 찾을 수 없습니다.")
                }
                rootNode.recycle()
            }
        } catch (e: Exception) {
            Log.e(TAG, "텍스트 입력 오류: ${e.message}")
        }
    }

    // 스크롤 가능한 요소 찾기
    private fun findScrollableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isScrollable) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val scrollable = findScrollableNode(child)
                if (scrollable != null) {
                    return scrollable
                }
                child.recycle()
            }
        }
        
        return null
    }

    // 편집 가능한 요소 찾기
    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val editable = findEditableNode(child)
                if (editable != null) {
                    return editable
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    private fun sendToFlutter(data: String) {
        // Flutter와 통신하는 방법
        // 실제 구현에서는 MethodChannel을 사용
        Log.d(TAG, "Flutter로 데이터 전송: $data")
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "접근성 서비스가 중단되었습니다.")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "접근성 서비스가 종료되었습니다.")
    }
} 