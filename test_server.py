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
    print("✅ .env 파일 로드됨")
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
    print(f"✅ Gemini API Key 설정됨: {GEMINI_API_KEY[:10]}...")

# Gemini 클라이언트 설정
try:
    genai.configure(api_key=GEMINI_API_KEY)
    print("✅ Gemini 클라이언트 초기화 성공")
except Exception as e:
    print(f"❌ Gemini 클라이언트 초기화 실패: {e}")

# Google Cloud Speech-to-Text 클라이언트 설정
try:
    # 환경 변수 직접 설정
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = GOOGLE_CREDENTIALS_PATH
    print(f"🔧 Google Cloud 인증 파일 경로: {GOOGLE_CREDENTIALS_PATH}")
    
    credentials = service_account.Credentials.from_service_account_file(
        GOOGLE_CREDENTIALS_PATH
    )
    speech_client = speech.SpeechClient(credentials=credentials)
    print("✅ Google Cloud Speech-to-Text 클라이언트 초기화 성공")
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
    print("✅ TTS 엔진 초기화 성공")
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
    print(f"🔍 호출어 인식 함수 시작")
    print(f"📝 입력 텍스트: '{transcript}'")
    print(f"📊 신뢰도 임계값: {confidence_threshold}")
    print(f"🎯 현재 신뢰도: {confidence}")
    
    if not transcript:
        print("❌ 텍스트가 비어있음")
        return False
    
    transcript_lower = transcript.lower().strip()
    print(f"🔤 소문자 변환: '{transcript_lower}'")
    
    # 정확한 매칭 확인
    print(f"🔍 정확한 매칭 확인 중...")
    for i, wake_word in enumerate(WAKE_WORDS):
        wake_word_lower = wake_word.lower()
        is_match = wake_word_lower in transcript_lower
        print(f"  {i+1:2d}. '{wake_word_lower}' in '{transcript_lower}' = {is_match}")
        
        if is_match:
            print(f"✅ 호출어 인식 성공: '{wake_word}' in '{transcript}'")
            return True
    
    # 부분 매칭 확인 (유사도 기반)
    print(f"🔍 유사도 기반 매칭 확인 중...")
    for i, wake_word in enumerate(WAKE_WORDS):
        wake_word_lower = wake_word.lower()
        similarity = _calculate_similarity(transcript_lower, wake_word_lower)
        is_similar = similarity > 0.8
        
        print(f"  {i+1:2d}. '{wake_word_lower}' ~ '{transcript_lower}' = {similarity:.3f} {'✅' if is_similar else '❌'}")
        
        if is_similar:
            print(f"✅ 호출어 유사도 인식: '{wake_word}' ~ '{transcript}' (유사도: {similarity:.3f})")
            return True
    
    print("❌ 호출어 인식 실패")
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

def post_process_transcript(transcript):
    """음성 인식 결과 텍스트 후처리"""
    if not transcript:
        return transcript
    
    # 일반적인 음성 인식 오류 보정
    corrections = {
        '네이버': '네이버',
        '네이버': '네이버',
        '네이버': '네이버',
        '로그인': '로그인',
        '로그인': '로그인',
        '검색': '검색',
        '검색': '검색',
        '스크롤': '스크롤',
        '스크롤': '스크롤',
        '클릭': '클릭',
        '클릭': '클릭',
        '버튼': '버튼',
        '버튼': '버튼',
        '열어줘': '열어줘',
        '실행해줘': '실행해줘',
        '보여줘': '보여줘'
    }
    
    corrected = transcript
    for wrong, correct in corrections.items():
        corrected = corrected.replace(wrong, correct)
    
    print(f"🔧 텍스트 후처리: '{transcript}' → '{corrected}'")
    return corrected

def convert_audio_to_wav(audio_data, input_format='m4a'):
    """오디오를 WAV 형식으로 변환"""
    try:
        print(f"🔄 오디오 변환 시작: {input_format} → WAV")
        
        # 임시 입력 파일 생성
        with tempfile.NamedTemporaryFile(suffix=f'.{input_format}', delete=False) as temp_input:
            temp_input.write(audio_data)
            temp_input_path = temp_input.name
        
        # 임시 출력 파일 경로
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_output:
            temp_output_path = temp_output.name
        
        print(f"📁 임시 입력 파일: {temp_input_path}")
        print(f"📁 임시 출력 파일: {temp_output_path}")
        
        # ffmpeg 명령 실행 (노이즈 제거 및 노멀라이징 추가)
        cmd = [
            'ffmpeg', '-i', temp_input_path,
            '-af', 'highpass=f=200,lowpass=f=3000,volume=1.5',  # 노이즈 제거 및 볼륨 증폭
            '-ar', '16000',  # 샘플링 레이트 16kHz
            '-ac', '1',      # 모노 채널
            '-acodec', 'pcm_s16le',  # LINEAR16 인코딩
            '-y', temp_output_path
        ]
        
        print(f"🔧 ffmpeg 명령: {' '.join(cmd)}")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ ffmpeg 변환 실패: {result.stderr}")
            return None
        
        print(f"✅ ffmpeg 변환 성공")
        
        # 변환된 WAV 파일 읽기
        with open(temp_output_path, 'rb') as wav_file:
            wav_content = wav_file.read()
        
        print(f"📊 변환된 WAV 크기: {len(wav_content)} bytes")
        
        # 임시 파일들 삭제
        try:
            os.unlink(temp_input_path)
            os.unlink(temp_output_path)
            print(f"🗑️ 임시 파일 삭제 완료")
        except Exception as e:
            print(f"⚠️ 임시 파일 삭제 실패: {e}")
        
        return wav_content
        
    except Exception as e:
        print(f"❌ 오디오 변환 중 오류: {e}")
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
        print(f"📥 POST 요청 받음: {request.content_type}")
        print(f"📊 요청 크기: {len(request.get_data())} bytes")
        
        data = request.get_json()
        if not data:
            print("❌ JSON 데이터가 없습니다.")
            return jsonify({'error': '요청 데이터가 없습니다.'}), 400
            
        audio_data = data.get('audio_data', '')
        check_wakeword = data.get('check_wakeword', False)
        
        print(f"🔍 받은 데이터 키들: {list(data.keys())}")
        print(f"🎤 audio_data 길이: {len(audio_data) if audio_data else 0}")
        
        if not audio_data:
            print("❌ audio_data가 없습니다.")
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
            
            print(f"🔧 STT 설정 완료 - 호출어 목록: {WAKE_WORDS}")
            
            # 음성 인식 실행
            print("🎤 Google STT 인식 시작...")
            response = speech_client.recognize(config=config, audio=audio)
            
            if not response.results:
                print("❌ 음성 인식 결과 없음")
                return jsonify({
                    'transcript': '',
                    'confidence': 0.0,
                    'is_wakeword': False
                })
            
            # 결과 처리
            result = response.results[0]
            transcript = result.alternatives[0].transcript.strip()
            confidence = result.alternatives[0].confidence
            
            # 텍스트 후처리 (철자 교정 및 문맥 보정)
            transcript = post_process_transcript(transcript)
            
            print(f"🎤 음성 인식 결과: '{transcript}' (신뢰도: {confidence:.2f})")
            
            # 호출어 확인
            is_wakeword = False
            if check_wakeword:
                print(f"🔍 호출어 확인 시작...")
                is_wakeword = is_wakeword_detected(transcript, confidence)
                print(f"🔍 호출어 확인 결과: {is_wakeword}")
            
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
        
        prompt = f"""당신은 스마트폰 화면을 제어하는 AI 비서입니다. 
        사용자의 음성 명령을 분석하여 적절한 UI 요소를 찾고 가상 터치를 수행합니다.
        
        **중요**: 음성 인식 오류를 고려하여 유사한 명령어들을 모두 처리할 수 있도록 해주세요.
        예를 들어 "네이버"가 "네이버"로 인식되지 않았더라도 "네이버", "네이버", "네이버" 등을 모두 "네이버"로 처리해주세요.
        
        응답 형식 (반드시 JSON으로만 응답):
        {{
            "action": "touch|scroll|type|back|home",
            "target": "버튼명 또는 요소 설명",
            "coordinates": {{"x": 100, "y": 200}},
            "response": "사용자에게 보여줄 응답 메시지",
            "confidence": 0.95
        }}
        
        액션 타입:
        - touch: 화면 터치 (좌표 필요)
        - scroll: 스크롤 (위/아래)
        - type: 텍스트 입력
        - back: 뒤로가기
        - home: 홈 버튼
        
        일반적인 명령 예시:
        - "네이버 클릭해줘" → touch, 네이버 버튼
        - "로그인 버튼 눌러줘" → touch, 로그인 버튼
        - "검색창 클릭해줘" → touch, 검색창
        - "위로 스크롤해줘" → scroll, 위
        - "안녕하세요 입력해줘" → type, 안녕하세요
        - "뒤로가기" → back, 뒤로가기
        - "홈으로" → home, 홈
        
        **음성 인식 오류 보정 규칙:**
        - "네이버" → "네이버"
        - "네이버" → "네이버" 
        - "네이버" → "네이버"
        - "로그인" → "로그인"
        - "검색" → "검색"
        - "스크롤" → "스크롤"
        
        다음 명령을 분석해주세요: {command}
        
        반드시 JSON 형식으로만 응답하세요."""
        
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
        
        print(f"🤖 명령 분석 완료: {parsed_response}")
        
        return jsonify(parsed_response)
        
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
    
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=True,
        threaded=True
    ) 