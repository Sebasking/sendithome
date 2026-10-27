import { loadFont } from "@remotion/fonts";
import { staticFile } from "remotion";

export const fontFamily = "Outfit";

loadFont({
  family: "Outfit",
  url: staticFile("Outfit.ttf"),
  weight: "100 900",
});
