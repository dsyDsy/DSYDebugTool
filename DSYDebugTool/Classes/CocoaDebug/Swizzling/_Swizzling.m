//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

#import "_Swizzling.h"

IMP replaceMethod(SEL selector, IMP newImpl, Class affectedClass, BOOL isClassMethod) {
    if (selector == NULL || newImpl == NULL || affectedClass == Nil) {
        return NULL;
    }

    Method origMethod = isClassMethod ? class_getClassMethod(affectedClass, selector) : class_getInstanceMethod(affectedClass, selector);
    if (origMethod == NULL) {
        return NULL;
    }

    IMP origImpl = method_getImplementation(origMethod);
    Class dispatchClass = isClassMethod ? object_getClass(affectedClass) : affectedClass;

    if (!class_addMethod(dispatchClass, selector, newImpl, method_getTypeEncoding(origMethod))) {
        method_setImplementation(origMethod, newImpl);
    }
    
    return origImpl;
}
