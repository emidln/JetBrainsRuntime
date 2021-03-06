// Copyright 2000-2020 JetBrains s.r.o. Use of this source code is governed by the Apache 2.0 license that can be found in the LICENSE file.

#ifndef NATIVE_JAVALISTACCESSIBILITY_H
#define NATIVE_JAVALISTACCESSIBILITY_H

#endif // NATIVE_JAVALISTACCESSIBILITY_H

#import "JavaElementAccessibility.h"

@interface JavaListAccessibility : JavaElementAccessibility
@end

@interface PlatformAxList : PlatformAxElement <NSAccessibilityList>
@end