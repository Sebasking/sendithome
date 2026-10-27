import React from "react";

// Brand palette
export const C = {
  teal: "#0E6B6B",
  tealLight: "#3E9A97",
  orange: "#E8743B",
  ink: "#10292B",
  ground: "#F5F8F7",
};

// A shipping barrel. Origin = bottom centre.
export const Barrel: React.FC<{ x: number; y: number; rotate?: number }> = ({
  x,
  y,
  rotate = 0,
}) => (
  <g transform={`translate(${x} ${y}) rotate(${rotate} 0 -45)`}>
    <ellipse cx="0" cy="-3" rx="31" ry="7" fill="#B9542A" />
    <path d="M-30 -86 Q-39 -45 -30 -4 L30 -4 Q39 -45 30 -86 Z" fill={C.orange} />
    <path d="M-34 -64 Q0 -57 34 -64" stroke={C.ink} strokeWidth="5" fill="none" strokeLinecap="round" />
    <path d="M-34 -27 Q0 -20 34 -27" stroke={C.ink} strokeWidth="5" fill="none" strokeLinecap="round" />
    <ellipse cx="0" cy="-86" rx="30" ry="8" fill={C.ink} />
    <ellipse cx="9" cy="-87" rx="5" ry="2.2" fill={C.orange} />
  </g>
);

// Flatbed truck. Origin = centre of the bed top surface.
export const Truck: React.FC<{ x: number; y: number; body: string; cab: string }> = ({
  x,
  y,
  body,
  cab,
}) => (
  <g transform={`translate(${x} ${y})`}>
    <rect x="-95" y="0" width="190" height="30" rx="4" fill={body} />
    <path d="M95 30 L95 -46 Q95 -60 109 -60 L160 -60 Q172 -60 178 -48 L196 -10 Q200 -4 200 4 L200 30 Z" fill={cab} />
    <path d="M110 -48 L156 -48 Q163 -48 167 -41 L180 -14 L110 -14 Z" fill="#CFE9EC" />
    <rect x="180" y="10" width="16" height="8" rx="3" fill="#F6C453" />
    <circle cx="-50" cy="38" r="24" fill={C.ink} />
    <circle cx="-50" cy="38" r="9" fill="#9FB8B6" />
    <circle cx="150" cy="38" r="24" fill={C.ink} />
    <circle cx="150" cy="38" r="9" fill="#9FB8B6" />
  </g>
);

// Cargo ship. Origin = centre of the deck line.
export const Ship: React.FC<{ x: number; y: number }> = ({ x, y }) => (
  <g transform={`translate(${x} ${y})`}>
    <rect x="-245" y="-130" width="95" height="130" rx="6" fill="#FFFFFF" />
    <rect x="-225" y="-112" width="22" height="18" rx="3" fill="#9FC9CC" />
    <rect x="-192" y="-112" width="22" height="18" rx="3" fill="#9FC9CC" />
    <rect x="-225" y="-80" width="22" height="18" rx="3" fill="#9FC9CC" />
    <rect x="-192" y="-80" width="22" height="18" rx="3" fill="#9FC9CC" />
    <rect x="-218" y="-168" width="26" height="40" rx="3" fill={C.orange} />
    <rect x="15" y="-60" width="70" height="60" rx="3" fill={C.teal} />
    <rect x="90" y="-60" width="70" height="60" rx="3" fill={C.orange} />
    <rect x="165" y="-60" width="70" height="60" rx="3" fill="#2E5E8C" />
    <rect x="52" y="-118" width="70" height="56" rx="3" fill="#2E5E8C" />
    <rect x="127" y="-118" width="70" height="56" rx="3" fill={C.teal} />
    <path d="M-265 0 L270 0 L232 140 L-228 140 Z" fill={C.ink} />
    <path d="M-252 52 L262 52 L256 72 L-245 72 Z" fill="#C0503A" />
    <rect x="-265" y="-6" width="535" height="10" rx="3" fill="#E9EFEE" />
  </g>
);

export const House: React.FC<{
  x: number;
  y: number;
  wall: string;
  roof: string;
  door: string;
  flip?: boolean;
}> = ({ x, y, wall, roof, door, flip = false }) => (
  <g transform={`translate(${x} ${y}) scale(${flip ? -1 : 1} 1)`}>
    <rect x="-130" y="-170" width="260" height="170" fill={wall} />
    <path d="M-155 -165 L0 -265 L155 -165 Z" fill={roof} />
    <rect x="-95" y="-105" width="55" height="105" rx="4" fill={door} />
    <circle cx="-50" cy="-52" r="4" fill={C.ground} />
    <rect x="10" y="-130" width="80" height="62" rx="4" fill="#CFE9EC" />
    <path d="M50 -130 V-68 M10 -99 H90" stroke={wall} strokeWidth="6" />
  </g>
);

export const Palm: React.FC<{ x: number; y: number; s?: number }> = ({ x, y, s = 1 }) => (
  <g transform={`translate(${x} ${y}) scale(${s})`}>
    <path d="M0 0 Q-14 -120 18 -250" stroke="#8A5A3B" strokeWidth="20" fill="none" strokeLinecap="round" />
    <path d="M18 -250 Q-70 -300 -150 -230 Q-70 -260 18 -250 Z" fill="#2F7D4A" />
    <path d="M18 -250 Q100 -310 180 -240 Q100 -265 18 -250 Z" fill="#2F7D4A" />
    <path d="M18 -250 Q-30 -340 -100 -330 Q-30 -300 18 -250 Z" fill="#3C9659" />
    <path d="M18 -250 Q70 -350 140 -330 Q70 -300 18 -250 Z" fill="#3C9659" />
    <path d="M18 -250 Q40 -200 30 -140 Q30 -210 18 -250 Z" fill="#2F7D4A" />
    <circle cx="10" cy="-240" r="9" fill="#6B4A2C" />
    <circle cx="28" cy="-238" r="9" fill="#6B4A2C" />
  </g>
);

export const Cloud: React.FC<{ x: number; y: number; s?: number }> = ({ x, y, s = 1 }) => (
  <g transform={`translate(${x} ${y}) scale(${s})`} fill="#FFFFFF" opacity="0.9">
    <ellipse cx="0" cy="0" rx="90" ry="34" />
    <ellipse cx="-45" cy="-14" rx="48" ry="36" />
    <ellipse cx="35" cy="-26" rx="56" ry="44" />
  </g>
);
