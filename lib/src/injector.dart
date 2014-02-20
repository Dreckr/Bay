library bay.injector;

import 'dart:collection';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:inject/inject.dart';
import 'package:quiver/mirrors.dart';
export 'package:dado/dado.dart' show Injector, Key;

class InjectorBindings extends IterableMixin<BayBinding> {
  Iterable<BayBinding> _bindings;
  
  Iterator<BayBinding> get iterator => _bindings.iterator;
  
  @inject
  factory InjectorBindings(Injector injector) {
    var bindings = injector.bindings.map(
        (binding) => new BayBinding._(binding, injector))
          .toList(growable: false);
    
    return new InjectorBindings._(bindings);
  }
  
  InjectorBindings._(this._bindings);
  
  InjectorBindings withType(Type type) =>
    this.where(
        (binding) => binding.key.type == type);
  
  InjectorBindings withSuperType(Type superType) =>
    this.where(
        (binding) => classImplements(reflectClass(binding.key.type), 
            reflectClass(superType).qualifiedName));

  InjectorBindings annotatedWith(annotation) =>
      this.where((binding) => binding.key.annotation == annotation);
  
  InjectorBindings annotatedWithType(Type annotationType) =>
      this.where(
          (binding) => binding.key.annotation.runtimeType == annotationType);
  
  InjectorBindings classAnnotatedWith(annotation) =>
      this.where(
          (binding) => reflectClass(binding.key.type).metadata.any(
              (metadata) => metadata.reflectee == annotation));
  
  InjectorBindings classAnnotatedWithType(Type annotationType) =>
      this.where(
          (binding) => reflectClass(binding.key.type).metadata.any(
              (metadata) => 
                  metadata.reflectee.runtimeType == annotationType));
  
  @override
  InjectorBindings where(bool f(BayBinding)) =>
    new InjectorBindings._(super.where(f));
  
}

class BayBinding {
  final Binding _binding;
  final Injector _injector;
  Key get key => _binding.key;
  
  BayBinding._(this._binding, this._injector);
  
  dynamic getInstance() => _injector.getInstanceOfKey(key);
  
}