library bay.parameters;

import 'dart:io';
import 'dart:mirrors';
import 'package:inject/inject.dart';
import 'annotations.dart';
import 'bay.dart';
import 'resources.dart';

class ParameterResolver {
  final Bay bay;
  List<ParameterResolutionStrategy> resolutionStrategies = [];
  
  ParameterResolver(this.bay, 
                    [List<ParameterResolutionStrategy> resolutionStrategies = 
                    const []]) {
    this.resolutionStrategies.add(new InjectorResolutionStrategy());
    this.resolutionStrategies.add(new PathParamResolutionStrategy());
    this.resolutionStrategies.add(new QueryParamResolutionStrategy());
    this.resolutionStrategies.add(new HeaderParamResolutionStrategy());
    this.resolutionStrategies.add(new CookieParamResolutionStrategy());
    this.resolutionStrategies.addAll(resolutionStrategies);
    
    this.resolutionStrategies.forEach((strategy) => strategy.install(bay));
  }
  
  ParameterResolution resolveParameters(ResourceMethod resourceMethod, 
                                          HttpRequest httpRequest) {
    var positionalArguments = resourceMethod.methodMirror.parameters
      .where((parameter) => !parameter.isNamed)
      .map((parameter) => 
          _resolveParameter(resourceMethod, parameter, httpRequest))
      .where((argument) => argument != null)
      .toList(growable: false);
    
    var namedArguments = new Map<Symbol, Object>();
    resourceMethod.methodMirror.parameters
      .where((parameter) => parameter.isNamed)
      .forEach((parameter) {
        var argument = 
            _resolveParameter(resourceMethod, parameter, httpRequest);
        
        if (argument != null) {
          namedArguments[parameter.simpleName] = argument;
        }
      });
    
    return new ParameterResolution(positionalArguments, namedArguments);
  }
  
  Object _resolveParameter(ResourceMethod resourceMethod, 
                             ParameterMirror parameterMirror, 
                             HttpRequest httpRequest) {
    var resolution;
    
    resolutionStrategies.forEach(
      (strategy) {
        if (resolution == null) {
          resolution = strategy.resolveParameter(resourceMethod, 
                                                 parameterMirror, 
                                                 httpRequest);
        }
    });
    
    if (resolution == null && !parameterMirror.isOptional) {
      throw new UnresolvedParameterError(parameterMirror);
    }
    
    return resolution;
    
  }
}

class ParameterResolution {
  List<Object> positionalArguments;
  Map<Symbol, Object> namedArguments;
  
  ParameterResolution (this.positionalArguments, this.namedArguments);
  
}

abstract class ParameterResolutionStrategy {
  Bay bay;
  
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequest httpRequest);
  
  void install(Bay bay) {
    this.bay = bay;
  }
  
}

class InjectorResolutionStrategy extends ParameterResolutionStrategy {
  
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequest httpRequest) {
    var injectMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee == inject, 
      orElse: () => null);
    
    if (injectMetadata == null)
      return null;
    
    var instance = 
        bay.injector.getInstanceOf(typeOfTypeMirror(parameterMirror.type));
    
    return instance;
  }
  
}

abstract class ParamResolutionStrategy extends ParameterResolutionStrategy {
  
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequest httpRequest) {

    var param = _extractParam(resourceMethod, parameterMirror, httpRequest);
    
    if (param == null) {
      var defaultValueMetadata = parameterMirror.metadata.firstWhere(
          (metadata) => metadata.reflectee is DefaultValue, 
          orElse: () => null);
      
      if (defaultValueMetadata != null) {
        param = defaultValueMetadata.reflectee.value;
      }
    }
    
    return _parse(param, typeOfTypeMirror(parameterMirror.type));
  }
  
  Object _parse(String param, Type type) {
    if (param == null) {
      return null;
    }
    
    switch (type) {
      case String:
        return param;
      case bool:
        if (param.toLowerCase() == "true") {
          return true;
        } else if (param.toLowerCase() == "false") {
          return false;
        }
        
        continue error;
      case int:
        return int.parse(param);
      case double:
        return double.parse(param);
      error:
      default:
        throw new ArgumentError("Cannot parse String as $type");
    }
  }
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequest httpRequest);
  
}

class PathParamResolutionStrategy extends ParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequest httpRequest) {
    var pathParamMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is PathParam, 
      orElse: () => null);
    
    if (pathParamMetadata == null)
      return null;
    
    var paramName = pathParamMetadata.reflectee.param;
    var match = resourceMethod.pathPattern.match(httpRequest.uri);
    return match.parameters[paramName];
  }
  
}

class QueryParamResolutionStrategy extends ParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequest httpRequest) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is QueryParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    return httpRequest.uri.queryParameters[paramName];
  }
}

class HeaderParamResolutionStrategy extends ParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequest httpRequest) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is HeaderParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    return httpRequest.headers.value(paramName);
  }
}

class CookieParamResolutionStrategy extends ParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequest httpRequest) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is CookieParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    var cookie = httpRequest.cookies.firstWhere(
        (cookie) => cookie.name == paramName, 
        orElse: () => null);
    
    if (cookie == null) {
      return null;
    } else {
      return cookie.value;
    }
  }
}

class UnresolvedParameterError extends Error {
  final ParameterMirror parameter;
  
  UnresolvedParameterError(this.parameter);
  
  String toString() {
    return "No parameter resolution strategy was able to resolve parameter "
            "${parameter.simpleName} of "
            "${parameter.owner.owner.simpleName}.${parameter.owner.simpleName}";
  }
}

Type typeOfTypeMirror(TypeMirror typeMirror) {
  if (typeMirror is ClassMirror) {
    return typeMirror.reflectedType;
  } else if (typeMirror is TypedefMirror) {
    // TODO(diego): Use typeMirror.reflectedType when it becomes available
    return typeMirror.referent.reflectedType;
  } else {
    return null;
  }
}