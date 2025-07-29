import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import 'accessibility_guide_page.dart';
import 'web_browser_page.dart';

class HintProvider extends ChangeNotifier {
  bool _isHintEnabled = false;

  bool get isHintEnabled => _isHintEnabled;

  void toggleHint() {
    _isHintEnabled = !_isHintEnabled;
    notifyListeners();
  }

  void setHintEnabled(bool enabled) {
    _isHintEnabled = enabled;
    notifyListeners();
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VoiceAssistantProvider()),
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProvider(create: (_) => HintProvider()),
      ],
      child: const VoiceAssistantApp(),
    ),
  );
}

class VoiceAssistantApp extends StatelessWidget {
  const VoiceAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LLM 음성 비서 프로토타입',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class HintWidget extends StatelessWidget {
  final String hint;
  final Widget child;

  const HintWidget({super.key, required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<HintProvider>(
      builder: (context, hintProvider, child) {
        if (!hintProvider.isHintEnabled) {
          return this.child;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            this.child,
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // 권한 요청
    await _requestPermissions();

    // 서버 연결 확인
    context.read<ServerProvider>().checkServerConnection();

    // 접근성 서비스 상태 확인
    context.read<AccessibilityProvider>().checkAccessibilityService();
  }

  Future<void> _requestPermissions() async {
    // 마이크 권한
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await Permission.microphone.request();
    }

    // 오버레이 권한 (플로팅 버튼용)
    var overlayStatus = await Permission.systemAlertWindow.status;
    if (!overlayStatus.isGranted) {
      await Permission.systemAlertWindow.request();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갈 때 플로팅 버튼 표시
        context.read<VoiceAssistantProvider>().showFloatingButton();
        break;
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 올 때 플로팅 버튼 숨김
        context.read<VoiceAssistantProvider>().hideFloatingButton();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 LLM 음성 비서 프로토타입'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final provider = context.read<VoiceAssistantProvider>();
              final textToCopy =
                  '인식된 텍스트: ${provider.recognizedText}\n\nAI 응답: ${provider.aiResponse}\n\n신뢰도: ${provider.confidence}';

              // 클립보드에 복사
              await Clipboard.setData(ClipboardData(text: textToCopy));

              // 앱 내부에도 저장
              provider.copyText(textToCopy);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다!')));
            },
            tooltip: '현재 텍스트를 클립보드에 복사',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccessibilityGuidePage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.web),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WebBrowserPage()),
              );
            },
          ),
          Consumer<VoiceAssistantProvider>(
            builder: (context, voiceProvider, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: voiceProvider.isListening
                      ? Colors.red.withOpacity(0.2)
                      : Colors.transparent,
                  boxShadow: voiceProvider.isListening
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: voiceProvider.isListening
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.2),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: GestureDetector(
                              onTap: () {
                                voiceProvider.stopVoiceRecognition();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Colors.red,
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        },
                        onEnd: () {
                          // 애니메이션 반복
                          if (voiceProvider.isListening) {
                            setState(() {});
                          }
                        },
                      )
                    : GestureDetector(
                        onTap: () {
                          voiceProvider.startVoiceRecognition();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.mic_none,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: const MainContent(),
      floatingActionButton: const FloatingActionButton(
        onPressed: null,
        child: Icon(Icons.help),
      ),
    );
  }
}

class MainContent extends StatelessWidget {
  const MainContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<
      VoiceAssistantProvider,
      AccessibilityProvider,
      ServerProvider
    >(
      builder:
          (
            context,
            voiceProvider,
            accessibilityProvider,
            serverProvider,
            child,
          ) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 음성 인식 결과 영역
                  _buildVoiceRecognitionSection(context, voiceProvider),

                  const SizedBox(height: 16),

                  // AI 응답 영역
                  _buildAIResponseSection(context, voiceProvider),

                  const SizedBox(height: 16),

                  // 복사된 텍스트 영역
                  _buildCopiedTextSection(context, voiceProvider),

                  const SizedBox(height: 16),

                  // 상태 표시 영역
                  _buildStatusSection(
                    context,
                    accessibilityProvider,
                    serverProvider,
                  ),

                  const SizedBox(height: 16),

                  // 접근성 서비스 상태
                  _buildAccessibilityStatus(context, accessibilityProvider),

                  const SizedBox(height: 16),

                  // 테스트 그리드
                  _buildTestGrid(context),

                  const SizedBox(height: 16),

                  // 서버 재연결 버튼
                  _buildServerReconnectButton(context, serverProvider),
                ],
              ),
            );
          },
    );
  }

  Widget _buildVoiceRecognitionSection(
    BuildContext context,
    VoiceAssistantProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '🎤 음성 인식 결과',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.recognizedText.isEmpty
                    ? '음성 명령을 말해주세요...'
                    : provider.recognizedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (provider.confidence > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '신뢰도: ${(provider.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: provider.confidence > 0.7
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // 현재 상태 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(provider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(provider), color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.currentStatus,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 상태 표시기
            Row(
              children: [
                _buildStatusIndicator(
                  '항상 듣기',
                  provider.isAlwaysListening,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatusIndicator(
                  '호출어 감지',
                  provider.isListeningForWakeword,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatusIndicator(
                  '명령어 감지',
                  provider.isListeningForCommand,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? color : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(VoiceAssistantProvider provider) {
    if (provider.isListeningForWakeword) return Colors.orange;
    if (provider.isListeningForCommand) return Colors.blue;
    if (provider.isAlwaysListening) return Colors.green;
    if (provider.currentStatus.contains('오류')) return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(VoiceAssistantProvider provider) {
    if (provider.isListeningForWakeword) return Icons.record_voice_over;
    if (provider.isListeningForCommand) return Icons.mic;
    if (provider.isAlwaysListening) return Icons.hearing;
    if (provider.currentStatus.contains('오류')) return Icons.error;
    return Icons.info;
  }

  Widget _buildAIResponseSection(
    BuildContext context,
    VoiceAssistantProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🤖 AI 응답',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.aiResponse.isEmpty
                    ? 'AI 응답이 없습니다.'
                    : provider.aiResponse,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (provider.aiResponse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.copyText(provider.aiResponse);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI 응답이 클립보드에 복사되었습니다.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('복사'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.clearAIResponse();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('지우기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCopiedTextSection(
    BuildContext context,
    VoiceAssistantProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 복사된 텍스트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.copiedText.isEmpty
                    ? '복사된 텍스트가 없습니다.'
                    : provider.copiedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (provider.copiedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.clearCopiedText();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('지우기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    AccessibilityProvider accessibilityProvider,
    ServerProvider serverProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 상태 표시',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  serverProvider.isConnected ? Icons.check_circle : Icons.error,
                  color: serverProvider.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  serverProvider.isConnected ? '서버 연결 성공' : '서버 연결 실패',
                  style: TextStyle(
                    color: serverProvider.isConnected
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  accessibilityProvider.isAccessibilityServiceEnabled
                      ? Icons.check_circle
                      : Icons.error,
                  color: accessibilityProvider.isAccessibilityServiceEnabled
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  accessibilityProvider.isAccessibilityServiceEnabled
                      ? '접근성 서비스 활성화'
                      : '접근성 서비스 비활성화',
                  style: TextStyle(
                    color: accessibilityProvider.isAccessibilityServiceEnabled
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Consumer<VoiceAssistantProvider>(
              builder: (context, voiceProvider, child) {
                return Row(
                  children: [
                    Icon(
                      voiceProvider.isAlwaysListening
                          ? Icons.mic
                          : Icons.mic_off,
                      color: voiceProvider.isAlwaysListening
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      voiceProvider.isAlwaysListening
                          ? '항상 듣기 모드 활성화'
                          : '항상 듣기 모드 비활성화',
                      style: TextStyle(
                        color: voiceProvider.isAlwaysListening
                            ? Colors.green
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              voiceProvider.toggleAlwaysListening(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: voiceProvider.isAlwaysListening
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            voiceProvider.isAlwaysListening ? '끄기' : '켜기',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (context.watch<HintProvider>().isHintEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '"켜기", "끄기"',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityStatus(
    BuildContext context,
    AccessibilityProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  '👁️ 접근성 서비스 상태',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.accessibilityStatus,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestGrid(BuildContext context) {
    final testApps = [
      {'name': 'Google', 'url': 'https://www.google.com'},
      {'name': 'YouTube', 'url': 'https://www.youtube.com'},
      {'name': 'Naver', 'url': 'https://www.naver.com'},
      {'name': 'GitHub', 'url': 'https://github.com'},
      {'name': 'Facebook', 'url': 'https://www.facebook.com'},
      {'name': 'Twitter', 'url': 'https://twitter.com'},
      {'name': 'Instagram', 'url': 'https://www.instagram.com'},
      {'name': 'LinkedIn', 'url': 'https://www.linkedin.com'},
      {'name': 'Reddit', 'url': 'https://www.reddit.com'},
      {'name': 'StackOverflow', 'url': 'https://stackoverflow.com'},
      {'name': 'Wikipedia', 'url': 'https://www.wikipedia.org'},
      {'name': 'Netflix', 'url': 'https://www.netflix.com'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 테스트 그리드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: testApps.length,
              itemBuilder: (context, index) {
                final app = testApps[index];
                return Container(
                  height: 80, // 고정 높이 설정
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // URL로 연결 (웹 브라우저에서 열기)
                              final url = app['url'] as String;
                              final uri = Uri.parse(url);

                              // AI 명령 분석을 통한 웹사이트 접근
                              final response = await http.post(
                                Uri.parse(
                                  'http://192.168.0.171:8000/analyze-command',
                                ),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'command': '${app['name']}로 이동해줘',
                                }),
                              );

                              if (response.statusCode == 200) {
                                final data = jsonDecode(response.body);
                                final aiResponse =
                                    data['response'] ?? '웹사이트로 이동합니다.';

                                // AI 응답을 상태에 저장
                                context.read<VoiceAssistantProvider>().setState(
                                  () {
                                    context
                                            .read<VoiceAssistantProvider>()
                                            .aiResponse =
                                        aiResponse;
                                  },
                                );

                                // 실제 URL 열기
                                try {
                                  print('URL 열기 시도: $url');
                                  final result = await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  print('URL 열기 결과: $result');
                                  if (!result) {
                                    print('URL을 열 수 없습니다: $url');
                                  }
                                } catch (e) {
                                  print('URL 실행 오류: $e');
                                }
                              }
                            } catch (e) {
                              // 오류 처리
                              print('테스트 그리드 오류: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[900],
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          child: Text(
                            app['name'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Expanded(
                          flex: 1,
                          child: Container(
                            width: double.infinity,
                            child: Text(
                              '"${app['name']}"',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // 테스트용 음성 인식 버튼 추가
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context
                            .read<VoiceAssistantProvider>()
                            .startVoiceRecognition(),
                        icon: const Icon(Icons.mic),
                        label: const Text('수동 음성 인식'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"음성인식", "수동음성인식"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context
                            .read<VoiceAssistantProvider>()
                            .testWakeword(),
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('호출어 테스트'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"호출어테스트", "호출어"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 가상 터치 테스트 버튼 추가
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await context
                                .read<VoiceAssistantProvider>()
                                .performVirtualTouch(400.0, 600.0);
                          } catch (e) {
                            // 화면 중앙 터치 오류 처리
                          }
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('중앙 터치'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"중앙터치", "중앙"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await context
                                .read<VoiceAssistantProvider>()
                                .performVirtualTouch(400.0, 200.0);
                          } catch (e) {
                            // 화면 상단 터치 오류 처리
                          }
                        },
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('상단 터치'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"상단터치", "상단"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 항상 듣기 모드 테스트 버튼 추가
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context
                            .read<VoiceAssistantProvider>()
                            .toggleAlwaysListening(),
                        icon: const Icon(Icons.hearing),
                        label: const Text('항상 듣기 토글'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"항상듣기", "토글"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final isEnabled = await context
                              .read<VoiceAssistantProvider>()
                              .checkAccessibilityServiceStatus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEnabled
                                    ? '✅ 접근성 서비스가 활성화되어 있습니다!'
                                    : '❌ 접근성 서비스가 비활성화되어 있습니다.',
                              ),
                              backgroundColor: isEnabled
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        },
                        icon: const Icon(Icons.accessibility),
                        label: const Text('접근성 상태 확인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (context.watch<HintProvider>().isHintEnabled)
                        Container(
                          height: 20,
                          child: Text(
                            '"접근성확인", "접근성상태"',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerReconnectButton(
    BuildContext context,
    ServerProvider provider,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          provider.reconnectServer();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('서버 재연결'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// Provider 클래스들
class VoiceAssistantProvider extends ChangeNotifier {
  static const platform = MethodChannel('voice_assistant_channel');
  String recognizedText = '';
  String aiResponse = '';
  double confidence = 0.0;
  String currentStatus = '대기 중';

  // 텍스트 복사 기능
  String _copiedText = '';

  String get copiedText => _copiedText;

  void copyText(String text) {
    _copiedText = text;
    notifyListeners();
  }

  void clearCopiedText() {
    _copiedText = '';
    notifyListeners();
  }

  // 복잡한 음성인식 시스템
  bool isAlwaysListening = false;
  bool isListeningForWakeword = false;
  bool isListeningForCommand = false;
  bool isListening = false;

  // 플로팅 버튼 상태
  bool _showFloatingButton = false;

  // 항상 듣기 토글
  void toggleAlwaysListening() {
    isAlwaysListening = !isAlwaysListening;
    if (isAlwaysListening) {
      currentStatus = '항상 듣기 모드 활성화';
      _showFloatingButton = true;
      _startAlwaysListening();
    } else {
      currentStatus = '항상 듣기 모드 비활성화';
      _showFloatingButton = false;
      _stopAlwaysListening();
    }
    notifyListeners();
  }

  // 오버레이 힌트 제어
  Future<void> setHintEnabled(bool enabled) async {
    try {
      await platform.invokeMethod('setHintEnabled', {'enabled': enabled});
    } catch (e) {
      // 오버레이 힌트 설정 실패 처리
    }
  }

  // 항상 듣기 시작
  void _startAlwaysListening() {
    _detectWakewordInBackground();
  }

  // 항상 듣기 중지
  void _stopAlwaysListening() {
    isListeningForWakeword = false;
    isListeningForCommand = false;
  }

  // 백그라운드에서 웨이크워드 감지
  void _detectWakewordInBackground() {
    if (!isAlwaysListening) return;

    isListeningForWakeword = true;
    currentStatus = '웨이크워드 감지 중...';
    notifyListeners();

    // 3초마다 웨이크워드 감지
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!isAlwaysListening) {
        timer.cancel();
        return;
      }

      _checkForWakeword();
    });
  }

  // 웨이크워드 확인
  Future<void> _checkForWakeword() async {
    if (!isAlwaysListening || isListeningForCommand) return;

    try {
      // 짧은 녹음으로 웨이크워드 확인
      final result = await platform.invokeMethod('startRecording');

      // 2초 후 녹음 중지
      await Future.delayed(const Duration(seconds: 2));
      final stopResult = await platform.invokeMethod('stopRecording');

      if (stopResult != null && stopResult['success'] == true) {
        final filePath = stopResult['filePath'];
        await _processWakewordDetection(filePath);
      }
    } catch (e) {
      // 웨이크워드 감지 오류 처리
    }
  }

  // 웨이크워드 처리
  Future<void> _processWakewordDetection(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return;
      }

      final audioBytes = await file.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final response = await http
          .post(
            Uri.parse('http://192.168.0.171:8003/speech-to-text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_data': base64Audio,
              'audio_format': 'm4a',
              'check_wakeword': true,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcript = data['transcript'] ?? '';
        final isWakeword = data['is_wakeword'] ?? false;

        if (isWakeword) {
          _onWakewordDetected();
        }
      }
    } catch (e) {
      // 웨이크워드 처리 오류 처리
    }
  }

  // 웨이크워드 감지 시 실행
  void _onWakewordDetected() {
    isListeningForWakeword = false;
    isListeningForCommand = true;
    currentStatus = '명령을 말씀해주세요...';
    notifyListeners();

    // 명령 녹음 시작
    _startCommandRecording();
  }

  // 명령 녹음 시작
  Future<void> _startCommandRecording() async {
    try {
      final result = await platform.invokeMethod('startRecording');

      // 5초 후 자동 중지
      await Future.delayed(const Duration(seconds: 5));
      await _stopCommandRecording();
    } catch (e) {
      _resetListeningState();
    }
  }

  // 명령 녹음 중지 및 처리
  Future<void> _stopCommandRecording() async {
    try {
      final result = await platform.invokeMethod('stopRecording');

      if (result != null && result['success'] == true) {
        final filePath = result['filePath'];
        await _processVoiceRecognition(filePath);
      }

      _resetListeningState();
    } catch (e) {
      _resetListeningState();
    }
  }

  // 리스닝 상태 초기화
  void _resetListeningState() {
    isListeningForCommand = false;
    if (isAlwaysListening) {
      isListeningForWakeword = true;
      currentStatus = '웨이크워드 감지 중...';
    } else {
      currentStatus = '대기 중';
    }
    notifyListeners();
  }

  // 접근성 서비스 상태 확인 (개선된 버전)
  Future<bool> _checkAccessibilityService() async {
    try {
      final result = await platform.invokeMethod('checkAccessibilityService');
      final isEnabled = result ?? false;

      if (isEnabled) {
        currentStatus = '접근성 서비스 활성화됨';
      } else {
        currentStatus = '접근성 서비스 비활성화됨 - 설정에서 활성화 필요';
        aiResponse = '접근성 서비스를 활성화해주세요. 설정 → 접근성 → LLM 음성 비서';
      }

      return isEnabled;
    } catch (e) {
      currentStatus = '접근성 서비스 확인 오류';
      aiResponse = '접근성 서비스 확인 중 오류가 발생했습니다.';
      return false;
    }
  }

  // 터치 피드백 제공
  Future<void> _provideTouchFeedback(String target, double x, double y) async {
    try {
      // TTS 피드백 (서버에 요청)
      final response = await http
          .post(
            Uri.parse('http://192.168.0.171:8000/tts'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': '$target을 클릭했습니다.'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {}
    } catch (e) {
      // 터치 피드백 오류 처리
    }
  }

  // 스크롤 액션 실행 (개선된 버전)
  Future<void> _performScrollAction(String target) async {
    try {
      // 스크롤 방향 결정 (더 많은 명령어 지원)
      String direction = 'down';
      String targetLower = target.toLowerCase();

      // 방향 감지 로직
      if (targetLower.contains('위') ||
          targetLower.contains('up') ||
          targetLower.contains('올려') ||
          targetLower.contains('위로')) {
        direction = 'up';
      } else if (targetLower.contains('아래') ||
          targetLower.contains('down') ||
          targetLower.contains('내려') ||
          targetLower.contains('아래로')) {
        direction = 'down';
      } else {
        // 방향 정보가 없는 경우 예외 처리
        aiResponse = '스크롤 방향을 명확히 말해주세요. (위/아래)';
        currentStatus = '스크롤 방향 불명확';
        return;
      }

      // 스크롤 양 결정 (명령어에 따라 조절)
      int scrollAmount = 300; // 기본값

      // 스크롤 양 조절 키워드 감지 (확장된 부사형 단어)
      if (targetLower.contains('많이') ||
          targetLower.contains('크게') ||
          targetLower.contains('강하게') ||
          targetLower.contains('무겁게') ||
          targetLower.contains('빠르게')) {
        scrollAmount = 600; // 많이 스크롤
      } else if (targetLower.contains('조금') ||
          targetLower.contains('살짝') ||
          targetLower.contains('적게') ||
          targetLower.contains('약하게') ||
          targetLower.contains('가볍게') ||
          targetLower.contains('천천히') ||
          targetLower.contains('느리게')) {
        scrollAmount = 150; // 조금 스크롤
      } else if (targetLower.contains('한번') ||
          targetLower.contains('한 번') ||
          targetLower.contains('쭉')) {
        scrollAmount = 400; // 한 번 스크롤
      } else if (targetLower.contains('부드럽게') || targetLower.contains('조용히')) {
        scrollAmount = 250; // 부드럽게 스크롤
      }

      // 네이티브 스크롤 실행 (양 포함)
      await platform.invokeMethod('performScroll', {
        'direction': direction,
        'scrollAmount': scrollAmount,
      });

      aiResponse = '$direction 방향으로 스크롤했습니다.';
      currentStatus = '스크롤 완료';
    } catch (e) {
      aiResponse = '스크롤 실행 중 오류가 발생했습니다: $e';
      currentStatus = '스크롤 오류';
    }
  }

  // 텍스트 입력 액션 실행
  Future<void> _performTypeAction(String target) async {
    try {
      // 텍스트 추출 (명령에서 텍스트 부분 파싱)
      String textToType = target;
      if (target.contains('입력') || target.contains('쓰기')) {
        // "안녕하세요 입력해줘" -> "안녕하세요"
        textToType = target.replaceAll('입력해줘', '').replaceAll('쓰기', '').trim();
      }

      // 네이티브 텍스트 입력 실행
      await platform.invokeMethod('performType', {'text': textToType});

      aiResponse = '"$textToType"을 입력했습니다.';
      currentStatus = '텍스트 입력 완료';
    } catch (e) {
      aiResponse = '텍스트 입력 중 오류가 발생했습니다.';
      currentStatus = '텍스트 입력 오류';
    }
  }

  // 플로팅 버튼 표시
  void showFloatingButton() {
    _showFloatingButton = true;
    notifyListeners();
  }

  // 플로팅 버튼 숨김
  void hideFloatingButton() {
    _showFloatingButton = false;
    notifyListeners();
  }

  // 웨이크워드 테스트
  void testWakeword() {
    isListeningForWakeword = true;
    currentStatus = '웨이크워드 감지 중...';
    notifyListeners();

    // 3초 후 자동으로 중지
    Future.delayed(const Duration(seconds: 3), () {
      isListeningForWakeword = false;
      currentStatus = '웨이크워드 테스트 완료';
      notifyListeners();
    });
  }

  // 수동 음성 녹음 테스트
  Future<void> startVoiceRecognition() async {
    if (isListening) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // 음성 인식 중지 (외부에서 호출 가능)
  Future<void> stopVoiceRecognition() async {
    if (isListening) {
      await _stopRecording();
    }
  }

  // 녹음 시작 (개선된 버전)
  Future<void> _startRecording() async {
    try {
      // 마이크 권한 확인
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        var result = await Permission.microphone.request();
        if (!result.isGranted) {
          setState(() {
            recognizedText = '❌ 마이크 권한이 필요합니다.';
            currentStatus = '권한 오류';
          });
          return;
        }
      }

      setState(() {
        isListening = true;
        currentStatus = '음성 인식 중... (버튼을 다시 누르면 중지)';
      });

      // Android 네이티브 녹음 시작
      final result = await platform.invokeMethod('startRecording');

      // 실시간 볼륨 모니터링 시작 (백그라운드에서)
      _startVolumeMonitoring();
    } catch (e) {
      setState(() {
        isListening = false;
        currentStatus = '녹음 오류: $e';
      });
    }
  }

  // 실시간 볼륨 모니터링
  Timer? _volumeTimer;
  DateTime? _lastVoiceTime;
  bool _isSilent = false;

  void _startVolumeMonitoring() {
    _lastVoiceTime = DateTime.now();
    _isSilent = false;

    _volumeTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!isListening) {
        timer.cancel();
        return;
      }

      // 무음 감지 (2초 이상 무음이면 자동 정지)
      if (_lastVoiceTime != null) {
        final silenceDuration = DateTime.now().difference(_lastVoiceTime!);
        if (silenceDuration.inSeconds >= 2 && !_isSilent) {
          await _stopRecording();
          _volumeTimer?.cancel();
        }
      }
    });
  }

  void _stopVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
  }

  // 녹음 중지 (개선된 버전)
  Future<void> _stopRecording() async {
    try {
      // 볼륨 모니터링 중지
      _stopVolumeMonitoring();

      setState(() {
        isListening = false;
        currentStatus = '음성 분석 중...';
      });

      // Android 네이티브 녹음 중지
      final result = await platform.invokeMethod('stopRecording');

      if (result != null && result['success'] == true) {
        final filePath = result['filePath'];
        final fileSize = result['fileSize'];

        // 파일 크기 검증 (1KB 이상)
        if (fileSize > 1024) {
          // 음성 품질 검증 추가
          final isValidAudio = await _validateAudioQuality(filePath, fileSize);
          if (isValidAudio) {
            // 실제 음성 인식 처리
            await _processVoiceRecognition(filePath);
          } else {
            setState(() {
              recognizedText = '❌ 음성 품질이 좋지 않습니다. 다시 말씀해주세요.';
              currentStatus = '음성 품질 오류';
            });
          }
        } else {
          setState(() {
            recognizedText = '❌ 녹음 파일이 너무 작습니다. (${fileSize} bytes) 다시 시도해주세요.';
            currentStatus = '녹음 파일 오류';
          });
        }
      } else {
        setState(() {
          recognizedText = '❌ 녹음에 실패했습니다.';
          currentStatus = '녹음 실패';
        });
      }
    } catch (e) {
      setState(() {
        isListening = false;
        currentStatus = '녹음 중지 오류';
      });
    }
  }

  // 음성 품질 검증
  Future<bool> _validateAudioQuality(String filePath, int fileSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // 파일 크기 검증 (최소 2KB, 최대 10MB)
      if (fileSize < 2048 || fileSize > 10 * 1024 * 1024) {
        return false;
      }

      // 파일 확장자 검증
      final extension = filePath.split('.').last.toLowerCase();
      if (extension != 'm4a' && extension != 'wav') {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 실제 음성 인식 처리
  Future<void> _processVoiceRecognition(String filePath) async {
    try {
      setState(() {
        currentStatus = '음성 분석 중...';
      });

      // 오디오 파일 읽기
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      // 디버깅: 파일 정보 출력
      print('🔍 [DEBUG] 오디오 파일 정보:');
      print('   📁 파일 경로: $filePath');
      print('   📏 파일 크기: ${bytes.length} bytes');
      print('   📄 파일 확장자: ${filePath.split('.').last.toLowerCase()}');
      print('   🔢 Base64 길이: ${base64Audio.length}');

      // 파일 확장자로 실제 형식 판단
      final fileExtension = filePath.split('.').last.toLowerCase();
      final audioFormat = 'm4a'; // MediaRecorder에서 MPEG_4 사용하므로 항상 m4a

      print('🎤 [DEBUG] 서버로 음성 인식 요청 전송...');
      print('   🌐 서버 URL: http://192.168.0.171:8000/speech-to-text');
      print('   📊 오디오 형식: $audioFormat');

      // 1단계: 음성 인식 (Speech-to-Text)
      final sttResponse = await http
          .post(
            Uri.parse('http://192.168.0.171:8000/speech-to-text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_data': base64Audio,
              'audio_format': audioFormat,
              'check_wakeword': false, // 명시적으로 추가
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 [DEBUG] 서버 응답 수신:');
      print('   📊 상태 코드: ${sttResponse.statusCode}');
      print('   📄 응답 본문: ${sttResponse.body}');

      if (sttResponse.statusCode == 200) {
        final sttData = jsonDecode(sttResponse.body);
        final transcript = sttData['transcript'] ?? '';
        final confidence = sttData['confidence'] ?? 0.0;

        print('🎯 [DEBUG] 음성 인식 결과:');
        print('   🎤 인식된 텍스트: "$transcript"');
        print('   📈 신뢰도: ${(confidence * 100).toStringAsFixed(1)}%');

        if (transcript.isNotEmpty && confidence > 0.3) {
          print('🤖 [DEBUG] AI 명령 분석 시작...');
          print('   📝 분석할 명령: "$transcript"');

          // 2단계: Gemini AI 명령 분석
          final aiResponse = await http
              .post(
                Uri.parse('http://192.168.0.171:8000/analyze-command'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'command': transcript}),
              )
              .timeout(const Duration(seconds: 30));

          print('📡 [DEBUG] AI 분석 응답:');
          print('   📊 상태 코드: ${aiResponse.statusCode}');
          print('   📄 응답 본문: ${aiResponse.body}');

          if (aiResponse.statusCode == 200) {
            final aiData = jsonDecode(aiResponse.body);
            final action = aiData['action'] ?? 'touch';
            final target = aiData['target'] ?? 'unknown';
            final coordinates = aiData['coordinates'] ?? {'x': 200, 'y': 300};
            final response = aiData['response'] ?? '명령을 처리하겠습니다.';

            print('🎯 [DEBUG] AI 분석 결과:');
            print('   🎬 액션: $action');
            print('   🎯 타겟: $target');
            print('   📍 좌표: $coordinates');
            print('   💬 응답: $response');

            // 3단계: 가상 터치 실행 (개선된 버전)
            if (action == 'touch' && coordinates != null) {
              final x = coordinates['x']?.toDouble() ?? 200.0;
              final y = coordinates['y']?.toDouble() ?? 300.0;

              try {
                // 접근성 서비스 상태 확인
                final isAccessibilityEnabled =
                    await _checkAccessibilityService();
                if (!isAccessibilityEnabled) {
                  setState(() {
                    this.aiResponse = '접근성 서비스를 활성화해주세요.';
                    currentStatus = '접근성 서비스 오류';
                  });
                  return;
                }

                // 가상 터치 실행
                await platform.invokeMethod('performVirtualTouch', {
                  'x': x,
                  'y': y,
                });

                // 터치 피드백 제공
                await _provideTouchFeedback(target, x, y);
              } catch (e) {
                setState(() {
                  this.aiResponse = '터치 실행 중 오류가 발생했습니다.';
                  currentStatus = '터치 실행 오류';
                });
              }
            } else if (action == 'scroll') {
              // 스크롤 액션 처리
              await _performScrollAction(target);
            } else if (action == 'type') {
              // 텍스트 입력 액션 처리
              await _performTypeAction(target);
            }

            setState(() {
              recognizedText = '🎤 "$transcript"';
              this.aiResponse = response;
              currentStatus = '명령 실행 완료';
              this.confidence = confidence.toDouble();
            });
          } else {
            setState(() {
              recognizedText = '🎤 "$transcript"';
              this.aiResponse = 'AI 분석 중 오류가 발생했습니다.';
              currentStatus = 'AI 분석 실패';
              this.confidence = confidence.toDouble();
            });
          }
        } else {
          setState(() {
            recognizedText = '🎤 음성을 인식할 수 없습니다.';
            this.aiResponse = '음성을 다시 말씀해주세요.';
            currentStatus = '음성 인식 실패';
            this.confidence = confidence.toDouble();
          });
        }
      } else {
        setState(() {
          recognizedText = '🎤 "안녕하세요, 이것은 테스트 음성입니다."';
          aiResponse = '음성을 인식했습니다! (서버 연결 실패로 시뮬레이션)';
          currentStatus = '음성 인식 완료 (시뮬레이션)';
          confidence = 0.95;
        });
      }
    } catch (e) {
      setState(() {
        recognizedText = '🎤 "안녕하세요, 이것은 테스트 음성입니다."';
        aiResponse = '음성을 인식했습니다! (오류로 시뮬레이션)';
        currentStatus = '음성 인식 완료 (시뮬레이션)';
        confidence = 0.95;
      });
    }
  }

  // 가상 터치 실행
  Future<void> performVirtualTouch(double x, double y) async {
    try {
      final result = await platform.invokeMethod('performVirtualTouch', {
        'x': x,
        'y': y,
      });
    } catch (e) {
      throw e;
    }
  }

  // 가상 터치 시뮬레이션
  void simulateTouch(int index) {
    // 실제 구현에서는 네이티브 코드와 통신
  }

  // 접근성 서비스 상태 확인
  Future<bool> checkAccessibilityServiceStatus() async {
    try {
      final result = await platform.invokeMethod('checkAccessibilityService');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  void clearAIResponse() {
    aiResponse = '';
    notifyListeners();
  }

  @override
  void dispose() {
    // 타이머 정리
    _volumeTimer?.cancel();
    _volumeTimer = null;

    // 상태 초기화
    isListening = false;
    isListeningForWakeword = false;
    isListeningForCommand = false;
    isAlwaysListening = false;

    super.dispose();
  }
}

class AccessibilityProvider extends ChangeNotifier {
  bool isAccessibilityServiceEnabled = false;
  String accessibilityStatus = '접근성 서비스 상태 확인 중...';

  Future<void> checkAccessibilityService() async {
    // 접근성 서비스 상태 확인
    // 실제 구현에서는 네이티브 코드와 통신
    setState(() {
      isAccessibilityServiceEnabled = true;
      accessibilityStatus = '접근성 이벤트 수신 중...';
    });
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}

class ServerProvider extends ChangeNotifier {
  bool isConnected = false;
  String serverStatus = '서버 연결 확인 중...';

  Future<void> checkServerConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.0.171:8000/health'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        isConnected = response.statusCode == 200;
        serverStatus = isConnected ? '서버 연결 성공' : '서버 연결 실패';
      });
    } catch (e) {
      setState(() {
        isConnected = false;
        serverStatus = '서버 연결 실패: $e';
      });
    }
  }

  Future<void> reconnectServer() async {
    setState(() {
      serverStatus = '서버 재연결 시도 중...';
    });

    await checkServerConnection();
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}
