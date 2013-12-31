library bay.router;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:uri/uri.dart';
import 'bay.dart';
import 'errors.dart';
import 'exceptions.dart';
import 'filters.dart';
import 'resources.dart';

class Router {
  final Bay bay;
  List<Resource> resources;
  Map<UriPattern, Key> filters;
  ResourceScanner resourceScanner;
  FilterScanner filterScanner;
  
  Router(this.bay) {
    resourceScanner = new ResourceScanner(bay);
    filterScanner = new FilterScanner(bay);
    
    resources = resourceScanner.scanResources();
    filters = filterScanner.scanFilters();
  }
  
  Future<HttpRequest> handleRequest(HttpRequest httpRequest) {
    var completer = new Completer<HttpRequest>();
    
    var resourceMethod;
    try {
      resourceMethod = _findResourceMethod(httpRequest);
    } catch (e) {
      completer.completeError(e);
      return completer.future;
    }
    
    _applyFilters(httpRequest).then(
      (httpRequest) {
        _callResourceMethod(resourceMethod, httpRequest).then(
          (httpRequest) {
            completer.complete(httpRequest);
        }, onError: (error) => completer.completeError(error));
      }, onError: (error) => completer.completeError(error));
    
    return completer.future;
  }
  
  Future<HttpRequest> _applyFilters(HttpRequest httpRequest) {
    var completer = new Completer<HttpRequest>();
    var matchingFilters = new List<ResourceFilter>();
    filters.forEach(
      (pattern, key) {
        if (pattern.matches(httpRequest.uri)) {
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
    
    _iterateThroughFilters(matchingFilters.iterator, httpRequest).then(
        (httpRequest) => completer.complete(httpRequest),
        onError: (error) => completer.completeError(error)
        );
    
    return completer.future;
  }
  
  // TODO(diego): Should we replace this with a chain of responsability?
  Future<HttpRequest> _iterateThroughFilters(
                       Iterator<ResourceFilter> resourceFilterIterator, 
                       HttpRequest httpRequest,
                       [Completer completer]) {
    if (completer == null) {
      completer = new Completer<HttpRequest>();
    }
    
    if (resourceFilterIterator.moveNext()) {
      try {
        resourceFilterIterator.current.filter(httpRequest).then(
          (httpRequest) {
              _iterateThroughFilters(resourceFilterIterator, 
                                   httpRequest, 
                                   completer);
        }, onError: (error) => completer.completeError(error));
      } catch (error) {
        completer.completeError(error);
      }
    } else {
      completer.complete(httpRequest);
    }
    
    return completer.future;
  }
  
  ResourceMethod _findResourceMethod(HttpRequest httpRequest) {
    Resource matchingResource;
    ResourceMethod matchingMethod;
    
    resources.forEach(
        (resource) {
          if (resource.pathPattern.matches(httpRequest.uri)) {
            if (matchingResource == null) {
              matchingResource = resource;
            } else {
              throw new MultipleMatchingResourcesError(httpRequest.uri.path);
            }
          }
          
          if (matchingResource != null) {
            matchingResource.methods.forEach(
              (method) {
                var match = method.pathPattern.match(httpRequest.uri);
                if (match != null && 
                    match.rest.path.length == 0 &&
                    method.method == httpRequest.method) {
                  if (matchingMethod == null) {
                    matchingMethod = method;
                  } else {
                    throw 
                      new MultipleMatchingResourcesError(httpRequest.uri.path);
                  }
                }
              });
          }
    });
    
    return matchingMethod;
  }
  
  Future<HttpRequest> _callResourceMethod(ResourceMethod resourceMethod, 
                                             HttpRequest httpRequest) {
    var completer = new Completer<HttpRequest>();
    if (completer.isCompleted) {
      return completer.future;
    }
    
    if (resourceMethod == null) {
      completer.completeError(
          new ResourceNotFoundException(httpRequest.uri.path));
      
      return completer.future;
    }
    
    try {
      var resourceObject = 
          bay.injector.getInstanceOfKey(resourceMethod.parent.bindingKey);
      
      var resourceMirror = reflect(resourceObject);
      var response = resourceMirror.invoke(resourceMethod.name, []).reflectee;
      httpRequest.response.write(response);
      httpRequest.response.close();
      completer.complete(httpRequest);
    } catch (e) {
      completer.completeError(e);
    }
    
    return completer.future;
  }
  
}
