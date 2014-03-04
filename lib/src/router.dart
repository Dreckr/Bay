library bay.router;

import 'dart:async';
import 'dart:io';
import 'injector.dart';
import 'handler.dart';

class Router {
  final InjectorBindings injectorBindings;
  List<RequestHandler> requestHandlers;
  
  Router(InjectorBindings this.injectorBindings) {
    var bindings = injectorBindings.withSuperType(RequestHandler);
    
    requestHandlers = bindings.map(
        (binding) => binding.getInstance()).toList(growable: false);
    
    requestHandlers.sort((a, b) => -a.priority.compareTo(b.priority));
  }
  
  Future<HttpRequest> handleRequest(HttpRequest httpRequest) {
    var future;
    try {
      var requestHandler = findRequestHandler(httpRequest);
      
      future = requestHandler.handle(httpRequest);
    } catch (error, stackTrace) {
      future = new Future.error(error, stackTrace);
    }
    
    return future;
  }
  
  RequestHandler findRequestHandler(HttpRequest httpRequest) {
    var matchingHandler = requestHandlers.firstWhere(
        (handler) => handler.accepts(httpRequest),
        orElse: () => null);
    
    if (matchingHandler == null) {
      throw new ResourceNotFoundException(httpRequest.uri.path);
    }
    
    return matchingHandler;
  }
}

class ResourceNotFoundException implements Exception {
  final String path;
  
  ResourceNotFoundException(String this.path);
  
  String toString() => "Resource not found for: $path";
  
}
