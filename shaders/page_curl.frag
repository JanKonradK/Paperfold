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

vec4 sampleFront(vec2 uv) {
  return texture(uFront, clamp(uv, 0.0, 1.0));
}

vec4 sampleBack(vec2 uv) {
  return texture(uBack, clamp(uv, 0.0, 1.0));
}

void main() {
  vec2 pixel = FlutterFragCoord().xy;
  vec2 uv = clamp(pixel / max(uSize, vec2(1.0)), 0.0, 1.0);
  float width = max(uSize.x, 1.0);
  float radius = max(uRadius, 1.0);
  float progress = clamp(uProgress, 0.0, 1.0);

  // Work in a canonical left-to-right space. A negative direction mirrors
  // both geometry and sampling without requiring a widget rebuild.
  float rightward = step(0.0, uDirection);
  float x = mix(width - pixel.x, pixel.x, rightward);
  float pointerX = mix(width - uPointer.x, uPointer.x, rightward);
  float pointerY = clamp(uPointer.y / max(uSize.y, 1.0), 0.0, 1.0);

  // The visible arc contracts at both endpoints so progress 0 and 1 resolve
  // to fully flat pages. The width floor keeps the rolled sheet readable on
  // phone screens; the cap leaves room for the flat and revealed zones.
  float envelope = smoothstep(0.0, 0.08, progress)
    * (1.0 - smoothstep(0.92, 1.0, progress));
  float targetArc = min(
    max(radius * kPi * 2.2, width * 0.36),
    width * 0.55
  ) * envelope;

  // The pointer owns most of the fold position. A small lead proportional to
  // the arc makes room for the page below without detaching from the finger.
  float fold = mix(progress * width, clamp(pointerX, 0.0, width), 0.78);
  fold += targetArc * 0.20;
  fold += (uv.y - pointerY) * radius * 0.28;
  fold = clamp(fold, 0.0, width);

  // At most 76% of the turned area is curl. The remainder is always the page
  // below, producing flat front / curled sheet / revealed page as three zones.
  float arcWidth = max(0.75, min(targetArc, max(fold * 0.76, 0.75)));
  float distanceToFold = fold - x;
  float curlT = clamp(distanceToFold / arcWidth, 0.0, 1.0);

  float frontMask = 1.0 - smoothstep(-0.75, 0.75, distanceToFold);
  float curlStart = smoothstep(-0.75, 0.75, distanceToFold);
  float curlEnd = 1.0 - smoothstep(
    arcWidth - 0.75,
    arcWidth + 0.75,
    distanceToFold
  );
  float curlMask = curlStart * curlEnd * envelope;

  vec4 frontColor = sampleFront(uv);
  vec4 backColor = sampleBack(uv);

  // Map the turned part of the front page backwards across the curl. This
  // produces the mirrored back face without stretching a half-width atlas.
  float cylinderBulge = sin(curlT * kPi);
  float sourceX = fold * curlT
    + cylinderBulge * min(radius * 0.32, fold * 0.08);
  float sourceUvX = clamp(sourceX / width, 0.0, 1.0);
  sourceUvX = mix(1.0 - sourceUvX, sourceUvX, rightward);
  vec2 curledUv = vec2(sourceUvX, uv.y);
  vec4 curledColor = sampleFront(curledUv);

  // A bright outer ridge, rounded midtone, and dark inner face describe the
  // cylinder without per-pixel branches.
  float edgeLight = 1.0 - smoothstep(0.0, 0.20, curlT);
  float innerShade = smoothstep(0.48, 1.0, curlT);
  float cylinderLight = clamp(
    0.72 + 0.24 * cylinderBulge + 0.30 * edgeLight - 0.34 * innerShade,
    0.44,
    1.12
  );
  curledColor.rgb *= cylinderLight;
  curledColor.rgb += vec3(0.055) * edgeLight * envelope;

  // Combine a narrow contact shadow and a broad soft falloff on the page below.
  // Both start at the inner edge and follow the pointer-led fold.
  float shadowDistance = max(distanceToFold - arcWidth, 0.0);
  float contactShadow = 1.0 - smoothstep(
    0.0,
    max(radius * 0.70, width * 0.012),
    shadowDistance
  );
  float softShadow = 1.0 - smoothstep(
    0.0,
    max(radius * 3.20, width * 0.11),
    shadowDistance
  );
  float shadowBand = clamp(
    contactShadow * 0.38 + softShadow * 0.62,
    0.0,
    1.0
  ) * step(arcWidth, distanceToFold) * envelope;
  backColor.rgb *= 1.0 - 0.54 * clamp(uShadow, 0.0, 1.0) * shadowBand;

  vec4 color = mix(backColor, curledColor, curlMask);
  color = mix(color, frontColor, frontMask);
  fragColor = color;
}
