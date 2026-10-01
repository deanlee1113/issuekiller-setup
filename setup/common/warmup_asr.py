#!/usr/bin/env python3
"""faster-whisper small 모델을 내려받고(약 465MB) wav 하나를 인식해 본다.
사용: python warmup_asr.py <wav 경로>
"""
import sys
import time

wav = sys.argv[1]
t0 = time.time()

from faster_whisper import WhisperModel

print("  Whisper small 모델 확인/다운로드 중... (처음 한 번만 오래 걸립니다)", flush=True)
model = WhisperModel("small", device="cpu", compute_type="int8")
segments, _ = model.transcribe(wav, language="ko", beam_size=5)
text = "".join(s.text for s in segments).strip()
print(f"  OK faster-whisper 인식 결과: {text!r} (소요 {time.time() - t0:.0f}초)")
if not any(k in text for k in ("이슈", "설치", "테스트")):
    print("  주의: 인식 문장이 예상과 다릅니다. 모델 로드는 정상이므로 계속 진행합니다.")
