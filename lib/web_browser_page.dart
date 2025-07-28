import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WebBrowserPage extends StatefulWidget {
  const WebBrowserPage({Key? key}) : super(key: key);

  @override
  State<WebBrowserPage> createState() => _WebBrowserPageState();
}

class _WebBrowserPageState extends State<WebBrowserPage> {
  String currentUrl = 'https://www.google.com';
  String recognizedText = '';
  String aiResponse = '';
  bool isListening = false;
  String currentPageContent = 'Google 홈페이지가 로드되었습니다.';

  final List<Map<String, String>> popularSites = [
    {'name': 'Google', 'url': 'https://www.google.com', 'content': 'Google 검색 페이지입니다.'},
    {'name': 'YouTube', 'url': 'https://www.youtube.com', 'content': 'YouTube 동영상 페이지입니다.'},
    {'name': 'Naver', 'url': 'https://www.naver.com', 'content': 'Naver 포털 페이지입니다.'},
    {'name': 'GitHub', 'url': 'https://www.github.com', 'content': 'GitHub 개발자 플랫폼입니다.'},
    {'name': 'Stack Overflow', 'url': 'https://stackoverflow.com', 'content': 'Stack Overflow 개발자 커뮤니티입니다.'},
    {'name': 'Wikipedia', 'url': 'https://www.wikipedia.org', 'content': 'Wikipedia 백과사전입니다.'},
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _processVoiceCommand(String command) async {
    setState(() {
      recognizedText = command;
      isListening = false;
    });

    try {
      // 백엔드 서버로 음성 명령 전송
      final response = await http.post(
        Uri.parse('http://192.168.219.109:8000/process_voice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': command,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          aiResponse = data['response'] ?? '명령을 처리했습니다.';
        });

        // AI 응답에 따른 웹페이지 제어
        _executeWebCommand(data['action'] ?? 'navigate', data['parameters'] ?? {});
      }
    } catch (e) {
      setState(() {
        aiResponse = '오류가 발생했습니다: $e';
      });
    }
  }

  void _executeWebCommand(String action, Map<String, dynamic> parameters) {
    switch (action) {
      case 'navigate':
        _navigateToUrl(parameters['url'] ?? 'https://www.google.com');
        break;
      case 'click':
        _clickElement(parameters['selector'] ?? 'button');
        break;
      case 'type':
        _typeText(parameters['selector'] ?? 'input', parameters['text'] ?? '');
        break;
      case 'scroll':
        _scrollPage(parameters['direction'] ?? 'down');
        break;
      case 'back':
        _goBack();
        break;
      case 'forward':
        _goForward();
        break;
      case 'refresh':
        _refreshPage();
        break;
    }
  }

  void _navigateToUrl(String url) {
    setState(() {
      currentUrl = url;
      // 실제 웹사이트에 맞는 콘텐츠 설정
      for (var site in popularSites) {
        if (site['url'] == url) {
          currentPageContent = site['content']!;
          break;
        }
      }
      aiResponse = '$url로 이동했습니다.';
    });
  }

  void _clickElement(String selector) {
    setState(() {
      aiResponse = '$selector 요소를 클릭했습니다.';
    });
  }

  void _typeText(String selector, String text) {
    setState(() {
      aiResponse = '$selector에 "$text"를 입력했습니다.';
    });
  }

  void _scrollPage(String direction) {
    setState(() {
      aiResponse = '페이지를 $direction 방향으로 스크롤했습니다.';
    });
  }

  void _goBack() {
    setState(() {
      aiResponse = '이전 페이지로 이동했습니다.';
    });
  }

  void _goForward() {
    setState(() {
      aiResponse = '다음 페이지로 이동했습니다.';
    });
  }

  void _refreshPage() {
    setState(() {
      aiResponse = '페이지를 새로고침했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음성 제어 웹 브라우저'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isListening ? Icons.mic : Icons.mic_off),
            onPressed: () {
              setState(() {
                isListening = !isListening;
              });
              if (isListening) {
                _startVoiceRecognition();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 인기 사이트 버튼들
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: popularSites.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToUrl(popularSites[index]['url']!);
                    },
                    child: Text(popularSites[index]['name']!),
                  ),
                );
              },
            ),
          ),
          
          // 음성 인식 결과 표시
          if (recognizedText.isNotEmpty || aiResponse.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recognizedText.isNotEmpty)
                    Text('음성 인식: $recognizedText', 
                         style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (aiResponse.isNotEmpty)
                    Text('AI 응답: $aiResponse', 
                         style: const TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          
          // 웹페이지 시뮬레이션
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // 브라우저 주소창
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.lock, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentUrl,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _refreshPage,
                        ),
                      ],
                    ),
                  ),
                  
                  // 웹페이지 콘텐츠
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentPageContent,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '이 페이지는 음성 명령으로 제어할 수 있습니다:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text('• "구글 검색창에 안드로이드 개발 입력해줘"'),
                          const Text('• "유튜브로 이동해줘"'),
                          const Text('• "페이지 새로고침해줘"'),
                          const Text('• "아래로 스크롤해줘"'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isListening = !isListening;
          });
          if (isListening) {
            _startVoiceRecognition();
          }
        },
        child: Icon(isListening ? Icons.stop : Icons.mic),
        backgroundColor: isListening ? Colors.red : Colors.blue,
      ),
    );
  }

  void _startVoiceRecognition() {
    // 음성 인식 시작 (실제 구현에서는 음성 인식 API 사용)
    setState(() {
      isListening = true;
    });
    
    // 시뮬레이션용 - 실제로는 음성 인식 결과를 받아옴
    Future.delayed(const Duration(seconds: 2), () {
      _processVoiceCommand('구글 검색창에 안드로이드 개발 입력해줘');
    });
  }
} 