import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

// 설치 확인용 2초짜리 세로 영상 (1080x1920, 30fps).
// 설치 도우미가 이 Composition 을 렌더해 ~/issuekiller-tools/test-render.mp4 로 저장합니다.
export const TEST_SHORT = { width: 1080, height: 1920, fps: 30, durationInFrames: 60 };

export const TestShort = () => {
  const frame = useCurrentFrame();
  const { durationInFrames, fps } = useVideoConfig();
  const bar = interpolate(frame, [0, durationInFrames - 1], [0, 100]);
  const pop = interpolate(frame, [0, 8], [0.6, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: "#141C2E", justifyContent: "center", alignItems: "center", fontFamily: "sans-serif" }}>
      <div style={{ transform: `scale(${pop})`, textAlign: "center" }}>
        <div style={{ fontSize: 150, fontWeight: 900, color: "#FFD23F", letterSpacing: -4 }}>이슈킬러</div>
        <div style={{ fontSize: 60, color: "#FFFFFF", marginTop: 20 }}>설치 확인 렌더</div>
        <div style={{ fontSize: 44, color: "#9AA6C4", marginTop: 40 }}>
          {Math.floor(frame / fps)}.{String(Math.floor(((frame % fps) / fps) * 10))}초 / {frame + 1}프레임
        </div>
      </div>
      <div style={{ position: "absolute", left: 90, right: 90, bottom: 420, height: 18, background: "#2A3550", borderRadius: 9 }}>
        <div style={{ width: `${bar}%`, height: "100%", background: "#FFD23F", borderRadius: 9 }} />
      </div>
    </AbsoluteFill>
  );
};
