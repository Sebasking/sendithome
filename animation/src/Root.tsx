import React from "react";
import { Composition, Folder } from "remotion";
import { SendItHomeVideo } from "./SendItHomeVideo";
import { Journey } from "./scenes/Journey";
import { EndCard } from "./scenes/EndCard";

export const RemotionRoot: React.FC = () => (
  <>
    <Folder name="SendItHome-Scenes">
      <Composition id="Journey" component={Journey} width={1920} height={1080} fps={30} durationInFrames={330} />
      <Composition id="EndCard" component={EndCard} width={1920} height={1080} fps={30} durationInFrames={90} />
    </Folder>
    <Composition id="SendItHomeJourney" component={SendItHomeVideo} width={1920} height={1080} fps={30} durationInFrames={405} />
  </>
);
