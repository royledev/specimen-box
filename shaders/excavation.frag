#version 460 core
#include <flutter/runtime_effect.glsl>
precision mediump float;

// =============================================================================
// excavation.frag — 「発掘」演出の背景レイヤー
//   土砂下地 → 埋没リビール(砂が退く) → 亀裂(封蝋を割る)＋発光エッジ →
//   砂パーティクル → グロー(加算) → ビネット
// すべて手続き生成（外部テクスチャ無し）。フェーズは進行度 uniform で駆動する。
//
// t=0（uCrack=uDissolve=uBloom=0）は「埋もれた箱＋封蝋エンブレム」の静止画で、
// uCrack で封蝋が中心から割れ、uDissolve で砂が退く。
// （旧 seal.frag との連続性契約は廃止済み＝ADR-0021 Deprecated。本シェーダは自己完結。
//   「★SHARED」表記は当時の共有ブロックの名残で、現在は本ファイル内で完結する。）
// =============================================================================

// --- uniforms（宣言順 = Dart の setFloat index。vec2 は float 2 つ分を消費）---
uniform vec2  uSize;     // index 0,1 : 解像度(px)
uniform float uTime;     // index 2   : 連続秒（砂ドリフト）
uniform float uCrack;    // index 3   : 亀裂の成長 0..1（封蝋を割る）
uniform float uDissolve; // index 4   : 埋没リビール 0..1（砂が下へ退く）
uniform float uBloom;    // index 5   : グロー強度 0..1
uniform float uSeed;     // index 6   : 乱数シード（seal と同値）

out vec4 fragColor;

// --- ★SHARED 配色（sRGB/255。マットで低彩度。強彩度は封蝋の朱と琥珀のみ）---
const vec3 C_DUST  = vec3(0.839, 0.765, 0.631); // 砂埃   #D6C3A1
const vec3 C_SOIL  = vec3(0.431, 0.290, 0.173); // 焼けた土 #6E4A2C
const vec3 C_TERRA = vec3(0.710, 0.384, 0.235); // テラコッタ #B5623C
const vec3 C_OCHRE = vec3(0.788, 0.573, 0.243); // 黄土   #C9923E
const vec3 C_VERM  = vec3(0.698, 0.227, 0.180); // 朱（封蝋）#B23A2E
const vec3 C_AMBER = vec3(0.949, 0.753, 0.290); // 琥珀グロー #F2C04A

// --- ★SHARED チューニング定数 ----------------------------------------------
const int   FBM_OCTAVES = 5;
const float FBM_LACUNARITY = 2.0;
const float FBM_GAIN = 0.5;
const float CRACK_THRESHOLD = 0.045;
const vec2  SEAL_CENTER = vec2(0.5, 0.46);  // 封蝋＝亀裂の発生源（seal と一致）
const float SEAL_R = 0.14;
const float BURY_BASE = 0.58;
const float TAU = 6.2831853;
// 発掘クライマックスのグロー中心（標本がせり上がる位置・やや上）
const vec2  GLOW_CENTER = vec2(0.5, 0.42);

// =============================================================================
// ★SHARED ノイズ基盤
// =============================================================================
float hash21(vec2 p) {
  p = fract(p * 0.3183099 + 0.1);
  p *= 17.0;
  return fract(p.x * p.y * (p.x + p.y));
}

vec2 hash22(vec2 p) {
  p = fract(p * vec2(0.3183099, 0.3678794) + 0.1);
  p += dot(p, p.yx + 19.19);
  return fract(vec2(p.x * p.y, p.x + p.y));
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i + vec2(0.0, 0.0));
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float sum = 0.0, amp = 0.5, freq = 1.0;
  for (int i = 0; i < FBM_OCTAVES; i++) {
    sum += amp * vnoise(p * freq);
    freq *= FBM_LACUNARITY;
    amp *= FBM_GAIN;
  }
  return sum;
}

// ★SHARED Voronoi（F1,F2）— 3x3 セル探索。uSeed を含めて seal と種を共有。
vec2 voronoiF1F2(vec2 p) {
  vec2 g = floor(p);
  vec2 f = fract(p);
  float f1 = 8.0, f2 = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cell = vec2(float(x), float(y));
      vec2 seed = hash22(g + cell + uSeed);
      vec2 diff = cell + seed - f;
      float d = dot(diff, diff);
      if (d < f1) { f2 = f1; f1 = d; }
      else if (d < f2) { f2 = d; }
    }
  }
  return sqrt(vec2(f1, f2));
}

// ★SHARED 封蝋エンブレム SDF / サイギル（seal と一致）
float sealSDF(vec2 ap, vec2 sc, float r) { return length(ap - sc) - r; }
float sigilMask(vec2 ap, vec2 sc, float r) {
  float d = length(ap - sc);
  float ring = smoothstep(0.006, 0.0, abs(d - r * 0.55) - 0.004);
  float dot  = smoothstep(0.006, 0.0, d - r * 0.10);
  return clamp(ring + dot, 0.0, 1.0);
}

// =============================================================================
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;     // 0..1（y 下方向）
  float aspect = uSize.x / uSize.y;
  vec2 ap = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);

  // ★SHARED 砂のドリフト＋風紋（seal から uTime を継続）
  vec2 drift = vec2(uTime * 0.015, uTime * 0.006);
  float wind = sin(uv.x * 3.0 + uTime * 0.08) * 0.02;

  // ---------------------------------------------------------------------------
  // 1) ★SHARED 土砂下地：box（露出箱面）/ sand（砂埃）
  // ---------------------------------------------------------------------------
  float grain     = fbm((uv + drift) * 3.0 + vec2(0.0, wind));
  float grainFine = fbm((uv - drift * 1.7) * 9.0);
  vec3 box  = mix(C_SOIL, C_TERRA, smoothstep(0.35, 0.75, grain));
  box = mix(box, C_OCHRE, smoothstep(0.55, 0.95, grainFine) * 0.30);
  box = mix(box, C_VERM,  smoothstep(0.94, 0.99, grainFine) * 0.10);
  vec3 sand = mix(C_DUST, C_DUST * 0.82, grain * 0.6);

  // ---------------------------------------------------------------------------
  // 2) 埋没リビール（★SHARED 基本式 ＋ uDissolve で line を下へ）
  //    uDissolve=0 → seal と同じ埋没。uDissolve=1 → line が画面下へ＝全露出。
  // ---------------------------------------------------------------------------
  float perturb = fbm((uv + drift) * 5.0) * 0.12 - 0.06;
  float line = BURY_BASE + perturb;
  line = mix(line, 1.25, uDissolve);                       // 砂が退く
  float cover = smoothstep(line - 0.03, line + 0.03, uv.y); // 1=砂
  vec3 col = mix(box, sand, cover);
  // 砂が退く前縁を明るいブラシエッジに（発掘時のみ＝uDissolve でスケール）
  float brush = (1.0 - smoothstep(0.0, 0.05, abs(uv.y - line)))
              * smoothstep(0.01, 0.2, uDissolve) * (1.0 - smoothstep(0.9, 1.0, uDissolve));
  col += C_DUST * brush * 0.5;

  // ---------------------------------------------------------------------------
  // 4)（先に算出）封蝋中心・SDF。亀裂はこの封蝋を割る。
  // ---------------------------------------------------------------------------
  vec2 sc = vec2((SEAL_CENTER.x - 0.5) * aspect, SEAL_CENTER.y - 0.5);
  float R = SEAL_R;
  float ed = sealSDF(ap, sc, R);
  float emblem = smoothstep(0.004, -0.004, ed);
  float emblemAlpha = 1.0 - smoothstep(0.0, 0.65, uCrack); // uCrack で封蝋が崩れ消える

  // ---------------------------------------------------------------------------
  // 3) 亀裂＋発光エッジ（★SHARED Voronoi。中心＝封蝋から外へ伸長）
  // ---------------------------------------------------------------------------
  vec2 vor = voronoiF1F2(ap * 6.0 + 11.0);
  float border = vor.y - vor.x;
  float crackLine = 1.0 - smoothstep(CRACK_THRESHOLD, CRACK_THRESHOLD + 0.02, border);
  float radial = length(ap - sc);                          // 封蝋中心からの距離
  // 休眠亀裂（★SHARED：uCrack=0 で seal と完全一致）
  col = mix(col, C_SOIL * 0.4, crackLine * 0.06);
  // 活性亀裂（uCrack で封蝋中心から外へ広がる濃い溝）
  float reach = smoothstep(uCrack * 0.9 + 0.04, uCrack * 0.9 - 0.06, radial);
  float crack = crackLine * reach * uCrack;
  col = mix(col, C_SOIL * 0.30, crack * 0.9);
  // 亀裂のすぐ内側に琥珀の発光エッジ
  float amberRim = smoothstep(CRACK_THRESHOLD + 0.02, CRACK_THRESHOLD + 0.06, border)
                 * (1.0 - smoothstep(CRACK_THRESHOLD + 0.06, CRACK_THRESHOLD + 0.12, border));
  col += C_AMBER * amberRim * smoothstep(0.0, 0.6, uCrack) * 0.4;

  // ---------------------------------------------------------------------------
  // 4) ★SHARED 封蝋エンブレム＋浮き彫り（emblemAlpha で割れて消える）
  // ---------------------------------------------------------------------------
  float em = emblem * emblemAlpha;
  // 亀裂線で封蝋面を破断（割れ目を暗く）
  float fractured = em * (1.0 - crackLine * smoothstep(0.0, 0.5, uCrack));
  col = mix(col, C_VERM, fractured);
  vec2 nrm = normalize(ap - sc + vec2(1e-4));
  float lit = dot(nrm, normalize(vec2(-0.35, -0.85)));
  float rimBand = smoothstep(0.020, 0.0, abs(ed)) * emblemAlpha;
  col += C_DUST * rimBand * max(lit, 0.0) * 0.45;
  col = mix(col, C_SOIL * 0.25, rimBand * max(-lit, 0.0) * 0.5);
  float sig = sigilMask(ap, sc, R) * fractured;
  col = mix(col, C_VERM * 0.55, sig * 0.7);
  col += C_DUST * sig * max(lit, 0.0) * 0.3;
  // 封蝋の夢みるグロー（seal と同じ息づかい。uReady=1 相当・割れと共に消える）
  float breathe = 0.26 + 0.16 * (0.5 + 0.5 * sin(uTime * TAU / 4.0));
  float embRadial = 1.0 - smoothstep(0.0, 0.30, length(ap - sc));
  col += C_AMBER * embRadial * breathe * em * (1.0 - sig) * 1.1;
  col += C_AMBER * (1.0 - smoothstep(R, R * 2.0, length(ap - sc))) * breathe * 0.18 * emblemAlpha; // 外周の淡い暈し（seal と一致）

  // ---------------------------------------------------------------------------
  // 5) 砂パーティクル（退く境界付近を下方向に流れ落ちる点群）
  // ---------------------------------------------------------------------------
  vec2 pp = uv * vec2(40.0, 70.0);
  pp.y += uTime * 6.0 + uDissolve * 8.0;
  vec2 pid = floor(pp);
  vec2 pf = fract(pp);
  float ph = hash21(pid + uSeed);
  vec2 ppos = hash22(pid + 3.1) * 0.6 + 0.2;
  float pdot = smoothstep(0.18, 0.0, length(pf - ppos)) * step(0.55, ph);
  float nearEdge = 1.0 - smoothstep(0.0, 0.16, abs(uv.y - line)); // 退く境界付近
  float particles = pdot * nearEdge * smoothstep(0.02, 0.3, uDissolve) * (0.4 + 0.6 * ph);
  col += mix(C_DUST, C_OCHRE, ph) * particles * 0.8;

  // ---------------------------------------------------------------------------
  // 6) グロー（標本中心からの放射＋光条）— uBloom でスケールし加算
  // ---------------------------------------------------------------------------
  vec2 gc = vec2((GLOW_CENTER.x - 0.5) * aspect, GLOW_CENTER.y - 0.5);
  vec2 gd = ap - gc;
  float dist = length(gd);
  float radialGlow = 1.0 - smoothstep(0.0, 0.45, dist);
  float angle = atan(gd.y, gd.x);
  float rays = pow(0.5 + 0.5 * sin(angle * 12.0 + uTime * 0.5), 6.0);
  float bloom = (radialGlow * 0.9 + radialGlow * rays * 0.6) * uBloom;
  col += C_AMBER * bloom * 1.4;

  // ---------------------------------------------------------------------------
  // 7) ★SHARED 上方アンビエント光 ＋ ビネット（seal と一致）
  // ---------------------------------------------------------------------------
  col *= mix(0.94, 1.06, smoothstep(1.0, 0.0, uv.y));
  float vig = 1.0 - smoothstep(0.55, 1.15, length(uv - 0.5) * 1.6);
  col *= mix(0.82, 1.0, vig);

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
