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

#ifndef MTLPaints_h_Included
#define MTLPaints_h_Included

#import <Metal/Metal.h>

#include "MTLSurfaceDataBase.h"

#define sun_java2d_SunGraphics2D_PAINT_UNDEFINED -1

@class Composite;
@class MTLPipelineStatesStorage;

@interface MTLPaint : NSObject
- (id)init;
- (BOOL)isEqual:(MTLPaint *)other;
- (void)copyFrom:(MTLPaint *)other;
- (NSString *)getDescription;

- (void)reset;

- (void)setColor:(jint)pixelColor;
- (void)setGradientUseMask:(jboolean)useMask
                    cyclic:(jboolean)cyclic
                        p0:(jdouble)p0
                        p1:(jdouble)p1
                        p3:(jdouble)p3
                    pixel1:(jint)pixel1
                    pixel2:(jint)pixel2;

- (void)setLinearGradient:(jboolean)useMask
                   linear:(jboolean)linear
              cycleMethod:(jboolean)cycleMethod
                 numStops:(jint)numStops
                       p0:(jfloat)p0
                       p1:(jfloat)p1
                       p3:(jfloat)p3
                fractions:(void *)fractions
                   pixels:(void *)pixels;

- (void)setRadialGradient:(jboolean)useMask
                   linear:(jboolean)linear
              cycleMethod:(jboolean)cycleMethod
                 numStops:(jint)numStops
                      m00:(jfloat)m00
                      m01:(jfloat)m01
                      m02:(jfloat)m02
                      m10:(jfloat)m10
                      m11:(jfloat)m11
                      m12:(jfloat)m12
                   focusX:(jfloat)focusX
                fractions:(void *)fractions
                   pixels:(void *)pixels;

- (void)setTexture:(jboolean)useMask
           pSrcOps:(jlong)pSrcOps
            filter:(jboolean)filter
               xp0:(jdouble)xp0
               xp1:(jdouble)xp1
               xp3:(jdouble)xp3
               yp0:(jdouble)yp0
               yp1:(jdouble)yp1
               yp3:(jdouble)yp3;

- (void)setPipelineState:(id<MTLRenderCommandEncoder>)encoder
               composite:(Composite *)composite
               isTexture:(jboolean)isTexture
                srcFlags:(const SurfaceRasterFlags *)srcFlags
                dstFlags:(const SurfaceRasterFlags *)dstFlags
    pipelineStateStorage:(MTLPipelineStatesStorage *)pipelineStateStorage;
@end

#endif /* MTLPaints_h_Included */
