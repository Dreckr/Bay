library bay.requests;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:http_server/http_server.dart';
import 'package:inject/inject.dart';
import 'package:model_map/model_map.dart';
import 'annotations.dart';
import 'bay.dart';
import 'resources.dart';

class RequestHandler {
  final Bay bay;
  final ParameterResolver parameterResolver;
  
  RequestHandler(Bay bay) : bay = bay,
                            parameterResolver = 
                              new ParameterResolver(bay);
  
  Future handleRequest(ResourceMethod resourceMethod, 
                         HttpRequestBody httpRequestBody) {
    var request = httpRequestBody.request;
    var completer = new Completer();
    
    try {
      var resourceObject = 
          bay.injector.getInstanceOfKey(resourceMethod.owner.bindingKey);
      
      var resourceMirror = reflect(resourceObject);
      var parameterResolution = 
          parameterResolver.resolveParameters(resourceMethod, httpRequestBody);
      
      var response = 
          resourceMirror.invoke(resourceMethod.name, 
                                parameterResolution.positionalArguments,
                                parameterResolution.namedArguments).reflectee;
      
      if (response is Future) {
        response.then(
            (value) => completer.complete(value), 
            onError: (error, stackTrace) => 
                completer.completeError(error, stackTrace));
      } else {
        completer.complete(response);
      }
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
    
    return completer.future;
  }
  
}

class ParameterResolver {
  final Bay bay;
  List<ParameterResolutionStrategy> resolutionStrategies = [];
  
  ParameterResolver(this.bay, 
                    [List<ParameterResolutionStrategy> resolutionStrategies = 
                    const []]) {
    this.resolutionStrategies.addAll([
                                      new HttpResolutionStrategy(),
                                      new InjectorResolutionStrategy(),
                                      new PathParamResolutionStrategy(),
                                      new QueryParamResolutionStrategy(),
                                      new HeaderParamResolutionStrategy(),
                                      new FormParamResolutionStrategy(),
                                      new CookieParamResolutionStrategy(),
                                      new ContentBodyResolutionStrategy()
                                      ]);
    this.resolutionStrategies.addAll(resolutionStrategies);
    
    this.resolutionStrategies.forEach((strategy) => strategy.install(bay));
  }
  
  ParameterResolution resolveParameters(ResourceMethod resourceMethod, 
                                          HttpRequestBody httpRequestBody) {
    var positionalArguments = resourceMethod.methodMirror.parameters
      .where((parameter) => !parameter.isNamed)
      .map((parameter) => 
          _resolveParameter(resourceMethod, parameter, httpRequestBody))
      .where((argument) => argument != null)
      .toList(growable: false);
    
    var namedArguments = new Map<Symbol, Object>();
    resourceMethod.methodMirror.parameters
      .where((parameter) => parameter.isNamed)
      .forEach((parameter) {
        var argument = 
            _resolveParameter(resourceMethod, parameter, httpRequestBody);
        
        if (argument != null) {
          namedArguments[parameter.simpleName] = argument;
        }
      });
    
    return new ParameterResolution(positionalArguments, namedArguments);
  }
  
  // TODO(diego): Transform this on a chain
  Object _resolveParameter(ResourceMethod resourceMethod, 
                             ParameterMirror parameterMirror, 
                             HttpRequestBody httpRequestBody) {
    var resolution;
    
    resolutionStrategies.forEach(
      (strategy) {
        if (resolution == null) {
          resolution = strategy.resolveParameter(resourceMethod, 
                                                 parameterMirror, 
                                                 httpRequestBody);
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
                            HttpRequestBody httpRequestBody);
  
  void install(Bay bay) {
    this.bay = bay;
  }
  
}

class InjectorResolutionStrategy extends ParameterResolutionStrategy {
  
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequestBody httpRequestBody) {
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

abstract class AnnotatedParamResolutionStrategy extends ParameterResolutionStrategy {
  
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequestBody httpRequestBody) {

    var param = _extractParam(resourceMethod, parameterMirror, httpRequestBody);
    
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
                         HttpRequestBody httpRequestBody);
  
}

class PathParamResolutionStrategy extends AnnotatedParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequestBody httpRequestBody) {
    var pathParamMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is PathParam, 
      orElse: () => null);
    
    if (pathParamMetadata == null)
      return null;
    
    var paramName = pathParamMetadata.reflectee.param;
    var match = resourceMethod.pathPattern.match(httpRequestBody.request.uri);
    return match.parameters[paramName];
  }
  
}

class QueryParamResolutionStrategy extends AnnotatedParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequestBody httpRequestBody) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is QueryParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    return httpRequestBody.request.uri.queryParameters[paramName];
  }
}

class HeaderParamResolutionStrategy extends AnnotatedParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequestBody httpRequestBody) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is HeaderParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    return httpRequestBody.request.headers.value(paramName);
  }
}

class CookieParamResolutionStrategy extends AnnotatedParamResolutionStrategy {
  
  String _extractParam(ResourceMethod resourceMethod,
                         ParameterMirror parameterMirror, 
                         HttpRequestBody httpRequestBody) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is CookieParam, 
      orElse: () => null);
    
    if (paramMetadata == null)
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    var cookie = httpRequestBody.request.cookies.firstWhere(
        (cookie) => cookie.name == paramName, 
        orElse: () => null);
    
    if (cookie == null) {
      return null;
    } else {
      return cookie.value;
    }
  }
}

class FormParamResolutionStrategy extends ParameterResolutionStrategy {
  
  Object resolveParameter(ResourceMethod resourceMethod,
                          ParameterMirror parameterMirror, 
                          HttpRequestBody httpRequestBody) {
    var paramMetadata = parameterMirror.metadata.firstWhere(
      (metadata) => metadata.reflectee is FormParam, 
      orElse: () => null);
    
    if (paramMetadata == null || httpRequestBody.type != "form")
      return null;
    
    var paramName = paramMetadata.reflectee.param;
    return httpRequestBody.body[paramName];
  }
}

class HttpResolutionStrategy extends ParameterResolutionStrategy {
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequestBody httpRequestBody) {
    var parameterType = typeOfTypeMirror(parameterMirror.type);
    
    if (parameterType == HttpRequest) {
      return httpRequestBody.request;
    } else if (parameterType == HttpResponse) {
      return httpRequestBody.request.response;
    } else if (parameterType == HttpRequestBody) {
      return httpRequestBody;
    }
    
    return null;
  }
}

class ContentBodyResolutionStrategy extends ParameterResolutionStrategy {
  Object resolveParameter(ResourceMethod resourceMethod,
                            ParameterMirror parameterMirror, 
                            HttpRequestBody httpRequestBody) {
    var parameterType = typeOfTypeMirror(parameterMirror.type);
    
    if (httpRequestBody.type == "text" && 
        typeOfTypeMirror(parameterMirror.type) == String) {
      return httpRequestBody.body;
    } else if (httpRequestBody.type == "json") {
      if (parameterMirror.type.simpleName == #Map) {
        return httpRequestBody.body;
      }
      
      return new ModelMap().fromMap(parameterType, httpRequestBody.body);
    } else if (httpRequestBody.type == "form" && 
                parameterMirror.type.simpleName == #Map) {
      return httpRequestBody.body;
    }
    
    return null;
  }
}

class UnresolvedParameterError extends Error {
  final ParameterMirror parameter;
  
  UnresolvedParameterError(this.parameter);
  
  String toString() {
    return "No parameter resolution strategy was able to resolve parameter "
            "'${MirrorSystem.getName(parameter.simpleName)}' of "
            "'${MirrorSystem.getName(parameter.owner.owner.simpleName)}."
            "${MirrorSystem.getName(parameter.owner.simpleName)}'";
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