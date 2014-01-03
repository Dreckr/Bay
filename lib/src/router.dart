library bay.router;

import 'dart:async';
import 'dart:io';
import 'package:dado/dado.dart';
import 'package:uri/uri.dart';
import 'package:http_server/http_server.dart';
import 'bay.dart';
import 'filters.dart';
import 'responses.dart';
import 'requests.dart';
import 'resources.dart';

class Router {
  final Bay bay;
  List<Resource> resources;
  Map<UriPattern, Key> filters;
  final ResourceScanner resourceScanner;
  final FilterScanner filterScanner;
  final RequestHandler requestHandler;
  final ResponseHandler responseHandler;
  
  Router(Bay bay) : 
      bay = bay,
      resourceScanner = new ResourceScanner(bay),
      filterScanner = new FilterScanner(bay),
      requestHandler = new RequestHandler(bay),
      responseHandler = new ResponseHandler(bay) {

    resources = resourceScanner.scanResources();
    filters = filterScanner.scanFilters();
  }
  
  Future<HttpRequestBody> handleRequest(HttpRequestBody httpRequestBody) {
    var completer = new Completer<HttpRequestBody>();
    
    var resourceMethod;
    try {
      resourceMethod = _findResourceMethod(httpRequestBody);

      if (resourceMethod == null) {
        throw new ResourceNotFoundException(httpRequestBody.request.uri.path);
      }
    } catch (e) {
      completer.completeError(e);
      return completer.future;
    }
    
    _applyFilters(httpRequestBody).then(
      (httpRequest) {
        _callResourceMethod(resourceMethod, httpRequest).then(
          (httpRequest) {
            completer.complete(httpRequest);
        }, onError: (error) => completer.completeError(error));
      }, onError: (error) => completer.completeError(error));
    
    return completer.future;
  }
  
  Future<HttpRequestBody> _applyFilters(HttpRequestBody httpRequestBody) {
    var completer = new Completer<HttpRequestBody>();
    var matchingFilters = new List<ResourceFilter>();
    filters.forEach(
      (pattern, key) {
        if (pattern.matches(httpRequestBody.request.uri)) {
          var resourceFilter;
          
          try {
            resourceFilter = bay.injector.getInstanceOfKey(key);
          } catch (e) {
            completer.completeError(e);
          }
          
          if (resourceFilter is ResourceFilter) {
            matchingFilters.add(resourceFilter);
          }
        }
    });
    
    if (completer.isCompleted) {
      return completer.future;
    }
    
    _iterateThroughFilters(matchingFilters.iterator, httpRequestBody).then(
        (httpRequest) => completer.complete(httpRequest),
        onError: (error) => completer.completeError(error)
        );
    
    return completer.future;
  }
  
  // TODO(diego): Should be replaced with a chain of responsability?
  Future<HttpRequestBody> _iterateThroughFilters(
                       Iterator<ResourceFilter> resourceFilterIterator, 
                       HttpRequestBody httpRequestBody,
                       [Completer completer]) {
    if (completer == null) {
      completer = new Completer<HttpRequestBody>();
    }
    
    if (resourceFilterIterator.moveNext()) {
      try {
        resourceFilterIterator.current.filter(httpRequestBody).then(
          (httpRequestBody) {
              _iterateThroughFilters(resourceFilterIterator, 
                                   httpRequestBody, 
                                   completer);
        }, onError: (error) => completer.completeError(error));
      } catch (error) {
        completer.completeError(error);
      }
    } else {
      completer.complete(httpRequestBody);
    }
    
    return completer.future;
  }
  
  ResourceMethod _findResourceMethod(HttpRequestBody httpRequestBody) {
    Resource matchingResource;
    ResourceMethod matchingMethod;
    HttpRequest request = httpRequestBody.request;
    
    resources.forEach(
        (resource) {
          if (resource.pathPattern.matches(request.uri)) {
            if (matchingResource == null) {
              matchingResource = resource;
            } else {
              throw new MultipleMatchingResourcesError(request.uri.path);
            }
          }
          
          if (matchingResource != null) {
            matchingResource.methods.forEach(
              (method) {
                var match = method.pathPattern.match(request.uri);
                if (match != null && 
                    match.rest.path.length == 0 &&
                    method.method == request.method) {
                  if (matchingMethod == null) {
                    matchingMethod = method;
                  } else {
                    throw 
                      new MultipleMatchingResourcesError(request.uri.path);
                  }
                }
              });
          }
    });
    
    return matchingMethod;
  }
  
  Future<HttpRequestBody> _callResourceMethod(ResourceMethod resourceMethod, 
      HttpRequestBody httpRequestBody) {
    var completer = new Completer<HttpRequestBody>();
    requestHandler
      .handleRequest(resourceMethod, httpRequestBody)
      .then(
        (response) =>
          responseHandler
            .handleResponse(resourceMethod, httpRequestBody, response)
        ,onError: (error, stackTrace) => 
            completer.completeError(error, stackTrace))
      .then((_) { 
        if (!completer.isCompleted)
          completer.complete(httpRequestBody);
      },
            onError: (error, stackTrace) => 
              completer.completeError(error, stackTrace));
              
    
    return completer.future;
  }
  
}

class ResourceNotFoundException implements Exception {
  final String path;
  
  ResourceNotFoundException(String this.path);
  
  String toString() => "Resource not found for: $path";
  
}

class MultipleMatchingResourcesError extends Error {
  final String path;
  
  MultipleMatchingResourcesError(String this.path);
  
  String toString() => "Multiple resources matching: $path";
  
}
