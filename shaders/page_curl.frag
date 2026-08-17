#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uProgress;
uniform vec2 uPointer;
uniform float uDirection;
uniform float uRadius;
uniform float uShadow;
uniform sampler2D uFront;
uniform sampler2D uBack;

out vec4 fragColor;

const float kPi = 3.14159265359;

// How far round the roll the leaf goes.
//
// Always past a half turn, so what faces the reader is always the back of the
// leaf. Under a half turn the front face is visible too and the mapping needs
// a second branch for it; a page being turned is never at rest there, and
// paying for that branch on every pixel of every frame to serve the first two
// millimetres of the movement is not a trade worth making.
const float kMinSweep = 3.20;
const float kMaxSweep = 4.60;

// How much of a leaf's own printing comes through its back.
//
// Low. Measured on the phone rather than guessed: at 0.10 the reversed text on
// the roll was comfortably readable, and readable is wrong. Print seen through
// paper is a suggestion of where the ink is, and it is soft, whereas this is
// sampled sharp. Amplitude is the only lever available without a blur pass, so
// it is kept below the level at which the eye starts resolving words.
const float kBleed = 0.045;

// Where the paper of the sheet is read from: its two side margins, at the row
// being drawn. A page has nothing printed there in any theme, so this is the
// colour of the paper itself rather than of whatever is set on it.
const float kMargin = 0.025;

// One light, high and a little behind the reader.
const vec2 kLight = vec2(-0.18, 0.9837);

// Half the width of every softened edge, in pixels.
const float kSoft = 0.75;

void main() {
  vec2 pixel = FlutterFragCoord().xy;
  float width = max(uSize.x, 1.0);
  float height = max(uSize.y, 1.0);

  // Canonical space: x runs from the free edge of the leaf at 0 to the bound
  // edge at width, whichever way round the interface reads. Mirroring here
  // means right-to-left costs a sign, not a second code path.
  float rightward = step(0.0, uDirection);
  float x = mix(width - pixel.x, pixel.x, rightward);
  float pointerX = mix(width - uPointer.x, uPointer.x, rightward);
  float pointerY = clamp(uPointer.y, 0.0, height);

  float progress = clamp(uProgress, 0.0, 1.0);

  // The fold is where the sheet leaves the flat plane. Everything behind it is
  // material that has already been taken up into the roll, so the fold is a
  // length of paper as much as it is a place. The pointer owns most of it, so
  // the paper stays under the finger.
  float fold = mix(progress * width, clamp(pointerX, 0.0, width), 0.78);
  // A fold square to the page reads as a guillotine. It leans with the finger.
  fold += (pixel.y - pointerY) / height * uRadius * 0.34;
  fold = clamp(fold, 0.0, width);

  // The roll gives its material back over the last quarter of the turn, so the
  // leaf arrives flat against the far side instead of as a barrel at the spine.
  // Nothing else is needed to make the two ends of the turn resolve flat: at
  // progress 0 there is no material to roll, and at 1 there is none left.
  float taper = 1.0 - smoothstep(0.72, 1.0, progress);
  float rolled = fold * taper;

  // uRadius is the stiffness of the sheet. A board rolls loose and wide, paper
  // rolls tight. The sweep is held constant per turn and the radius follows the
  // material, which is why the roll grows as the page comes across instead of
  // wrapping itself into a scroll.
  float sweep = clamp(260.0 / max(uRadius, 1.0), kMinSweep, kMaxSweep);
  float radius = max(rolled / sweep, 0.35);

  // Where the leaf runs out. Past a half turn it overhangs the page it came
  // off, which is what puts a shadow on paper that has not been turned yet.
  float freeEdge = fold - radius * sin(sweep);

  // The angle round the cylinder of the surface facing the reader. Of the two
  // places the sheet crosses this pixel, this is the nearer.
  float d = fold - x;
  float a = asin(clamp(abs(d) / radius, 0.0, 1.0));
  float theta = kPi + mix(a, -a, step(0.0, d));

  // The two silhouettes of the roll, each softened by a pixel. The last factor
  // retires the roll once it is thinner than the pixels available to draw it:
  // below that it is a row of dashes crawling along the spine, not a curl.
  float rollNear = smoothstep(fold - radius - kSoft, fold - radius + kSoft, x);
  float rollFar = 1.0 - smoothstep(freeEdge - kSoft, freeEdge + kSoft, x);
  float rollMask = rollNear * rollFar * smoothstep(0.6, 2.5, radius);
  float frontMask = 1.0 - rollFar;

  vec2 uv = clamp(pixel / max(uSize, vec2(1.0)), 0.0, 1.0);
  vec4 front = texture(uFront, uv);
  vec4 back = texture(uBack, uv);

  // The printed face of the rolled material, read back along the arc. Arc
  // length is the material coordinate, so the foreshortening near the
  // silhouette comes out of the geometry rather than being drawn in.
  float source = clamp((fold - radius * theta) / width, 0.0, 1.0);
  vec2 sourceUv = vec2(mix(1.0 - source, source, rightward), uv.y);
  vec3 recto = texture(uFront, sourceUv).rgb;

  // The back of a leaf is the paper of that leaf, with its own printing barely
  // coming through. The paper is read from the sheet's own side margins on the
  // row being drawn, which is what keeps this right on cream, on a black
  // reading theme, and on a cover board alike - and, because both taps are on
  // the same row, adds no structure of its own down the roll.
  vec3 sheet = 0.5 * (
    texture(uFront, vec2(kMargin, uv.y)).rgb
    + texture(uFront, vec2(1.0 - kMargin, uv.y)).rgb
  );
  // Show-through is faded where it cannot honestly be drawn: the material
  // compresses without limit toward the silhouette, and a roll only a few
  // pixels across holds the whole remaining page. Sampling either is aliasing
  // wearing the clothes of detail.
  float grazing = 1.0 - smoothstep(0.55, 0.95, clamp(abs(d) / radius, 0.0, 1.0));
  float bleed = kBleed * grazing * smoothstep(8.0, 40.0, radius);
  vec3 verso = mix(sheet, recto, bleed);

  // A real cylinder, lit once. The normal is the angle round the roll, so the
  // shading is the geometry rather than a gradient laid over the top of it.
  // Diffuse, and never brighter than the paper it is made of: paper has no
  // mirror in it, and a specular band across the roll reads as satin or as
  // chrome, which was exactly what the first cut of this looked like.
  vec2 normal = vec2(-sin(theta), -cos(theta));
  float lambert = clamp(dot(normal, kLight), 0.0, 1.0);
  verso *= 0.46 + 0.52 * lambert;
  verso += vec3(0.035 * pow(lambert, 8.0));

  float shadow = clamp(uShadow, 0.0, 1.0);

  // The roll stands away from the page it has uncovered, so what it drops there
  // is a hard contact line inside a wide soft one.
  float gapNear = max(fold - radius - x, 0.0);
  float contact = 1.0 - smoothstep(0.0, max(radius * 0.20, 2.0), gapNear);
  float ambient =
    1.0 - smoothstep(0.0, max(radius * 1.45, width * 0.05), gapNear);
  float underRoll =
    clamp(contact * 0.55 + ambient * 0.62, 0.0, 1.0) * (1.0 - rollNear);
  // Composited toward opaque black rather than multiplied into the colour, so
  // that a caller may hand in a *transparent* page below and get a real shadow
  // on whatever is actually behind this widget. The reader does exactly that:
  // its destination page is the live WebView, not a picture of one. For an
  // opaque page below the two are identical - alpha stays 1 and the colour is
  // still scaled by (1 - s).
  back = mix(back, vec4(0.0, 0.0, 0.0, 1.0), 0.60 * shadow * underRoll);

  // And the overhanging edge drops a narrow one on the page still to turn.
  float gapFar = max(x - freeEdge, 0.0);
  float overhang =
    (1.0 - smoothstep(0.0, max(radius * 0.42, 3.0), gapFar)) * frontMask;
  front = mix(front, vec4(0.0, 0.0, 0.0, 1.0), 0.34 * shadow * overhang);

  vec4 color = mix(back, front, frontMask);
  fragColor = mix(color, vec4(verso, 1.0), rollMask);
}
