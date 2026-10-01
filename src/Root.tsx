import "./index.css";
import { Composition } from "remotion";
import { TestShort, TEST_SHORT } from "./TestShort";

// 강의 당일 받는 영상 Composition 들은 이 아래에 추가됩니다.
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
    </>
  );
};
