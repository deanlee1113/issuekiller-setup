#!/usr/bin/env python3
"""Supertonic 음성 모델을 내려받고(약 385MB) 짧은 한국어 문장을 합성해 wav로 저장한다.
사용: python warmup_tts.py <저장할 wav 경로>
"""
import sys
import time
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "test-voice.wav")
t0 = time.time()

import numpy as np
from supertonic import TTS

print("  Supertonic 모델 확인/다운로드 중... (처음 한 번만 오래 걸립니다)", flush=True)
tts = TTS(auto_download=True)
style = tts.get_voice_style(voice_name="F1")
wav, duration = tts.synthesize(
    text="안녕하세요. 이슈킬러 설치 테스트입니다.",
    lang="ko",
    voice_style=style,
    total_steps=8,
    speed=1.2,
)
tts.save_audio(wav, out)
try:
    secs = float(np.asarray(duration).reshape(-1)[0])
    extra = f", 음성 길이 {secs:.1f}초"
except Exception:
    extra = ""
print(f"  OK Supertonic 합성 성공: {out}{extra} (소요 {time.time() - t0:.0f}초)")
