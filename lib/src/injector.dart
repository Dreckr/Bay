library bay.injector;

import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:quiver/mirrors.dart';
export 'package:dado/dado.dart' show Injector, Key;

class InjectorScanner {
  final Injector injector;
  
  InjectorScanner(this.injector);
  
  List<BayBinding> getAllBindings() {
    return injector.bindings.map(
        (binding) => new BayBinding._(binding, injector))
          .toList(growable: false);
  }
  
  List<BayBinding> findBindingsBy({Type type, 
                                Type superType,
                                annotation, 
                                Type annotationType, 
                                typeAnnotatedWith,
                                Type typeAnnotatedWithType}) {
    var matchingBindings = getAllBindings();
    
    if (type != null) {
      matchingBindings = matchingBindings.where(
          (binding) => binding.key.type == type);
    }
    
    if (superType != null) {
      matchingBindings = matchingBindings.where(
          (binding) => classImplements(reflectClass(binding.key.type), 
                                       reflectClass(superType).qualifiedName));
    }
    
    if (annotation != null) {
      matchingBindings = matchingBindings.where(
          (binding) => binding.key.annotation == annotation);
    }
    
    if (annotationType != null) {
      matchingBindings = matchingBindings.where(
          (binding) => binding.key.annotation.runtimeType == annotationType);
    }
    
    if (typeAnnotatedWith != null) {
      matchingBindings = matchingBindings.where(
          (binding) => reflectClass(binding.key.type).metadata.any(
              (metadata) => metadata.reflectee == typeAnnotatedWith));
    }
    
    if (typeAnnotatedWithType != null) {
      matchingBindings = matchingBindings.where(
          (binding) => reflectClass(binding.key.type).metadata.any(
              (metadata) => 
                  metadata.reflectee.runtimeType == typeAnnotatedWithType));
    }
    
    return matchingBindings.toList(growable: false);
  }
}

class BayBinding {
  final Binding _binding;
  final Injector _injector;
  Key get key => _binding.key;
  
  BayBinding._(this._binding, this._injector);
  
  dynamic getInstance() => _injector.getInstanceOfKey(key);
  
}