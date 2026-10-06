// =====================================================================
//  쇼츠 화면 템플릿 (1080x1920, 30fps)
//  새 영상은 이 파일을 고치지 않고, scaffold_short.py 가 만드는
//  src/<ID>Composition.tsx 에서 createNewsComposition(config) 로 만든다.
//  채널 이름 배지는 프로젝트 폴더의 channel.json 에서 읽는다.
//  색·글씨 크기·글꼴은 프로젝트 폴더의 theme.json 에서 읽는다.
//  (화면 모양을 바꿀 때는 이 파일이 아니라 theme.json 만 고친다.
//   값이 없거나 잘못되면 아래 DEFAULT_THEME 의 기본값을 쓴다.)
// =====================================================================
import type { Caption } from "@remotion/captions";
import { Audio } from "@remotion/media";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  OffthreadVideo,
  interpolate,
  staticFile,
  useCurrentFrame,
  useDelayRender,
  useVideoConfig,
} from "remotion";
import channel from "../channel.json";
import themeFile from "../theme.json";

export type Scene = {
  startMs: number;
  endMs: number;
  image: string;
  video?: string;
  accent: string;
  label: string;
  position?: string;
  zoom?: number;
  transformOrigin?: string;
  obscureSourceText?: boolean;
  maskSourceCorners?: boolean;
};

export type NewsConfig = {
  assetRoot: string;
  voiceFile?: string;
  title: string;
  titleSize?: number;
  captionSize?: number;
  layoutPreset?: "legacy" | "shorts-safe-v2";
  showProgress?: boolean;
  durationInFrames: number;
  scenes: Scene[];
  highlightTerms: string[];
  maskBroadcastCorners?: boolean;
  hook?: {
    /** 첫 화면을 가득 채우는 한 줄 훅. 12자 이내를 권장한다. */
    text: string;
    /** text 안에서 노란 배경으로 강조할 부분 */
    highlight?: string;
    /** 훅 카드가 유지되는 시간(ms). 기본 1100 */
    durationMs?: number;
    /** 훅 카드에 쓸 이미지. 생략하면 첫 장면 이미지를 쓴다. */
    image?: string;
    /** 이미지에서 얼굴이 보이도록 잡는 위치. 기본 "center 38%" */
    position?: string;
  };
};

// Mac 은 Apple SD Gothic Neo, Windows 는 맑은 고딕(Malgun Gothic)으로 그려진다.
const BASE_FONT_STACK =
  '"Apple SD Gothic Neo", "Malgun Gothic", "Pretendard", "Noto Sans KR", Arial, sans-serif';

// 채널 이름·문구는 프로젝트 폴더의 channel.json 한 곳에서만 바꾼다.
const channelConfig = channel as {name?: string; tagline?: string};
const CHANNEL_NAME = (channelConfig.name ?? "").trim() || "내 채널";
const CHANNEL_TAGLINE = (channelConfig.tagline ?? "").trim();

// ---------------------------------------------------------------------
//  화면 모양(theme.json). 기본값 = 강의 키트의 원래 모양.
//  theme.json 에 키가 없거나, 값이 비었거나, 형식이 틀리면 기본값을 쓴다.
// ---------------------------------------------------------------------
const DEFAULT_THEME = {
  backgroundColor: "#0d0f13",
  titleColor: "#ffffff",
  titleSizeAdjust: 0,
  badgeColor: "#ffcc4d",
  badgeTextColor: "#111318",
  taglineColor: "rgba(255,255,255,0.94)",
  taglineSize: 25,
  sceneLabelColor: "",
  sceneLabelTextColor: "#111318",
  captionBoxColor: "rgba(7,9,12,0.94)",
  captionTextColor: "#fffdf6",
  captionSizeAdjust: 0,
  highlightColor: "#ffdf63",
  highlightTextColor: "#111318",
  fontFamily: "",
};
// 훅 카드의 강조 색은 원래 조금 다른 노랑이다. highlightColor 를 바꾸면 훅 강조도 같이 바뀐다.
const DEFAULT_HOOK_HIGHLIGHT = "#ffe066";

const HEX_COLOR = /^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
const RGB_COLOR =
  /^rgba?\(\s*\d{1,3}(\.\d+)?\s*,\s*\d{1,3}(\.\d+)?\s*,\s*\d{1,3}(\.\d+)?\s*(,\s*(0|1|0?\.\d+|1\.0+|\d{1,3}%)\s*)?\)$/i;

const rawTheme: Record<string, unknown> =
  themeFile != null && typeof themeFile === "object" && !Array.isArray(themeFile)
    ? (themeFile as unknown as Record<string, unknown>)
    : {};

const themeColor = (key: keyof typeof DEFAULT_THEME, allowEmpty = false): string => {
  const value = rawTheme[key];
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (HEX_COLOR.test(trimmed) || RGB_COLOR.test(trimmed)) {
      return trimmed;
    }
    if (allowEmpty && trimmed === "") {
      return "";
    }
  }
  return DEFAULT_THEME[key] as string;
};

const themeNumber = (
  key: keyof typeof DEFAULT_THEME,
  min: number,
  max: number,
): number => {
  const value = rawTheme[key];
  const parsed =
    typeof value === "number"
      ? value
      : typeof value === "string" && value.trim() !== ""
        ? Number(value.trim())
        : NaN;
  if (!Number.isFinite(parsed)) {
    return DEFAULT_THEME[key] as number;
  }
  return Math.min(max, Math.max(min, Math.round(parsed)));
};

// "#0d0f13" / "rgba(13,15,19,0.9)" → [13, 15, 19]
const toRgb = (color: string): [number, number, number] => {
  if (color.startsWith("#")) {
    let hex = color.slice(1);
    if (hex.length <= 4) {
      hex = hex
        .split("")
        .map((c) => c + c)
        .join("");
    }
    return [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)) as [
      number,
      number,
      number,
    ];
  }
  const nums = color.match(/[\d.]+/g) ?? ["0", "0", "0"];
  return [0, 1, 2].map((i) => Math.min(255, Math.round(Number(nums[i])))) as [
    number,
    number,
    number,
  ];
};

const isDarkColor = (color: string): boolean => {
  const [r, g, b] = toRgb(color);
  return 0.299 * r + 0.587 * g + 0.114 * b < 128;
};

const cleanFontName = (value: unknown): string =>
  typeof value === "string"
    ? value.replace(/["'`;{}<>\\]/g, "").trim().slice(0, 60)
    : "";

const highlightColor = themeColor("highlightColor");
const THEME = {
  backgroundColor: themeColor("backgroundColor"),
  titleColor: themeColor("titleColor"),
  titleSizeAdjust: themeNumber("titleSizeAdjust", -40, 60),
  badgeColor: themeColor("badgeColor"),
  badgeTextColor: themeColor("badgeTextColor"),
  taglineColor: themeColor("taglineColor"),
  taglineSize: themeNumber("taglineSize", 14, 60),
  sceneLabelColor: themeColor("sceneLabelColor", true),
  sceneLabelTextColor: themeColor("sceneLabelTextColor"),
  captionBoxColor: themeColor("captionBoxColor"),
  captionTextColor: themeColor("captionTextColor"),
  captionSizeAdjust: themeNumber("captionSizeAdjust", -40, 60),
  highlightColor,
  highlightTextColor: themeColor("highlightTextColor"),
  hookHighlightColor:
    highlightColor.toLowerCase() === DEFAULT_THEME.highlightColor
      ? DEFAULT_HOOK_HIGHLIGHT
      : highlightColor,
};

const customFont = cleanFontName(rawTheme.fontFamily);
const fontFamily = customFont
  ? `"${customFont}", ${BASE_FONT_STACK}`
  : BASE_FONT_STACK;

// 화면 위·아래 그림자(그라데이션)는 backgroundColor 와 같은 색으로 칠한다.
const BG_RGB = toRgb(THEME.backgroundColor).join(",");
const shade = (alpha: number): string => `rgba(${BG_RGB},${alpha})`;

// 자막 글씨가 어두운 색이면 글씨 그림자를 빼서 번져 보이지 않게 한다.
const CAPTION_TEXT_SHADOW = isDarkColor(THEME.captionTextColor)
  ? "none"
  : "0 4px 14px rgba(0,0,0,0.86)";

const fontSizeWithAdjust = (base: number, adjust: number): number =>
  Math.max(24, base + adjust);

export const createNewsComposition = (config: NewsConfig): React.FC => {
  const Component: React.FC = () => {
    const {delayRender, continueRender, cancelRender} = useDelayRender();
    const [handle] = useState(() => delayRender(`Loading ${config.assetRoot}`));
    const [captions, setCaptions] = useState<Caption[] | null>(null);

    const loadCaptions = useCallback(async () => {
      try {
        const response = await fetch(
          staticFile(`${config.assetRoot}/captions-voiced.json`),
        );
        if (!response.ok) {
          throw new Error(`Failed to load captions: ${response.status}`);
        }
        setCaptions((await response.json()) as Caption[]);
        continueRender(handle);
      } catch (error) {
        cancelRender(error);
      }
    }, [cancelRender, continueRender, handle]);

    useEffect(() => {
      loadCaptions();
    }, [loadCaptions]);

    if (!captions) {
      return null;
    }

    return <NewsShort config={config} captions={captions} />;
  };
  return Component;
};

const NewsShort: React.FC<{config: NewsConfig; captions: Caption[]}> = ({
  config,
  captions,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const timeMs = (frame / fps) * 1000;
  const scene =
    config.scenes.find(
      (candidate) => timeMs >= candidate.startMs && timeMs < candidate.endMs,
    ) ?? config.scenes[config.scenes.length - 1];
  const hookActive =
    config.hook != null && timeMs < (config.hook.durationMs ?? 1100);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.backgroundColor,
        color: "#fff",
        fontFamily,
        overflow: "hidden",
      }}
    >
      <ImageScene
        config={config}
        scene={scene}
        timeMs={timeMs}
      />
      <Audio
        src={staticFile(`${config.assetRoot}/${config.voiceFile ?? "voiceover-f5.wav"}`)}
        volume={1}
      />
      {hookActive ? null : <TopHeader config={config} />}
      {hookActive ? null : (
        <CaptionOverlay config={config} captions={captions} timeMs={timeMs} />
      )}
      {config.showProgress === false || hookActive ? null : (
        <ProgressBar config={config} />
      )}
      {hookActive ? <HookCard config={config} /> : null}
    </AbsoluteFill>
  );
};

const ImageScene: React.FC<{
  config: NewsConfig;
  scene: Scene;
  timeMs: number;
}> = ({config, scene, timeMs}) => {
  const {fps} = useVideoConfig();
  const isShortsSafeV2 = config.layoutPreset === "shorts-safe-v2";
  const imageTop = isShortsSafeV2 ? 392 : 246;
  const imageHeight = isShortsSafeV2 ? 1528 : 1290;
  const imageSide = isShortsSafeV2 ? 0 : 28;
  const localFrame = ((timeMs - scene.startMs) / 1000) * fps;
  const entrance = interpolate(localFrame, [0, 6], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });
  const sceneProgress = interpolate(
    timeMs,
    [scene.startMs, scene.endMs],
    [0, 1],
    {extrapolateLeft: "clamp", extrapolateRight: "clamp"},
  );
  const imagePath = `${config.assetRoot}/${scene.image}`;
  const maskSourceCorners =
    scene.maskSourceCorners ?? config.maskBroadcastCorners ?? false;
  // theme.json 의 sceneLabelColor 가 비어 있으면 장면마다 정해 둔 색(scene.accent)을 쓴다.
  const sceneColor = THEME.sceneLabelColor || scene.accent;

  return (
    <AbsoluteFill>
      <Img
        src={staticFile(imagePath)}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: scene.position ?? "center center",
          filter: "blur(48px) brightness(0.34) saturate(1.05)",
          scale: 1.2,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            `linear-gradient(180deg, ${shade(0.22)} 0%, ${shade(0.03)} 38%, ${shade(0.94)} 82%, ${THEME.backgroundColor} 100%)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          top: imageTop,
          left: imageSide,
          right: imageSide,
          height: imageHeight,
          borderRadius: isShortsSafeV2 ? 0 : 8,
          overflow: "hidden",
          backgroundColor: "#141820",
          outline: isShortsSafeV2
            ? "none"
            : "2px solid rgba(255,255,255,0.2)",
          boxShadow: isShortsSafeV2
            ? "none"
            : "0 30px 100px rgba(0,0,0,0.58)",
          opacity: entrance,
          translate: `0 ${(1 - entrance) * 14}px`,
        }}
      >
        {scene.video ? (
          <OffthreadVideo
            src={staticFile(`${config.assetRoot}/${scene.video}`)}
            muted
            style={{width: "100%", height: "100%", objectFit: "cover"}}
          />
        ) : (
        <Img
          src={staticFile(imagePath)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: scene.position ?? "center center",
            filter: scene.obscureSourceText
              ? "blur(9px) brightness(0.58) saturate(0.88)"
              : undefined,
            scale: (scene.zoom ?? 1.06) + sceneProgress * 0.035,
            transformOrigin: scene.transformOrigin ?? "50% 50%",
          }}
        />
        )}
        {scene.obscureSourceText ? (
          <div
            style={{
              position: "absolute",
              inset: 0,
              backgroundColor: "rgba(7,9,12,0.2)",
            }}
          />
        ) : null}
      </div>
      <div
        style={{
          position: "absolute",
          top: isShortsSafeV2 ? 760 : maskSourceCorners ? 825 : 650,
          left: imageSide,
          right: imageSide,
          height: isShortsSafeV2
            ? 1160
            : maskSourceCorners
              ? 711
              : 886,
          borderRadius: isShortsSafeV2 ? 0 : "0 0 8px 8px",
          background: isShortsSafeV2
            ? `linear-gradient(180deg, ${shade(0.02)} 0%, ${shade(0.48)} 32%, ${shade(0.78)} 67%, ${shade(0.9)} 100%)`
            : maskSourceCorners
              ? `linear-gradient(180deg, ${shade(0.34)} 0%, ${shade(0.95)} 28%, ${shade(0.995)} 100%)`
              : `linear-gradient(180deg, ${shade(0)} 0%, ${shade(0.5)} 38%, ${shade(0.99)} 100%)`,
        }}
      />
      {maskSourceCorners ? (
        <div
          style={{
            position: "absolute",
            top: isShortsSafeV2 ? imageTop + 12 : 258,
            left: isShortsSafeV2 ? 0 : 42,
            right: isShortsSafeV2 ? 0 : 42,
            height: 82,
            borderRadius: isShortsSafeV2 ? 0 : 6,
            backgroundColor: shade(0.96),
          }}
        />
      ) : null}
      <div
        style={{
          position: "absolute",
          top: imageTop,
          left: imageSide,
          width: 14,
          height: imageHeight,
          backgroundColor: sceneColor,
        }}
      />
      <div
        style={{
          position: "absolute",
          top: isShortsSafeV2 ? imageTop + 34 : 275,
          left: isShortsSafeV2 ? 46 : 68,
          maxWidth: 735,
          padding: "12px 20px 13px",
          borderRadius: 6,
          backgroundColor: sceneColor,
          color: THEME.sceneLabelTextColor,
          fontSize: 34,
          fontWeight: 900,
          letterSpacing: 0,
          boxShadow: "0 8px 24px rgba(0,0,0,0.32)",
        }}
      >
        {scene.label}
      </div>
    </AbsoluteFill>
  );
};

const HookCard: React.FC<{config: NewsConfig}> = ({config}) => {
  const hook = config.hook;
  if (!hook) {
    return null;
  }
  const source = hook.image ?? config.scenes[0].image;
  const parts = hook.highlight
    ? hook.text.split(hook.highlight)
    : [hook.text];

  return (
    <AbsoluteFill>
      <Img
        src={staticFile(`${config.assetRoot}/${source}`)}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: hook.position ?? "center 38%",
          scale: 1.06,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            `linear-gradient(180deg, ${shade(0.62)} 0%, ${shade(0.12)} 26%, ${shade(0.2)} 52%, ${shade(0.92)} 84%, ${THEME.backgroundColor} 100%)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 104,
          left: 54,
          padding: "9px 18px 10px",
          borderRadius: 6,
          backgroundColor: THEME.badgeColor,
          color: THEME.badgeTextColor,
          fontSize: 34,
          fontWeight: 900,
        }}
      >
        {CHANNEL_NAME}
      </div>
      <div
        style={{
          position: "absolute",
          left: 56,
          right: 56,
          bottom: 300,
          fontSize: 132,
          fontWeight: 900,
          lineHeight: 1.06,
          letterSpacing: -2,
          whiteSpace: "pre-wrap",
          wordBreak: "keep-all",
          textShadow: "0 6px 26px rgba(0,0,0,0.9)",
        }}
      >
        {parts.map((part, index) => (
          <React.Fragment key={index}>
            {part}
            {hook.highlight && index < parts.length - 1 ? (
              <span
                style={{
                  backgroundColor: THEME.hookHighlightColor,
                  color: THEME.highlightTextColor,
                  padding: "0 12px",
                  borderRadius: 8,
                  boxDecorationBreak: "clone",
                  WebkitBoxDecorationBreak: "clone",
                }}
              >
                {hook.highlight}
              </span>
            ) : null}
          </React.Fragment>
        ))}
      </div>
    </AbsoluteFill>
  );
};

const TopHeader: React.FC<{config: NewsConfig}> = ({config}) => {
  const isShortsSafeV2 = config.layoutPreset === "shorts-safe-v2";

  return (
    <div
      style={{
        position: "absolute",
        top: isShortsSafeV2 ? 104 : 18,
        left: 54,
        right: 54,
        height: isShortsSafeV2 ? 262 : 218,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        gap: isShortsSafeV2 ? 13 : 9,
        textShadow: "0 4px 18px rgba(0,0,0,0.76)",
      }}
    >
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 22,
      }}
    >
      <div
        style={{
          padding: "7px 14px 8px",
          borderRadius: 5,
          backgroundColor: THEME.badgeColor,
          color: THEME.badgeTextColor,
          fontSize: 30,
          fontWeight: 900,
          letterSpacing: 0,
        }}
      >
        {CHANNEL_NAME}
      </div>
      <div
        style={{
          color: THEME.taglineColor,
          fontSize: THEME.taglineSize,
          fontWeight: 800,
          letterSpacing: 0,
        }}
      >
        {CHANNEL_TAGLINE}
      </div>
    </div>
    <div
      style={{
        // 영상별 titleSize(없으면 78)에 theme.json 의 titleSizeAdjust 를 더한다.
        fontSize: fontSizeWithAdjust(config.titleSize ?? 78, THEME.titleSizeAdjust),
        color: THEME.titleColor,
        fontWeight: 900,
        lineHeight: isShortsSafeV2 ? 1.02 : 0.95,
        letterSpacing: 0,
        whiteSpace: "pre-wrap",
        wordBreak: "keep-all",
      }}
    >
      {config.title}
    </div>
    </div>
  );
};

const CaptionOverlay: React.FC<{
  config: NewsConfig;
  captions: Caption[];
  timeMs: number;
}> = ({config, captions, timeMs}) => {
  const {fps} = useVideoConfig();
  const isShortsSafeV2 = config.layoutPreset === "shorts-safe-v2";
  const active = useMemo(
    () =>
      captions.find(
        (caption) => timeMs >= caption.startMs && timeMs < caption.endMs,
      ) ?? captions[captions.length - 1],
    [captions, timeMs],
  );
  const localFrame = ((timeMs - active.startMs) / 1000) * fps;
  const opacity = interpolate(localFrame, [0, 4], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const translateY = interpolate(localFrame, [0, 6], [12, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });
  // 영상별 captionSize(없으면 76)에 theme.json 의 captionSizeAdjust 를 더한다.
  const baseFontSize = fontSizeWithAdjust(
    config.captionSize ?? 76,
    THEME.captionSizeAdjust,
  );
  const fontSize =
    active.text.length > 58
      ? baseFontSize - 10
      : active.text.length > 48
        ? baseFontSize - 6
        : baseFontSize;

  return (
    <div
      style={{
        position: "absolute",
        top: isShortsSafeV2 ? 1120 : 910,
        left: 62,
        right: 184,
        minHeight: isShortsSafeV2 ? 500 : 450,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        opacity,
        translate: `0 ${translateY}px`,
      }}
    >
      <div
        style={{
          width: "100%",
          padding: isShortsSafeV2 ? "28px 24px 32px" : "40px 28px 44px",
          borderRadius: 8,
          backgroundColor: THEME.captionBoxColor,
          outline: "2px solid rgba(255,255,255,0.32)",
          boxShadow: "0 28px 86px rgba(0,0,0,0.72)",
          color: THEME.captionTextColor,
          fontSize,
          fontWeight: 900,
          lineHeight: isShortsSafeV2 ? 1.1 : 1.16,
          letterSpacing: 0,
          textAlign: "center",
          whiteSpace: "pre-wrap",
          wordBreak: "keep-all",
          overflowWrap: "break-word",
          textShadow: CAPTION_TEXT_SHADOW,
        }}
      >
        {splitWithHighlights(active.text, config.highlightTerms)}
      </div>
    </div>
  );
};

const splitWithHighlights = (
  text: string,
  highlightTerms: string[],
): React.ReactNode[] => {
  const sorted = [...highlightTerms].sort((a, b) => b.length - a.length);
  const escaped = sorted.map((term) =>
    term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
  );
  const parts = text.split(new RegExp(`(${escaped.join("|")})`, "g"));

  return parts.map((part, index) => {
    if (!sorted.includes(part)) {
      return <React.Fragment key={`${part}-${index}`}>{part}</React.Fragment>;
    }

    return (
      <span
        key={`${part}-${index}`}
        style={{
          color: THEME.highlightTextColor,
          backgroundColor: THEME.highlightColor,
          borderRadius: 5,
          padding: "0 9px 2px",
          boxDecorationBreak: "clone",
          WebkitBoxDecorationBreak: "clone",
          textShadow: "none",
        }}
      >
        {part}
      </span>
    );
  });
};

const ProgressBar: React.FC<{config: NewsConfig}> = ({config}) => {
  const frame = useCurrentFrame();
  const progress = frame / config.durationInFrames;

  return (
    <div
      style={{
        position: "absolute",
        left: 72,
        right: 184,
        bottom: 286,
        height: 8,
        borderRadius: 999,
        overflow: "hidden",
        backgroundColor: "rgba(255,255,255,0.22)",
      }}
    >
      <div
        style={{
          width: `${Math.min(100, progress * 100)}%`,
          height: "100%",
          backgroundColor: THEME.badgeColor,
        }}
      />
    </div>
  );
};
