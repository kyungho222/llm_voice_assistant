# 🎤 LLM 음성 비서 프로토타입

Android 접근성 서비스를 활용한 스마트폰 화면 요소 음성 인식 및 가상 터치 시스템

## 📱 프로젝트 개요

이 프로젝트는 **Flutter**와 **Android 접근성 서비스**를 결합하여 음성 명령으로 스마트폰 화면을 제어하는 AI 비서 시스템입니다.

### 🎯 주요 기능
- **호출어 감지**: "하이프로" 호출어로 음성 인식 시작
- **음성 명령 분석**: Google Gemini를 활용한 자연어 처리
- **가상 터치**: 접근성 서비스를 통한 화면 요소 제어
- **백그라운드 서비스**: 플로팅 버튼으로 언제든지 접근 가능
- **실시간 음성 인식**: Google Cloud Speech-to-Text 연동
- **오디오 전처리**: ffmpeg를 통한 노이즈 제거 및 볼륨 증폭
- **AI 후처리**: 인식된 텍스트의 오류 보정 및 문맥 개선
- **텍스트 복사**: 긴 AI 응답을 클립보드로 복사

## 🏗️ 기술 스택

### Frontend (Flutter)
- **Flutter 3.8.1+** - 크로스 플랫폼 UI 프레임워크
- **Provider** - 상태 관리
- **flutter_sound** - 음성 녹음
- **permission_handler** - 권한 관리
- **http/dio** - HTTP 통신

### Backend (Python)
- **Flask** - 웹 서버
- **Google Cloud Speech-to-Text** - 음성 인식
- **Google Gemini** - 자연어 처리
- **ffmpeg** - 오디오 형식 변환 및 전처리

### Android Native
- **AccessibilityService** - 화면 요소 감지 및 제어
- **BackgroundService** - 백그라운드 플로팅 버튼
- **MethodChannel** - Flutter-Native 통신
- **MediaRecorder** - 네이티브 오디오 녹음

## 🚀 설치 및 실행

### 1. 환경 설정

#### Flutter 개발 환경
```bash
# Flutter SDK 설치 확인
flutter doctor

# 의존성 설치
flutter pub get
```

#### Python 백엔드 환경
```bash
# 루트 폴더에서 실행
pip install -r backend/requirements.txt

# ffmpeg 설치 (오디오 변환용)
# Windows: https://ffmpeg.org/download.html
# macOS: brew install ffmpeg
# Ubuntu: sudo apt install ffmpeg
```

### 2. API 키 설정

#### Google Cloud Speech-to-Text
1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트 생성
2. Speech-to-Text API 활성화
3. 서비스 계정 키 생성 후 `backend/teak-mix-466716-h0-3fc9e37b08ce.json`에 저장

#### Google Gemini API
```bash
# .env 파일 생성 (UTF-8 인코딩)
GEMINI_API_KEY=your-gemini-api-key
```

### 3. 앱 실행

#### 백엔드 서버 시작
```bash
# 루트 폴더에서 실행
python test_server.py
```

#### Flutter 앱 실행
```bash
flutter run
```

## 📋 사용법

### 1. 앱 설정
1. 앱 실행 후 권한 허용 (마이크, 접근성 서비스, 오버레이)
2. 설정 → 접근성 → LLM 음성 비서 활성화
3. 서버 연결 상태 확인

### 2. 음성 명령 사용
1. **호출어**: "하이프로" (음성 인식 시작)
2. **명령어 예시**:
   - "네이버 클릭해줘"
   - "로그인 버튼 눌러줘"
   - "검색창 클릭해줘"
   - "스크롤해줘"

### 3. 백그라운드 사용
- 앱을 백그라운드로 보내면 플로팅 버튼 표시
- 플로팅 버튼 클릭으로 언제든지 음성 인식 시작

### 4. 텍스트 복사
- 앱바의 복사 버튼을 클릭하여 인식된 텍스트와 AI 응답을 클립보드로 복사

## 🔧 프로젝트 구조

```
llm_voice_assistant/
├── lib/
│   └── main.dart                 # Flutter 메인 앱
├── android/
│   └── app/src/main/kotlin/
│       └── com/example/llm_voice_assistant/
│           ├── MainActivity.kt           # Flutter-Native 연결
│           ├── MyAccessibilityService.kt # 접근성 서비스
│           └── BackgroundService.kt      # 백그라운드 서비스
├── test_server.py                # Flask 백엔드 서버 (루트)
├── backend/
│   ├── requirements.txt          # Python 의존성
│   └── teak-mix-466716-h0-3fc9e37b08ce.json # Google Cloud 인증
├── .env                          # 환경 변수 (API 키)
└── README.md
```

## 🎨 주요 컴포넌트

### VoiceAssistantProvider (Flutter)
- 음성 녹음 및 실시간 볼륨 감지
- 호출어 감지 시스템
- AI 응답 처리
- 네이티브 코드와의 통신
- 텍스트 복사 기능

### MyAccessibilityService (Android)
- 화면 요소 분석 및 감지
- 가상 터치 실행
- 접근성 이벤트 처리

### BackgroundService (Android)
- 플로팅 버튼 관리
- 백그라운드 음성 인식
- 포그라운드 서비스 유지

### Flask Backend
- Google Cloud Speech-to-Text 연동
- Google Gemini 명령 분석
- ffmpeg 오디오 변환 및 전처리
- 텍스트 후처리 (오류 보정)

## 🔒 권한 요구사항

### Android 권한
- `RECORD_AUDIO` - 음성 녹음
- `BIND_ACCESSIBILITY_SERVICE` - 접근성 서비스
- `SYSTEM_ALERT_WINDOW` - 플로팅 버튼
- `FOREGROUND_SERVICE` - 백그라운드 서비스
- `INTERNET` - 서버 통신

## 🐛 문제 해결 및 개발 과정

### 🎯 주요 해결 과정

#### 1. 음성 녹음 문제 (44바이트 파일)
**문제**: 녹음된 파일이 44바이트로 실제 오디오 데이터가 없음
**해결**: Android 네이티브 MediaRecorder로 전환
```kotlin
// MainActivity.kt
private fun startRecording(result: MethodChannel.Result) {
    mediaRecorder = MediaRecorder().apply {
        setAudioSource(MediaRecorder.AudioSource.MIC)
        setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        setAudioSamplingRate(44100)  // 향상된 샘플링 레이트
        setAudioChannels(1)
        setAudioEncodingBitRate(256000)  // 향상된 비트레이트
        setOutputFile(recordingFile!!.absolutePath)
    }
}
```

#### 2. Google STT 인코딩 오류
**문제**: "400 Invalid recognition 'config': bad encoding"
**해결**: ffmpeg를 통한 오디오 형식 변환 및 전처리
```python
# test_server.py
def convert_audio_to_wav(audio_data, input_format='m4a'):
    # M4A/3GP를 LINEAR16 WAV로 변환 + 노이즈 제거 + 볼륨 증폭
    ffmpeg_cmd = [
        'ffmpeg', '-i', temp_input_path,
        '-af', 'highpass=f=200,lowpass=f=3000,volume=2.0',  # 노이즈 제거 + 볼륨 증폭
        '-ar', '16000', '-ac', '1', '-acodec', 'pcm_s16le',
        '-y', temp_output_path
    ]
```

#### 3. Google Cloud 인증 문제
**문제**: "Your default credentials were not found"
**해결**: 서비스 계정 키 파일을 backend 폴더로 이동
```python
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'backend/teak-mix-466716-h0-3fc9e37b08ce.json'
```

#### 4. AI 모델 전환
**문제**: OpenAI GPT에서 Google Gemini로 전환 필요
**해결**: Gemini API 통합
```python
import google.generativeai as genai
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-pro')  # 최신 모델 사용
```

#### 5. 파일 중복 문제
**문제**: test_server.py가 루트와 backend 폴더에 중복 존재
**해결**: backend 폴더의 이전 버전 삭제, 루트 폴더의 최신 버전만 사용

#### 6. 음성 인식 정확도 개선
**문제**: 음성 인식 정확도가 80% 수준
**해결**: 오디오 전처리 및 AI 후처리 구현
```python
# 오디오 전처리: 노이즈 제거, 볼륨 증폭
# AI 후처리: 철자 교정, 문맥 보정, N-gram 기반 보정
def post_process_transcript(text):
    # 텍스트 후처리 로직
    return corrected_text
```

#### 7. 보안 강화
**문제**: API 키가 코드에 하드코딩됨
**해결**: 환경 변수 및 .env 파일 사용
```python
from dotenv import load_dotenv
load_dotenv()
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
```

### 🔧 최종 성공 구성

#### 음성 인식 파이프라인
1. **Android MediaRecorder**: M4A 형식으로 고품질 녹음
2. **Flutter MethodChannel**: 네이티브 녹음 결과 전달
3. **Python Flask**: Base64 디코딩 및 ffmpeg 변환
4. **오디오 전처리**: 노이즈 제거, 볼륨 증폭, 리샘플링
5. **Google STT**: LINEAR16 WAV로 변환된 오디오 인식
6. **AI 후처리**: 인식된 텍스트 오류 보정
7. **Google Gemini**: 개선된 텍스트 분석 및 명령 처리

#### 핵심 성공 요인
- ✅ **네이티브 오디오 녹음**: MediaRecorder 사용
- ✅ **ffmpeg 변환**: M4A → LINEAR16 WAV
- ✅ **오디오 전처리**: 노이즈 제거, 볼륨 증폭
- ✅ **AI 후처리**: 텍스트 오류 보정
- ✅ **Google Cloud 인증**: 서비스 계정 키 설정
- ✅ **Gemini AI**: 자연어 처리
- ✅ **보안**: 환경 변수 사용
- ✅ **파일 관리**: 중복 파일 정리

## 🐛 일반적인 문제들

### 1. 접근성 서비스가 활성화되지 않음
- 설정 → 접근성 → LLM 음성 비서 확인
- 앱 재시작 후 다시 시도

### 2. 서버 연결 실패
- 백엔드 서버가 실행 중인지 확인
- IP 주소가 올바른지 확인 (`192.168.219.109:8000`)

### 3. 음성 인식이 안됨
- 마이크 권한 확인
- Google Cloud 인증 파일 확인
- 네트워크 연결 상태 확인

### 4. 플로팅 버튼이 안 나타남
- 오버레이 권한 확인
- 앱을 백그라운드로 보낸 후 확인

### 5. ffmpeg 오류
- ffmpeg가 시스템에 설치되어 있는지 확인
- 환경 변수 PATH에 ffmpeg 경로 추가

### 6. API 키 오류
- .env 파일이 UTF-8 인코딩으로 저장되었는지 확인
- 환경 변수가 올바르게 설정되었는지 확인

### 7. 가상 터치가 작동하지 않음
- 접근성 서비스가 활성화되었는지 확인
- 대상 요소가 화면에 보이는지 확인
- 터치 좌표가 올바른지 확인

## 🔮 향후 개발 계획

### 단기 목표
- [ ] 에러 처리 강화
- [ ] UI/UX 개선
- [ ] 성능 최적화
- [ ] 테스트 코드 작성

### 장기 목표
- [ ] iOS 지원
- [ ] 더 정교한 화면 요소 인식
- [ ] 다국어 지원
- [ ] 커스텀 명령어 학습

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해주세요.

---

**🎉 성공 사례**: 이 프로젝트는 초기 음성 인식 문제부터 최종 성공까지의 전체 개발 과정을 포함하며, Android 네이티브 녹음, ffmpeg 변환, Google Cloud STT, Gemini AI를 통합한 완전한 음성 비서 시스템입니다.

**⚠️ 주의사항**: 이 프로젝트는 프로토타입이며, 실제 사용 시에는 보안 및 개인정보 보호를 고려해야 합니다.
