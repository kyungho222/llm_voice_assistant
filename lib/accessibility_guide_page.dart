import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AccessibilityGuidePage extends StatefulWidget {
  const AccessibilityGuidePage({Key? key}) : super(key: key);

  @override
  State<AccessibilityGuidePage> createState() => _AccessibilityGuidePageState();
}

class _AccessibilityGuidePageState extends State<AccessibilityGuidePage> {
  bool isAccessibilityEnabled = false;
  bool isOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final overlayStatus = await Permission.systemAlertWindow.status;
    
    setState(() {
      // 접근성 서비스는 앱에서 직접 확인할 수 없으므로 시뮬레이션
      isAccessibilityEnabled = false; // 실제로는 네이티브 코드로 확인 필요
      isOverlayEnabled = overlayStatus.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('접근성 서비스 설정'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 접근성 서비스 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAccessibilityEnabled ? Icons.check_circle : Icons.error,
                          color: isAccessibilityEnabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '접근성 서비스',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAccessibilityEnabled 
                        ? '✅ 접근성 서비스가 활성화되어 있습니다.'
                        : '❌ 접근성 서비스가 비활성화되어 있습니다.',
                      style: TextStyle(
                        color: isAccessibilityEnabled ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '접근성 서비스 활성화 방법:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. 설정 → 접근성 → 사용 중인 서비스'),
                    const Text('2. "LLM Voice Assistant" 찾기'),
                    const Text('3. 토글을 켜서 활성화'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // 설정 앱으로 이동
                          openAppSettings();
                        },
                        child: const Text('설정으로 이동'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 오버레이 권한 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOverlayEnabled ? Icons.check_circle : Icons.error,
                          color: isOverlayEnabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '오버레이 권한',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOverlayEnabled 
                        ? '✅ 오버레이 권한이 허용되어 있습니다.'
                        : '❌ 오버레이 권한이 거부되어 있습니다.',
                      style: TextStyle(
                        color: isOverlayEnabled ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '오버레이 권한 허용 방법:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. 설정 → 앱 → LLM Voice Assistant'),
                    const Text('2. 권한 → 다른 앱 위에 표시'),
                    const Text('3. 허용으로 설정'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Permission.systemAlertWindow.request();
                          _checkPermissions();
                        },
                        child: const Text('권한 요청'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 기능 설명
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 필요한 권한 설명',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '접근성 서비스:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• 화면의 UI 요소를 읽고 분석'),
                    const Text('• 가상 터치 및 제스처 수행'),
                    const Text('• 다른 앱과 상호작용'),
                    const SizedBox(height: 8),
                    const Text(
                      '오버레이 권한:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• 플로팅 버튼 표시'),
                    const Text('• 백그라운드에서 음성 인식'),
                    const Text('• 다른 앱 위에 UI 표시'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 테스트 버튼
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧪 권한 테스트',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _checkPermissions();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isAccessibilityEnabled && isOverlayEnabled
                                      ? '모든 권한이 정상적으로 설정되었습니다!'
                                      : '일부 권한이 설정되지 않았습니다.',
                                  ),
                                  backgroundColor: isAccessibilityEnabled && isOverlayEnabled
                                    ? Colors.green
                                    : Colors.orange,
                                ),
                              );
                            },
                            child: const Text('권한 상태 확인'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('돌아가기'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 