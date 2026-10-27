import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { fontFamily } from "../fonts";

export const EndCard: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill
      name="End card"
      style={{
        backgroundColor: "#F5F8F7",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        gap: 28,
        fontFamily,
      }}
    >
      <Interactive.Div
        name="Logo mark"
        style={{
          width: 180,
          height: 207,
          scale: interpolate(frame, [0, 18], [0.6, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 200 }),
            output: "perceptual-scale",
          }),
          opacity: interpolate(frame, [0, 10], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        <svg viewBox="20 8 160 184" width="180" height="207">
          <path fill="#0E6B6B" d="M45 28 C30 62 30 98 50 124 L100 188 L150 124 C170 98 170 62 155 28 Z" />
          <ellipse cx="100" cy="28" rx="55" ry="13" fill="#E8743B" />
          <path d="M44 62 Q100 76 156 62" fill="none" stroke="#FFFFFF" strokeWidth="8" strokeLinecap="round" />
          <path d="M47 104 Q100 118 153 104" fill="none" stroke="#FFFFFF" strokeWidth="8" strokeLinecap="round" />
        </svg>
      </Interactive.Div>
      <Interactive.Div
        name="Wordmark"
        style={{
          fontSize: 150,
          fontWeight: 700,
          letterSpacing: "-0.03em",
          lineHeight: 1,
          color: "#10292B",
          opacity: interpolate(frame, [8, 22], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [8, 22], ["0px 30px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        SendIt<span style={{ color: "#0E6B6B" }}>Home</span>
      </Interactive.Div>
      <Interactive.Div
        name="Tagline"
        style={{
          fontSize: 60,
          fontWeight: 500,
          color: "#4A5F61",
          opacity: interpolate(frame, [18, 32], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Find your Caribbean shipper
      </Interactive.Div>
      <Interactive.Div
        name="URL"
        style={{
          marginTop: 12,
          fontSize: 54,
          fontWeight: 700,
          color: "#0E6B6B",
          opacity: interpolate(frame, [28, 42], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        sendithome.net
      </Interactive.Div>
    </AbsoluteFill>
  );
};
