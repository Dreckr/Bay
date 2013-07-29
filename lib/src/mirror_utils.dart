library bay.mirror_utils;

import 'dart:mirrors';
import 'package:dado/src/mirror_utils.dart';

bool declarationProvidesClass (DeclarationMirror declarationMirror, 
                              Symbol classSymbol, {bool useSimple: false}) {
  if (declarationMirror is VariableMirror) {
    return implements(declarationMirror.type, classSymbol, 
        useSimple: useSimple);
  } else if (declarationMirror is MethodMirror) {
    return implements(declarationMirror.returnType, classSymbol,
        useSimple: useSimple);
  } else if (declarationMirror is TypeMirror) {
    return implements(declarationMirror, classSymbol,
        useSimple: useSimple);
  } else {
    return false;
  }
}