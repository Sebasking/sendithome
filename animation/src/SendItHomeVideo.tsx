import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { Journey } from "./scenes/Journey";
import { EndCard } from "./scenes/EndCard";

export const SendItHomeVideo: React.FC = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence name="Journey" durationInFrames={330}>
      <Journey />
    </TransitionSeries.Sequence>
    <TransitionSeries.Transition
      presentation={fade()}
      timing={linearTiming({ durationInFrames: 15 })}
    />
    <TransitionSeries.Sequence name="End card" durationInFrames={90}>
      <EndCard />
    </TransitionSeries.Sequence>
  </TransitionSeries>
);
