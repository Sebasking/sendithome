import React from "react";
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { fontFamily } from "../fonts";
import { Barrel, C, Cloud, House, Palm, Ship, Truck } from "./Props";

const io = Easing.inOut(Easing.cubic);
const up = Easing.out(Easing.quad);
const down = Easing.in(Easing.quad);
const lin = Easing.linear;
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// Barrel journey keyframes (world coordinates). 0–40 pickup, 40–90 drive to port,
// 90–110 load onto ship, 110–230 sail, 230–250 unload, 250–290 drive, 290–305 delivered.
const F = [0, 15, 28, 40, 90, 100, 110, 230, 240, 250, 290, 298, 305];
const BX = [430, 430, 535, 640, 1500, 1730, 1960, 4250, 4475, 4700, 5150, 5280, 5400];
const BY = [800, 800, 690, 738, 738, 560, 720, 720, 580, 728, 728, 690, 790];
const ROT = [0, 0, -12, 0, 0, 10, 0, 0, -10, 0, 0, 8, 0];

const buildings: [number, number, number][] = [
  [0, 140, 330], [150, 110, 420], [600, 160, 380], [780, 120, 470],
  [920, 180, 300], [1120, 130, 430], [1270, 160, 350], [1450, 110, 260],
];

export const Journey: React.FC = () => {
  const frame = useCurrentFrame();

  const bx = interpolate(frame, F, BX, {
    ...clamp,
    easing: [io, lin, lin, io, lin, lin, io, lin, lin, io, lin, lin],
  });
  const sailing = frame >= 110 && frame <= 230;
  const bob = sailing ? Math.sin((frame - 110) / 7) * 5 : 0;
  const by =
    interpolate(frame, F, BY, {
      ...clamp,
      easing: [io, up, down, io, up, down, io, up, down, io, up, down],
    }) + bob;
  const rot = interpolate(frame, F, ROT, clamp);

  const truckA = interpolate(frame, [40, 90], [640, 1500], { ...clamp, easing: io });
  const ship = interpolate(frame, [110, 230], [2000, 4290], { ...clamp, easing: io });
  const truckB = interpolate(frame, [250, 290], [4700, 5150], { ...clamp, easing: io });
  const cam = interpolate(
    frame,
    [0, 40, 90, 110, 230, 250, 290],
    [0, 0, 600, 1060, 3350, 3800, 3840],
    { ...clamp, easing: io },
  );
  const badge = interpolate(frame, [305, 318], [0, 1], {
    ...clamp,
    easing: Easing.out(Easing.back(1.8)),
  });

  return (
    <AbsoluteFill style={{ backgroundColor: C.ground }}>
      <svg viewBox="0 0 1920 1080" width="1920" height="1080">
        <defs>
          <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#BFE3E6" />
            <stop offset="1" stopColor="#F5F8F7" />
          </linearGradient>
        </defs>
        <g transform={`translate(${-cam} 0)`}>
          {/* Sky, sun, clouds */}
          <rect x="0" y="0" width="5760" height="840" fill="url(#sky)" />
          <circle cx="4950" cy="250" r="150" fill="#F6C453" opacity="0.25" />
          <circle cx="4950" cy="250" r="95" fill="#F6C453" />
          <Cloud x={500 + frame * 0.4} y={180} />
          <Cloud x={1350 + frame * 0.3} y={270} s={0.8} />
          <Cloud x={2450 + frame * 0.4} y={170} s={1.1} />
          <Cloud x={3350 + frame * 0.3} y={250} s={0.9} />
          <Cloud x={4250 + frame * 0.4} y={150} />
          <Cloud x={5350 + frame * 0.3} y={230} s={0.8} />

          {/* Pickup: the city */}
          {buildings.map(([x, w, h]) => (
            <rect key={x} x={x} y={800 - h} width={w} height={h} fill="#A9C1BF" />
          ))}
          <House x={330} y={800} wall="#F2E3C9" roof="#0B5555" door={C.orange} />
          <rect x="0" y="800" width="1720" height="280" fill="#B9CBC8" />
          <rect x="0" y="800" width="1720" height="12" fill="#DDE6E4" />
          <rect x="1600" y="800" width="18" height="110" fill="#5E4634" />
          <rect x="1680" y="800" width="18" height="110" fill="#5E4634" />

          {/* The sea (back) */}
          <rect x="1700" y="830" width="2920" height="250" fill={C.teal} />

          {/* Delivery: the island */}
          <path d="M4560 834 Q4610 790 4700 790 L5760 790 L5760 1080 L4520 1080 Z" fill="#F1D9A8" />
          <rect x="4900" y="790" width="860" height="290" fill="#5EA36A" />
          <rect x="4900" y="790" width="860" height="14" fill="#7DBA84" />
          <rect x="4520" y="800" width="18" height="100" fill="#5E4634" />
          <Palm x={4930} y={796} s={0.9} />
          <House x={5575} y={790} wall="#F7C9A0" roof="#C0503A" door={C.teal} />
          <Palm x={5740} y={792} s={1.1} />

          {/* Ship, then the front of the sea so the hull sits in the water */}
          <Ship x={ship} y={720 + bob} />
          <rect x="1700" y="846" width="2860" height="234" fill={C.teal} />
          <path d="M4560 846 L4620 846 L4600 1080 L4540 1080 Z" fill={C.teal} />
          {[872, 936, 1010].map((y, i) => (
            <path
              key={y}
              d={`M1700 ${y} H4560`}
              stroke={C.tealLight}
              strokeWidth="5"
              strokeLinecap="round"
              strokeDasharray="46 74"
              strokeDashoffset={-frame * (2 + i)}
            />
          ))}

          {/* Vehicles and the barrel */}
          <Truck x={truckA} y={738} body="#0B5555" cab={C.teal} />
          <Truck x={truckB} y={728} body="#B9542A" cab={C.orange} />
          <Barrel x={bx} y={by} rotate={rot} />

          {/* Delivered badge */}
          <g transform={`translate(5400 600) scale(${badge})`}>
            <circle cx="0" cy="0" r="56" fill={C.teal} />
            <path d="M-24 2 L-6 20 L26 -16" stroke="#FFFFFF" strokeWidth="11" fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </g>
        </g>
      </svg>

      <Interactive.Div
        name="Caption: pickup"
        style={{
          position: "absolute",
          top: 110,
          width: "100%",
          textAlign: "center",
          fontFamily,
          fontWeight: 700,
          fontSize: 96,
          letterSpacing: "-0.02em",
          color: "#10292B",
          opacity: interpolate(frame, [5, 20, 80, 95], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: [Easing.bezier(0.16, 1, 0.3, 1), Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          translate: interpolate(frame, [5, 20], ["0px 24px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Picked up from home
      </Interactive.Div>
      <Interactive.Div
        name="Caption: sea"
        style={{
          position: "absolute",
          top: 110,
          width: "100%",
          textAlign: "center",
          fontFamily,
          fontWeight: 700,
          fontSize: 96,
          letterSpacing: "-0.02em",
          color: "#10292B",
          opacity: interpolate(frame, [110, 125, 215, 230], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: [Easing.bezier(0.16, 1, 0.3, 1), Easing.linear, Easing.bezier(0.16, 1, 0.3, 1)],
          }),
          translate: interpolate(frame, [110, 125], ["0px 24px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Shipped across the sea
      </Interactive.Div>
      <Interactive.Div
        name="Caption: delivered"
        style={{
          position: "absolute",
          top: 110,
          width: "100%",
          textAlign: "center",
          fontFamily,
          fontWeight: 700,
          fontSize: 96,
          letterSpacing: "-0.02em",
          color: "#10292B",
          opacity: interpolate(frame, [255, 270], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [255, 270], ["0px 24px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Delivered to family
      </Interactive.Div>
    </AbsoluteFill>
  );
};
