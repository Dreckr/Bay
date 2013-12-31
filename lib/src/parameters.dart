library bay.parameters;

import 'dart:io';
import 'dart:mirrors';
import 'bay.dart';
import 'resources.dart';

class ParameterResolver {
  final Bay bay;
  List<ParameterResolutionStrategy> resolutionStrategies;
  
  ParameterResolver(this.bay, this.resolutionStrategies);
}

abstract class ParameterResolutionStrategy {
  
  Object resolveParameter(HttpRequest httpRequest, 
                            ResourceMethod resouceMethod,
                            ParameterMirror parameterMirror);
  
}