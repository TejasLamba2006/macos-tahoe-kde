#version 440

// Vertical Gaussian blur — mirror of blur_h along Y. See blur_h.frag for
// the tap-count / sigma-clamp rationale.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float radiusPx;
    vec2  sourceSizePx;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float px = 1.0 / sourceSizePx.y;

    float sigma = clamp(radiusPx / 3.0, 0.001, 3.1);
    float s2 = 2.0 * sigma * sigma;

    float t1  = sigma * (3.0  / 8.0);
    float t2  = sigma * (6.0  / 8.0);
    float t3  = sigma * (9.0  / 8.0);
    float t4  = sigma * (12.0 / 8.0);
    float t5  = sigma * (15.0 / 8.0);
    float t6  = sigma * (18.0 / 8.0);
    float t7  = sigma * (21.0 / 8.0);
    float t8  = sigma * (24.0 / 8.0);
    float t9  = sigma * (27.0 / 8.0);
    float t10 = sigma * (30.0 / 8.0);
    float t11 = sigma * (33.0 / 8.0);
    float t12 = sigma * (36.0 / 8.0);

    float g0  = 1.0;
    float g1  = exp(-(t1  * t1)  / s2);
    float g2  = exp(-(t2  * t2)  / s2);
    float g3  = exp(-(t3  * t3)  / s2);
    float g4  = exp(-(t4  * t4)  / s2);
    float g5  = exp(-(t5  * t5)  / s2);
    float g6  = exp(-(t6  * t6)  / s2);
    float g7  = exp(-(t7  * t7)  / s2);
    float g8  = exp(-(t8  * t8)  / s2);
    float g9  = exp(-(t9  * t9)  / s2);
    float g10 = exp(-(t10 * t10) / s2);
    float g11 = exp(-(t11 * t11) / s2);
    float g12 = exp(-(t12 * t12) / s2);

    float w0    = g0;
    float w12_  = g1  + g2;
    float w34   = g3  + g4;
    float w56   = g5  + g6;
    float w78   = g7  + g8;
    float w910  = g9  + g10;
    float w1112 = g11 + g12;

    float o12   = (t1  * g1  + t2  * g2)  / w12_;
    float o34   = (t3  * g3  + t4  * g4)  / w34;
    float o56   = (t5  * g5  + t6  * g6)  / w56;
    float o78   = (t7  * g7  + t8  * g8)  / w78;
    float o910  = (t9  * g9  + t10 * g10) / w910;
    float o1112 = (t11 * g11 + t12 * g12) / w1112;

    vec4 c = texture(source, uv) * w0;

    c += texture(source, uv + vec2(0.0, o12 * px)) * w12_;
    c += texture(source, uv - vec2(0.0, o12 * px)) * w12_;

    c += texture(source, uv + vec2(0.0, o34 * px)) * w34;
    c += texture(source, uv - vec2(0.0, o34 * px)) * w34;

    c += texture(source, uv + vec2(0.0, o56 * px)) * w56;
    c += texture(source, uv - vec2(0.0, o56 * px)) * w56;

    c += texture(source, uv + vec2(0.0, o78 * px)) * w78;
    c += texture(source, uv - vec2(0.0, o78 * px)) * w78;

    c += texture(source, uv + vec2(0.0, o910 * px)) * w910;
    c += texture(source, uv - vec2(0.0, o910 * px)) * w910;

    c += texture(source, uv + vec2(0.0, o1112 * px)) * w1112;
    c += texture(source, uv - vec2(0.0, o1112 * px)) * w1112;

    c /= (w0 + 2.0 * (w12_ + w34 + w56 + w78 + w910 + w1112));

    fragColor = c * qt_Opacity;
}
