import "./index.css";
import { Composition } from "remotion";
import { TestShort, TEST_SHORT } from "./TestShort";
import { ClaudeGeneratedCompositions } from "./ClaudeGeneratedCompositions";

// 새 영상은 이 파일이 아니라 src/ClaudeGeneratedCompositions.tsx 에 등록된다
// (.claude/skills/issuekiller-shorts/scripts/scaffold_short.py 가 자동으로 추가).
export const RemotionRoot = () => {
  return (
    <>
      <Composition
        id="TestShort"
        component={TestShort}
        durationInFrames={TEST_SHORT.durationInFrames}
        fps={TEST_SHORT.fps}
        width={TEST_SHORT.width}
        height={TEST_SHORT.height}
      />
      <ClaudeGeneratedCompositions />
    </>
  );
};
