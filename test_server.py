#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
LLM 음성 비서 프로토타입 백엔드 서버
Google Cloud Speech-to-Text와 OpenAI GPT를 활용한 음성 인식 및 명령 분석
"""

import os
import json
import base64
import tempfile
import subprocess
from flask import Flask, request, jsonify
from flask_cors import CORS
import google.generativeai as genai
from google.cloud import speech
from google.oauth2 import service_account
import pyttsx3
import io
import wave
import numpy as np

# .env 파일 로드 (보안상 권장)
try:
    from dotenv import load_dotenv
    load_dotenv()
    # .env 파일 로드됨
except ImportError:
    print("⚠️ python-dotenv가 설치되지 않았습니다. 환경 변수를 직접 설정하세요.")
except Exception as e:
    print(f"⚠️ .env 파일 로드 실패: {e}")

app = Flask(__name__)
CORS(app)

# 환경 변수 설정
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', 'your-gemini-api-key')
GOOGLE_CREDENTIALS_PATH = os.getenv('GOOGLE_CREDENTIALS_PATH', 'backend/teak-mix-466716-h0-3fc9e37b08ce.json')

# Gemini API Key 설정 확인
if GEMINI_API_KEY == 'your-gemini-api-key':
    print("⚠️ Gemini API Key가 설정되지 않았습니다.")
    print("📝 환경 변수 설정 방법:")
    print("   Windows: set GEMINI_API_KEY=your-api-key")
    print("   또는 코드에서 직접 설정하세요.")
else:
    pass  # Gemini API Key 설정됨

# Gemini 클라이언트 설정
try:
    genai.configure(api_key=GEMINI_API_KEY)
    pass  # Gemini 클라이언트 초기화 성공
except Exception as e:
    print(f"❌ Gemini 클라이언트 초기화 실패: {e}")

# Google Cloud Speech-to-Text 클라이언트 설정
try:
    # 환경 변수 직접 설정
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = GOOGLE_CREDENTIALS_PATH
    pass  # Google Cloud 인증 파일 경로 확인
    
    credentials = service_account.Credentials.from_service_account_file(
        GOOGLE_CREDENTIALS_PATH
    )
    speech_client = speech.SpeechClient(credentials=credentials)
    pass  # Google Cloud Speech-to-Text 클라이언트 초기화 성공
except Exception as e:
    print(f"❌ Google Cloud Speech-to-Text 클라이언트 초기화 실패: {e}")
    print(f"🔍 인증 파일 존재 여부 확인 중...")
    import pathlib
    if pathlib.Path(GOOGLE_CREDENTIALS_PATH).exists():
        print(f"✅ 인증 파일 존재: {GOOGLE_CREDENTIALS_PATH}")
    else:
        print(f"❌ 인증 파일 없음: {GOOGLE_CREDENTIALS_PATH}")
    speech_client = None

# TTS 엔진 초기화
try:
    tts_engine = pyttsx3.init()
    tts_engine.setProperty('rate', 150)
    tts_engine.setProperty('volume', 0.8)
    pass  # TTS 엔진 초기화 성공
except Exception as e:
    print(f"❌ TTS 엔진 초기화 실패: {e}")
    tts_engine = None

# 호출어 설정 - 다양한 변형 추가
WAKE_WORDS = [
    '하이프로', '하이 프로', '하이프로', '하이프로',
    'hi pro', 'hi pro', 'hi pro', 'hi pro',
    '하이프로야', '하이프로씨', '하이프로님',
    '프로야', '프로씨', '프로님',
    '비서야', '비서씨', '비서님',
    '어시스턴트', '어시스턴트야', '어시스턴트씨'
]

# 호출어 인식 함수 추가
def is_wakeword_detected(transcript, confidence_threshold=0.7):
    """호출어 인식 확인"""
    # 호출어 인식 함수 시작
    
    if not transcript:
        return False
    
    transcript_lower = transcript.lower().strip()
    # 소문자 변환
    
    # 정확한 매칭 확인
    for i, wake_word in enumerate(WAKE_WORDS):
        wake_word_lower = wake_word.lower()
        is_match = wake_word_lower in transcript_lower
        if is_match:
            return True
    
    # 부분 매칭 확인 (유사도 기반)
    for i, wake_word in enumerate(WAKE_WORDS):
        wake_word_lower = wake_word.lower()
        similarity = _calculate_similarity(transcript_lower, wake_word_lower)
        is_similar = similarity > 0.8
        
        if is_similar:
            return True
    
    return False

def _calculate_similarity(text1, text2):
    """텍스트 유사도 계산 (간단한 구현)"""
    if not text1 or not text2:
        return 0.0
    
    # 공통 문자 수 계산
    common_chars = sum(1 for c in text1 if c in text2)
    total_chars = max(len(text1), len(text2))
    
    similarity = common_chars / total_chars if total_chars > 0 else 0.0
    return similarity

import re

def post_process_transcript(transcript):
    """음성 인식 결과 텍스트 후처리"""
    if not transcript:
        return transcript

    # 오류 보정 딕셔너리 (단어 기준)
    corrections = {
        r'\b스크\.?\b': '스크롤',     # '스크.', '스크' → 스크롤
        r'\b스크롤\.?\b': '스크롤',
        r'\b내\.?\b': '내려',        # '내.', '내' → 내려
        r'\b올\.?\b': '올려',        # '올.', '올' → 올려
        r'\b내려\.?\b': '내려',
        r'\b올려\.?\b': '올려',
        r'\b열어줘\b': '열어줘',
        r'\b실행해줘\b': '실행해줘',
        r'\b보여줘\b': '보여줘',
        r'\b클릭\b': '클릭',
        r'\b버튼\b': '버튼',
        r'\b검색\b': '검색',
        r'\b로그인\b': '로그인',
        r'\b네이버\b': '네이버',
    }

    corrected = transcript

    for wrong_pattern, correct in corrections.items():
        if re.search(wrong_pattern, corrected):
            corrected = re.sub(wrong_pattern, correct, corrected)

    # 불필요한 마침표 제거 (전체 문장 끝에 있는 경우)
    corrected = re.sub(r'\.$', '', corrected)

    return corrected

def postprocess_ai_response(response_json, original_command):
    """AI 응답 검증 및 보정"""
    scroll_keywords = ['내려', '올려', '스크롤', '내려줘', '올려줘', '아래', '위', '위로', '아래로', '화면 내려', '화면 올려']
    
    action = response_json.get('action', '')
    target = response_json.get('target', '')
    
    # AI 응답 검증
    print(f"🔍 AI 응답 검증: action='{action}', target='{target}', command='{original_command}'")
    
    # 스크롤 키워드가 있는데 touch 액션인 경우 강제 변환
    if action == 'touch' and any(word in original_command for word in scroll_keywords):
        print(f"⚠️ 스크롤 명령이 touch로 분석됨! 강제 변환 시작...")
        
        # 방향 결정
        direction = 'down'
        if any(word in original_command for word in ['올려', '올려줘', '위', '위로']):
            direction = 'up'
        elif any(word in original_command for word in ['내려', '내려줘', '아래', '아래로']):
            direction = 'down'
        
        # 강제 scroll 변환
        response_json['action'] = 'scroll'
        response_json['direction'] = direction
        response_json['target'] = original_command
        
        print(f"✅ 강제 변환 완료: touch → scroll ({direction})")
    
    return response_json

def convert_audio_to_wav(audio_data, input_format='m4a'):
    """오디오를 WAV 형식으로 변환"""
    try:
        # 오디오 변환 시작
        
        # 임시 입력 파일 생성
        with tempfile.NamedTemporaryFile(suffix=f'.{input_format}', delete=False) as temp_input:
            temp_input.write(audio_data)
            temp_input_path = temp_input.name
        
        # 임시 출력 파일 경로
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_output:
            temp_output_path = temp_output.name
        
        # ffmpeg 명령 실행 (노이즈 제거 및 볼륨 증폭 강화)
        cmd = [
            'ffmpeg', '-i', temp_input_path,
            '-af', 'highpass=f=200,lowpass=f=3000,volume=3.0,compand=0.3|0.3:1|1:-90/-60/-40/-30/-20/-10/0:6:0:-90:0.2',  # 강한 볼륨 증폭 + 다이나믹 레인지 압축
            '-ar', '16000',  # 샘플링 레이트 16kHz
            '-ac', '1',      # 모노 채널
            '-acodec', 'pcm_s16le',  # LINEAR16 인코딩
            '-y', temp_output_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            return None
        
        # 변환된 WAV 파일 읽기
        with open(temp_output_path, 'rb') as wav_file:
            wav_content = wav_file.read()
        
        # 임시 파일들 삭제
        try:
            os.unlink(temp_input_path)
            os.unlink(temp_output_path)
        except Exception as e:
            pass
        
        return wav_content
        
    except Exception as e:
        return None

@app.route('/health', methods=['GET'])
def health_check():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'message': 'LLM 음성 비서 서버가 정상적으로 작동 중입니다.',
        'services': {
            'google_stt': speech_client is not None,
            'gemini': bool(GEMINI_API_KEY and GEMINI_API_KEY != 'your-gemini-api-key'),
            'tts_engine': tts_engine is not None
        }
    })

@app.route('/speech-to-text', methods=['POST'])
def speech_to_text():
    """음성을 텍스트로 변환"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': '요청 데이터가 없습니다.'}), 400
            
        audio_data = data.get('audio_data', '')
        check_wakeword = data.get('check_wakeword', False)
        
        if not audio_data:
            return jsonify({'error': '오디오 데이터가 없습니다.'}), 400
        
        # Base64 데이터 검증
        try:
            # Base64 디코딩 테스트
            test_decode = base64.b64decode(audio_data)
            if len(test_decode) < 50:  # 최소 크기를 50 bytes로 낮춤
                return jsonify({'error': '오디오 데이터가 너무 작습니다.'}), 400
        except Exception as e:
            return jsonify({'error': f'잘못된 Base64 데이터입니다: {str(e)}'}), 400
        
        print(f"🎤 받은 오디오 데이터 길이: {len(audio_data)}")
        print(f"🔍 호출어 확인 모드: {check_wakeword}")
        print(f"🔍 audio_data 첫 100자: {audio_data[:100] if audio_data else 'None'}")
        print(f"🔍 audio_data 마지막 100자: {audio_data[-100:] if audio_data and len(audio_data) > 100 else 'None'}")
        
        print("🔍 [DEBUG] 요청 헤더 정보:")
        print(f"   📊 Content-Type: {request.headers.get('Content-Type', 'N/A')}")
        print(f"   📏 Content-Length: {request.headers.get('Content-Length', 'N/A')}")
        print(f"   🌐 User-Agent: {request.headers.get('User-Agent', 'N/A')}")
        
        try:
            # Base64 디코딩
            audio_bytes = base64.b64decode(audio_data)
            print(f"🎤 디코딩된 오디오 크기: {len(audio_bytes)} bytes")
            
            # 오디오 형식 확인 (Flutter에서 전송한 형식)
            audio_format = data.get('audio_format', 'm4a')
            print(f"📁 받은 오디오 형식: {audio_format}")
            
            # M4A를 WAV로 변환
            wav_content = convert_audio_to_wav(audio_bytes, audio_format)
            if wav_content is None:
                return jsonify({'error': '오디오 변환 실패'}), 500
            
            print(f"✅ 오디오 변환 완료: {len(wav_content)} bytes")
            
            # Google Cloud Speech-to-Text 설정
            audio = speech.RecognitionAudio(content=wav_content)
            config = speech.RecognitionConfig(
                encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
                # sample_rate_hertz는 자동 감지되도록 제거
                language_code='ko-KR',
                use_enhanced=True,
                model='latest_long',  # 더 긴 명령어에 최적화
                enable_automatic_punctuation=True,
                enable_word_time_offsets=True,
                enable_word_confidence=True,  # 단어별 신뢰도 추가
                speech_contexts=[{
                    'phrases': WAKE_WORDS + [
                        '네이버', '유튜브', '구글', '페이스북', '로그인', '검색',
                        '클릭', '버튼', '열어줘', '실행해줘', '보여줘', '네이버', '네이버',
                        '로그인', '로그인', '검색', '검색', '스크롤', '스크롤'
                    ],
                    'boost': 25  # 더 높은 가중치
                }]
            )
            
            # 음성 인식 실행
            print("🎤 [DEBUG] Google Cloud Speech-to-Text API 호출 중...")
            response = speech_client.recognize(config=config, audio=audio)
            
            print(f"📡 [DEBUG] Google STT 응답:")
            print(f"   📊 결과 개수: {len(response.results)}")
            
            if not response.results:
                print("❌ [DEBUG] 음성 인식 결과 없음")
                return jsonify({
                    'transcript': '',
                    'confidence': 0.0,
                    'is_wakeword': False
                })
            
            # 결과 처리
            result = response.results[0]
            transcript = result.alternatives[0].transcript.strip()
            confidence = result.alternatives[0].confidence
            
            print(f"🎯 [DEBUG] 음성 인식 결과:")
            print(f"   🎤 원본 텍스트: '{transcript}'")
            print(f"   📈 신뢰도: {confidence:.3f} ({confidence*100:.1f}%)")
            print(f"   📊 대안 개수: {len(result.alternatives)}")
            
            if len(result.alternatives) > 1:
                for i, alt in enumerate(result.alternatives[1:3]):  # 상위 3개만 출력
                    print(f"   🔄 대안 {i+1}: '{alt.transcript.strip()}' (신뢰도: {alt.confidence:.3f})")
            
            # 텍스트 후처리 (철자 교정 및 문맥 보정)
            original_transcript = transcript
            transcript = post_process_transcript(transcript)
            
            print(f"🔧 [DEBUG] 텍스트 후처리:")
            print(f"   📝 원본: '{original_transcript}'")
            print(f"   ✨ 후처리: '{transcript}'")
            
            # 호출어 확인
            is_wakeword = False
            if check_wakeword:
                is_wakeword = is_wakeword_detected(transcript, confidence)
                print(f"🔍 [DEBUG] 호출어 확인: {is_wakeword}")
            
            return jsonify({
                'transcript': transcript,
                'confidence': confidence,
                'is_wakeword': is_wakeword
            })
            
        except Exception as e:
            print(f"❌ 음성 인식 처리 중 오류: {e}")
            return jsonify({'error': f'음성 인식 처리 중 오류가 발생했습니다: {str(e)}'}), 500
            
    except Exception as e:
        print(f"❌ 음성 인식 오류: {e}")
        return jsonify({'error': f'음성 인식 중 오류가 발생했습니다: {str(e)}'}), 500

@app.route('/analyze-command', methods=['POST'])
def analyze_command():
    """음성 명령을 분석하고 적절한 액션 결정"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': '요청 데이터가 없습니다.'}), 400
            
        command = data.get('command', '')
        
        if not command:
            return jsonify({'error': '명령어가 없습니다.'}), 400
        
        # 명령어 길이 검증
        if len(command.strip()) < 2:
            return jsonify({'error': '명령어가 너무 짧습니다.'}), 400
        
        # 명령 분석 시작
        print(f"🤖 명령 분석 시작: '{command}'")
        
        # Gemini API Key 검증
        if GEMINI_API_KEY == 'your-gemini-api-key' or GEMINI_API_KEY == 'dummy-key-for-testing':
            print("❌ Gemini API Key가 설정되지 않아 AI 분석을 건너뜁니다.")
            return jsonify({
                'action': 'touch',
                'target': command,
                'coordinates': {'x': 200, 'y': 300},
                'response': f"'{command}' 명령을 실행하겠습니다. (API Key 미설정으로 기본 처리)",
                'confidence': 0.5
            })
        
        # Gemini를 사용한 명령 분석
        try:
            model = genai.GenerativeModel('gemini-1.5-pro')
        except Exception as e:
            print(f"❌ Gemini 모델 초기화 실패: {e}")
            return jsonify({
                'action': 'touch',
                'target': command,
                'coordinates': {'x': 200, 'y': 300},
                'response': f"'{command}' 명령을 실행하겠습니다. (AI 분석 실패로 기본 처리)",
                'confidence': 0.5
            })
        
        prompt = f"""
당신은 사용자의 음성 명령을 분석하여 아래 4가지 액션 중 하나로 분류해야 합니다:

- touch: 사용자가 화면의 특정 지점을 누르거나 클릭하려고 할 때
- scroll: 화면을 위 또는 아래로 이동(스크롤)하려고 할 때
- input: 텍스트나 문자를 입력하려고 할 때
- navigate: 앱이나 페이지를 전환하거나 이동하려고 할 때

🚨 [절대 규칙 - 반드시 지켜야 함]
- "내려", "올려", "스크롤", "내려줘", "올려줘", "위로", "아래로", "화면 내려", "화면 올려" → 절대 touch 액션이 아님! 반드시 scroll 액션으로만 응답!
- "내려"는 절대 touch 액션이 아니고 반드시 scroll 액션으로 응답하세요
- "올려"는 절대 touch 액션이 아니고 반드시 scroll 액션으로 응답하세요
- 스크롤 관련 명령어는 절대 touch가 될 수 없습니다!

🔍 [부사형 단어 유연성 - 절대 규칙]
- **부사형 단어는 스크롤 명령의 강도나 양을 나타내며, 스크롤 액션의 본질을 바꾸지 않습니다**
- "많이", "조금", "적게", "살짝", "크게", "한번", "한 번", "쭉", "천천히", "빨리", "부드럽게", "가볍게", "강하게", "약하게", "무겁게", "조용히", "느리게" 등의 부사는 모두 scroll 액션입니다
- 부사형 단어가 포함되어도 스크롤 명령의 핵심 동사("내려", "올려", "스크롤")가 있으면 반드시 scroll 액션입니다
- **절대 규칙**: "많이 내려줘", "조금 올려줘", "살짝 스크롤", "한번 내려줘", "크게 올려줘", "천천히 내려줘", "부드럽게 올려줘" → 모두 scroll 액션 (절대 touch 아님!)
- **부사형 단어가 포함된 명령은 절대 touch가 될 수 없습니다!**

⚠️ [중요 기준 정리]
- "스크롤", "스크롤 다운", "스크롤 업", "위로 올려줘", "아래로 내려줘", "쭉 내려봐", "쭉 올려줘", "내려줘", "올려줘" → 반드시 scroll 액션으로 분류 (절대 touch 아님)
- "눌러줘", "클릭", "터치", "이 버튼 눌러" → touch 액션 (특정 위치나 버튼을 누르는 의도)
- 스크롤 명령은 **단순한 방향 조작이며**, 화면의 위치를 움직이는 것이지, 특정 지점을 누르는 것이 아닙니다.

🎯 반드시 JSON 형식으로만 응답하세요. 예시는 다음과 같습니다:
- "스크롤 해줘" → {{ "action": "scroll", "direction": "down" }}
- "위로 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "아래로 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "내려" → {{ "action": "scroll", "direction": "down" }}
- "올려" → {{ "action": "scroll", "direction": "up" }}
- "많이 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "조금 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "살짝 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "한번 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "크게 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "천천히 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "부드럽게 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "가볍게 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "강하게 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "약하게 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "무겁게 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "조용히 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "느리게 올려줘" → {{ "action": "scroll", "direction": "up" }}
- "쭉 내려줘" → {{ "action": "scroll", "direction": "down" }}
- "화면 눌러줘" → {{ "action": "touch", "position": {{ "x": 100, "y": 300 }} }}

🧠 다음 명령을 분석해주세요:
"{command}"

정확히 JSON 형식으로만 출력해주세요.
"""
        
        response = model.generate_content(prompt)
        gemini_response = response.text.strip()
        
        try:
            # JSON 응답 파싱 시도
            if gemini_response.startswith('{') and gemini_response.endswith('}'):
                parsed_response = json.loads(gemini_response)
            else:
                # JSON이 아닌 경우 기본 응답 생성
                parsed_response = {
                    "action": "touch",
                    "target": command,
                    "coordinates": {"x": 200, "y": 300},
                    "response": f"'{command}' 명령을 실행하겠습니다."
                }
        except json.JSONDecodeError:
            # JSON 파싱 실패 시 기본 응답
            parsed_response = {
                "action": "touch",
                "target": command,
                "coordinates": {"x": 200, "y": 300},
                "response": f"'{command}' 명령을 실행하겠습니다."
            }
        
        # AI 결과 검증 및 보정
        corrected_response = postprocess_ai_response(parsed_response, command)
        
        print(f"🤖 명령 분석 완료: {corrected_response}")
        
        return jsonify(corrected_response)
        
    except Exception as e:
        print(f"❌ 명령 분석 오류: {e}")
        return jsonify({
            'action': 'touch',
            'target': 'unknown',
            'coordinates': {'x': 200, 'y': 300},
            'response': f'명령 분석 중 오류가 발생했습니다: {str(e)}'
        })

@app.route('/tts', methods=['POST'])
def text_to_speech():
    """텍스트를 음성으로 변환"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': '요청 데이터가 없습니다.'}), 400
            
        text = data.get('text', '')
        
        if not text:
            return jsonify({'error': '텍스트가 없습니다.'}), 400
        
        # 텍스트 길이 검증
        if len(text.strip()) < 1:
            return jsonify({'error': '텍스트가 너무 짧습니다.'}), 400
        
        if tts_engine is None:
            return jsonify({'error': 'TTS 엔진이 초기화되지 않았습니다.'}), 500
        
        # 임시 파일에 음성 저장
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_file_path = temp_file.name
        
        try:
            # TTS 실행
            tts_engine.save_to_file(text, temp_file_path)
            tts_engine.runAndWait()
            
            # 음성 파일 읽기
            with open(temp_file_path, 'rb') as f:
                audio_data = f.read()
            
            # Base64 인코딩
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
            
            return jsonify({
                'audio_data': audio_base64,
                'text': text
            })
            
        finally:
            # 임시 파일 삭제
            os.unlink(temp_file_path)
            
    except Exception as e:
        print(f"❌ TTS 오류: {e}")
        return jsonify({'error': f'TTS 중 오류가 발생했습니다: {str(e)}'}), 500

@app.route('/wakeword-feedback', methods=['POST'])
def wakeword_feedback():
    """호출어 인식 피드백 TTS"""
    try:
        feedback_text = "호출어 인식되었습니다. 명령어를 말해주세요."
        
        if tts_engine is None:
            return jsonify({'error': 'TTS 엔진이 초기화되지 않았습니다.'}), 500
        
        # 임시 파일에 음성 저장
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_file_path = temp_file.name
        
        try:
            # TTS 실행
            tts_engine.save_to_file(feedback_text, temp_file_path)
            tts_engine.runAndWait()
            
            # 음성 파일 읽기
            with open(temp_file_path, 'rb') as f:
                audio_data = f.read()
            
            # Base64 인코딩
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
            
            return jsonify({
                'audio_data': audio_base64,
                'text': feedback_text
            })
            
        finally:
            # 임시 파일 삭제
            os.unlink(temp_file_path)
            
    except Exception as e:
        print(f"❌ 호출어 피드백 TTS 오류: {e}")
        return jsonify({'error': f'호출어 피드백 TTS 중 오류가 발생했습니다: {str(e)}'}), 500

if __name__ == '__main__':
    print("🚀 LLM 음성 비서 백엔드 서버 시작...")
    print(f"📍 서버 URL: http://127.0.0.1:8000")
    
    # API Key 상태 확인
    if GEMINI_API_KEY == 'your-gemini-api-key' or GEMINI_API_KEY == 'dummy-key-for-testing':
        print("🔧 Gemini API Key: 설정 필요")
        print("📝 API Key 설정 방법:")
        print("   1. 환경 변수 설정: set GEMINI_API_KEY=your-api-key")
        print("   2. .env 파일 생성: GEMINI_API_KEY=your-api-key")
        print("   3. 코드에서 직접 설정: GEMINI_API_KEY = 'your-api-key'")
        print("   4. Google AI Studio에서 API Key 발급: https://makersuite.google.com/app/apikey")
    else:
        print("🔧 Gemini API Key: 설정됨")
    
    print(f"🎤 Google STT: {'사용 가능' if speech_client else '사용 불가'}")
    print(f"🔊 TTS Engine: {'사용 가능' if tts_engine else '사용 불가'}")
    
    # 라우트 등록 확인
    print("🔍 등록된 라우트 확인:")
    for rule in app.url_map.iter_rules():
        print(f"   {rule.rule} -> {rule.endpoint}")
    
    app.run(
        host='0.0.0.0',
        port=8000,  # 포트 8000으로 통일
        debug=False,  # 디버그 모드 끄기
        threaded=True
    ) 