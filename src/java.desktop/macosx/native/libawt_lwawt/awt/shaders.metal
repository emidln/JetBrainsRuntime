/*
 * Copyright (c) 2019, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

#include <simd/simd.h>
#include <metal_stdlib>
#include "common.h"

using namespace metal;

struct VertexInput {
    float2 position [[attribute(VertexAttributePosition)]];
};

struct TxtVertexInput {
    float2 position [[attribute(VertexAttributePosition)]];
    float2 texCoords [[attribute(VertexAttributeTexPos)]];
};

struct ColShaderInOut {
    float4 position [[position]];
    half4  color;
};

struct StencilShaderInOut {
    float4 position [[position]];
    char color;
};

struct TxtShaderInOut {
    float4 position [[position]];
    float2 texCoords;
    float2 tpCoords;
};

struct GradShaderInOut {
    float4 position [[position]];
    float2 texCoords;
};

vertex ColShaderInOut vert_col(VertexInput in [[stage_in]],
       constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]],
       constant TransformMatrix& transform [[buffer(MatrixBuffer)]]) {
    ColShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix*pos4;
    out.color = half4(uniforms.color.r, uniforms.color.g, uniforms.color.b, uniforms.color.a);
    return out;
}

vertex StencilShaderInOut vert_stencil(VertexInput in [[stage_in]],
       constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]],
       constant TransformMatrix& transform [[buffer(MatrixBuffer)]]) {
    StencilShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix * pos4;
    out.color = 0xFF;
    return out;
}

vertex GradShaderInOut vert_grad(VertexInput in [[stage_in]], constant TransformMatrix& transform [[buffer(MatrixBuffer)]]) {
    GradShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix*pos4;
    return out;
}

vertex TxtShaderInOut vert_txt(TxtVertexInput in [[stage_in]], constant TransformMatrix& transform [[buffer(MatrixBuffer)]]) {
    TxtShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix*pos4;
    out.texCoords = in.texCoords;
    return out;
}

vertex TxtShaderInOut vert_txt_tp(TxtVertexInput in [[stage_in]], constant AnchorData& anchorData [[buffer(FrameUniformBuffer)]], constant TransformMatrix& transform [[buffer(MatrixBuffer)]])
{
    TxtShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix * pos4;

    // Compute texture coordinates here w.r.t. anchor rect of texture paint
    out.tpCoords.x = (anchorData.xParams[0] * in.position.x) +
                      (anchorData.xParams[1] * in.position.y) +
                      (anchorData.xParams[2] * out.position.w);
    out.tpCoords.y = (anchorData.yParams[0] * in.position.x) +
                      (anchorData.yParams[1] * in.position.y) +
                      (anchorData.yParams[2] * out.position.w);
    out.texCoords = in.texCoords;

    return out;
}

vertex GradShaderInOut vert_txt_grad(TxtVertexInput in [[stage_in]],
                                     constant TransformMatrix& transform [[buffer(MatrixBuffer)]]) {
    GradShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix*pos4;
    out.texCoords = in.texCoords;
    return out;
}

fragment half4 frag_col(ColShaderInOut in [[stage_in]]) {
    return in.color;
}

fragment unsigned int frag_stencil(StencilShaderInOut in [[stage_in]]) {
    return in.color;
}

// NOTE:
// 1. consider to make shaders without IF-conditions
// 2. we can pass interpolation mode via uniforms and select corresponding sampler in shader
//  but it can cause performance problems (something like getTextureSampler(hint) will be invoked
//  for every pixel)

fragment half4 frag_txt(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> renderTexture [[texture(0)]],
        constant TxtFrameUniforms& uniforms [[buffer(1)]],
        sampler textureSampler [[sampler(0)]]
) {
    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);
    float srcA = uniforms.isSrcOpaque ? 1 : pixelColor.a;
    if (uniforms.mode) {
        float4 c = mix(pixelColor, uniforms.color, srcA);
        return half4(c.r, c.g, c.b , c.a);
    }

    return half4(pixelColor.r,
                 pixelColor.g,
                 pixelColor.b, srcA*uniforms.extraAlpha);
}

fragment half4 frag_txt_tp(TxtShaderInOut vert [[stage_in]],
                       texture2d<float, access::sample> renderTexture [[texture(0)]],
                       texture2d<float, access::sample> paintTexture [[texture(1)]],
                       sampler textureSampler [[sampler(0)]]
) {
    float4 renderColor = renderTexture.sample(textureSampler, vert.texCoords);
    float4 paintColor = paintTexture.sample(textureSampler, vert.tpCoords);
    return half4(paintColor.r*renderColor.a,
                 paintColor.g*renderColor.a,
                 paintColor.b*renderColor.a,
                 renderColor.a);
}

fragment half4 frag_txt_grad(GradShaderInOut in [[stage_in]],
                         constant GradFrameUniforms& uniforms [[buffer(0)]],
                         texture2d<float, access::sample> renderTexture [[texture(0)]])
{
    constexpr sampler textureSampler (address::repeat, mag_filter::nearest,
                                      min_filter::nearest);

    float4 renderColor = renderTexture.sample(textureSampler, in.texCoords);

    float3 v = float3(in.position.x, in.position.y, 1);
    float  a = (dot(v,uniforms.params)-0.25)*2.0;
    float4 c = mix(uniforms.color1, uniforms.color2, a);
    return half4(c.r*renderColor.a,
                 c.g*renderColor.a,
                 c.b*renderColor.a,
                 renderColor.a);
}

fragment half4 aa_frag_txt(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> renderTexture [[texture(0)]],
        texture2d<float, access::sample> stencilTexture [[texture(1)]],
        constant TxtFrameUniforms& uniforms [[buffer(1)]],
        sampler textureSampler [[sampler(0)]]
) {
    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);
    if (!is_null_texture(stencilTexture)) {
        float4 stencil = stencilTexture.sample(textureSampler, vert.texCoords);
        if (stencil.r ==  0.0) {
            discard_fragment();
        }
    }
    return half4(pixelColor.r, pixelColor.g, pixelColor.b, pixelColor.a);
}

fragment half4 frag_txt_op_rescale(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> srcTex [[texture(0)]],
        constant TxtFrameOpRescaleUniforms& uniforms [[buffer(1)]],
        sampler textureSampler [[sampler(0)]]
) {
    float4 srcColor = srcTex.sample(textureSampler, vert.texCoords);
    const float srcA = uniforms.isSrcOpaque ? 1 : srcColor.a;

    // TODO: check uniforms.isNonPremult and pre-multiply if necessary
    return half4(srcColor.r*uniforms.normScaleFactors.r + uniforms.normOffsets.r,
                 srcColor.g*uniforms.normScaleFactors.g + uniforms.normOffsets.g,
                 srcColor.b*uniforms.normScaleFactors.b + uniforms.normOffsets.b, srcA*uniforms.extraAlpha);

    // NOTE: GL-shader multiplies result with glColor (in order to apply extra alpha), probably it's better to do the
    // same here.
    //
    // GL-shader impl:
    //"    vec4 srcColor = texture%s(baseImage, gl_TexCoord[0].st);"
    //"    %s"                                                      // (placeholder for un-premult code: srcColor.rgb /= srcColor.a;)
    //"    vec4 result = (srcColor * scaleFactors) + offsets;"      // rescale source value
    //"    %s"                                                      // (placeholder for re-premult code: result.rgb *= result.a;)
    //"    gl_FragColor = result * gl_Color;"                       // modulate with gl_Color in order to apply extra alpha
}

fragment half4 frag_txt_op_convolve(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> srcTex [[texture(0)]],
        constant TxtFrameOpConvolveUniforms& uniforms [[buffer(1)]],
        const device float * kernelVals [[buffer(2)]],
        sampler textureSampler [[sampler(0)]]
) {
    float4 sum = float4(0, 0, 0, 0);
    if (vert.texCoords[0] < uniforms.imgEdge[0]
        || vert.texCoords[1] < uniforms.imgEdge[1]
        || vert.texCoords[0] > uniforms.imgEdge[2]
        || vert.texCoords[1] > uniforms.imgEdge[3]
    ) {
        if (!uniforms.isEdgeZeroFill) {
            sum = srcTex.sample(textureSampler, vert.texCoords);
        }
    }

    for (int i = 0; i < uniforms.kernelSize; i++) {
        float3 kern = float3(kernelVals[i*3], kernelVals[i*3 + 1], kernelVals[i*3 + 2]);
        float2 pos = float2(vert.texCoords.x + kern.x, vert.texCoords.y + kern.y);
        float4 pixCol = srcTex.sample(textureSampler, pos);
        sum.r += kern.z * pixCol.r;
        sum.g += kern.z * pixCol.g;
        sum.b += kern.z * pixCol.b;
        sum.a += kern.z * pixCol.a;
    }

    return half4(sum.r, sum.g, sum.b, sum.a*uniforms.extraAlpha);

    // NOTE: GL-shader multiplies result with glColor (in order to apply extra alpha), probably it's better to do the
    // same here.
    //
    // GL-shader impl:
    //"    if (any(lessThan(gl_TexCoord[0].st, imgEdge.xy)) ||"
    //"        any(greaterThan(gl_TexCoord[0].st, imgEdge.zw)))"
    //"    {"
    //"        %s"      // (placeholder for edge condition code)
    //"    } else {"
    //"        sum = vec4(0.0);"
    //"        for (i = 0; i < MAX_KERNEL_SIZE; i++) {"
    //"            sum +="
    //"                kernelVals[i].z *"
    //"                texture%s(baseImage,"
    //"                          gl_TexCoord[0].st + kernelVals[i].xy);"
    //"        }"
    //"    }"
    //""
    //"    gl_FragColor = sum * gl_Color;" // modulate with gl_Color in order to apply extra alpha
}

fragment half4 frag_txt_op_lookup(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> srcTex [[texture(0)]],
        texture2d<float, access::sample> lookupTex [[texture(1)]],
        constant TxtFrameOpLookupUniforms& uniforms [[buffer(1)]],
        sampler textureSampler [[sampler(0)]]
) {
    float4 srcColor = srcTex.sample(textureSampler, vert.texCoords);
    float4 srcIndex = srcColor - uniforms.offset;
    const float2 posR = float2(srcIndex.r, 0.125);
    const float2 posG = float2(srcIndex.g, 0.375);
    const float2 posB = float2(srcIndex.b, 0.625);

    float4 lookupR = lookupTex.sample(textureSampler, posR);
    float4 lookupG = lookupTex.sample(textureSampler, posG);
    float4 lookupB = lookupTex.sample(textureSampler, posB);

    const float a = uniforms.isUseSrcAlpha ? srcColor.a : lookupTex.sample(textureSampler, float2(srcIndex.a, 0.875)).a;

    // TODO: check uniforms.isNonPremult and pre-multiply if necessary
    return half4(lookupR.a, lookupG.a, lookupB.a, a*uniforms.extraAlpha);

    // NOTE: GL-shader multiplies result with glColor (in order to apply extra alpha), probably it's better to do the
    // same here.
    //
    // GL-shader impl:
    //"    vec4 srcColor = texture%s(baseImage, gl_TexCoord[0].st);"
    //"    %s"                                  // (placeholder for un-premult code)
    //"    vec4 srcIndex = srcColor - offset;"  // subtract offset from original index
    //
    //      // use source value as input to lookup table (note that
    //      // "v" texcoords are hardcoded to hit texel centers of
    //      // each row/band in texture)
    //"    vec4 result;"
    //"    result.r = texture2D(lookupTable, vec2(srcIndex.r, 0.125)).r;"
    //"    result.g = texture2D(lookupTable, vec2(srcIndex.g, 0.375)).r;"
    //"    result.b = texture2D(lookupTable, vec2(srcIndex.b, 0.625)).r;"
    //"    %s"                                  // (placeholder for alpha store code)
    //"    %s"                                  // (placeholder for re-premult code)
    //"    gl_FragColor = result * gl_Color;"   // modulate with gl_Color in order to apply extra alpha
}

fragment half4 frag_grad(GradShaderInOut in [[stage_in]],
                         constant GradFrameUniforms& uniforms [[buffer(0)]]) {
    float3 v = float3(in.position.x, in.position.y, 1);
    float  a = (dot(v,uniforms.params)-0.25)*2.0;
    float4 c = mix(uniforms.color1, uniforms.color2, a);
    return half4(c);
}


vertex TxtShaderInOut vert_tp(VertexInput in [[stage_in]],
       constant AnchorData& anchorData [[buffer(FrameUniformBuffer)]],
       constant TransformMatrix& transform [[buffer(MatrixBuffer)]])
{
    TxtShaderInOut out;
    float4 pos4 = float4(in.position, 0.0, 1.0);
    out.position = transform.transformMatrix * pos4;

    // Compute texture coordinates here w.r.t. anchor rect of texture paint
    out.texCoords.x = (anchorData.xParams[0] * in.position.x) +
                      (anchorData.xParams[1] * in.position.y) +
                      (anchorData.xParams[2] * out.position.w);
    out.texCoords.y = (anchorData.yParams[0] * in.position.x) +
                      (anchorData.yParams[1] * in.position.y) +
                      (anchorData.yParams[2] * out.position.w);
   
    return out;
}

fragment half4 frag_tp(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> renderTexture [[texture(0)]])
{
    constexpr sampler textureSampler (address::repeat,
                                      mag_filter::nearest,
                                      min_filter::nearest);

    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);
    return half4(pixelColor.r, pixelColor.g, pixelColor.b, 1.0);

    // This implementation defaults alpha to 1.0 as if source is opaque
    //TODO : implement alpha component value if source is transparent
}

fragment half4 frag_tp_xorMode(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> renderTexture [[texture(0)]],
        constant int& xorColor[[buffer(0)]])
{
    constexpr sampler textureSampler (address::repeat,
                                      mag_filter::nearest,
                                      min_filter::nearest);

    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);

    pixelColor.r = float( (unsigned char)(pixelColor.r * 255.0) ^ ((xorColor >> 16) & 0xFF) ) / 255.0f;
    pixelColor.g = float( (unsigned char)(pixelColor.g * 255.0) ^ ((xorColor >> 8) & 0xFF)) / 255.0f;
    pixelColor.b = float( (unsigned char)(pixelColor.b * 255.0) ^ (xorColor & 0xFF)) / 255.0f;
    pixelColor.a = 1.0;

    return half4(pixelColor.r, pixelColor.g, pixelColor.b, 1.0);

    // This implementation defaults alpha to 1.0 as if source is opaque
    //TODO : implement alpha component value if source is transparent
}

/* The variables involved in the equation can be expressed as follows:
 *
 *   Cs = Color component of the source (foreground color) [0.0, 1.0]
 *   Cd = Color component of the destination (background color) [0.0, 1.0]
 *   Cr = Color component to be written to the destination [0.0, 1.0]
 *   Ag = Glyph alpha (aka intensity or coverage) [0.0, 1.0]
 *   Ga = Gamma adjustment in the range [1.0, 2.5]
 *   (^ means raised to the power)
 *
 * And here is the theoretical equation approximated by this shader:
 *
 *            Cr = (Ag*(Cs^Ga) + (1-Ag)*(Cd^Ga)) ^ (1/Ga)
 */
fragment float4 lcd_color(
        TxtShaderInOut vert [[stage_in]],
        texture2d<float, access::sample> glyphTexture [[texture(0)]],
        texture2d<float, access::sample> dstTexture [[texture(1)]],
        constant LCDFrameUniforms& uniforms [[buffer(1)]]) 
{
    float3 src_adj = uniforms.src_adj;
    float3 gamma = uniforms.gamma;
    float3 invgamma = uniforms.invgamma;

    constexpr sampler glyphTextureSampler (mag_filter::linear,
                                      min_filter::linear);

    // load the RGB value from the glyph image at the current texcoord
    float3 glyph_clr = float3(glyphTexture.sample(glyphTextureSampler, vert.texCoords));

    if (glyph_clr.r == 0.0f && glyph_clr.g == 0.0f && glyph_clr.b == 0.0f) {
        // zero coverage, so skip this fragment
        discard_fragment();
    }
    constexpr sampler dstTextureSampler (mag_filter::linear,
                                      min_filter::linear);
    // load the RGB value from the corresponding destination pixel
    float3 dst_clr = float3(dstTexture.sample(dstTextureSampler, vert.texCoords));

    // gamma adjust the dest color
    float3 dst_adj = pow(dst_clr.rgb, gamma);

    // linearly interpolate the three color values
    float3 result = mix(dst_adj, src_adj, glyph_clr);

    // gamma re-adjust the resulting color (alpha is always set to 1.0)
    return float4(pow(result.rgb, invgamma), 1.0);

}
// Compute shader to transfer clipping data to the texture used for manual clipping in
// aa_frag_txt shader
kernel void stencil2tex(const device uchar *imageBuffer [[buffer(0)]],
    device uchar4 *outputBuffer [[buffer(1)]],
    uint gid [[thread_position_in_grid]])
{
    uchar p = imageBuffer[gid];
    outputBuffer[gid] = uchar4(p, p, p, p);
}