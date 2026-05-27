import "./index.css";
import { Composition } from "remotion";
import { QuickPodGuideComposition } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="QuickPodGuide"
        component={QuickPodGuideComposition}
        durationInFrames={780}
        fps={30}
        width={1280}
        height={720}
      />
    </>
  );
};
