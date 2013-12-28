library bay.router;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:uri/uri.dart';
import 'annotations.dart';
import 'errors.dart';
import 'exceptions.dart';
import 'filters.dart';

class Router {
  final Injector injector;
  Map<UriPattern, Key> get filters => filterScanner.map;
  Map<UriPattern, Key> get resources => resourceScanner.map;
  ResourceScanner resourceScanner;
  FilterScanner filterScanner;
  
  Router(Injector this.injector) {
    resourceScanner = new ResourceScanner(injector.bindings);
    filterScanner = new FilterScanner(injector.bindings);
  }
  
  Future<HttpRequest> handleRequest(HttpRequest httpRequest) {
    var completer = new Completer<HttpRequest>();
    _applyFilters(httpRequest).then(
      (httpRequest) {
        _callResource(httpRequest).then(
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
          var resourceFilter = injector.getInstanceOfKey(key);
          
          if (resourceFilter is ResourceFilter) {
            matchingFilters.add(resourceFilter);
          }
        }
    });
    
    _iterateThroughFilters(matchingFilters.iterator, httpRequest).then(
        (httpRequest) => completer.complete(httpRequest),
        onError: (error) => completer.completeError(error)
        );
    
    return completer.future;
  }
  
  Future<HttpRequest> _iterateThroughFilters(
                       Iterator<ResourceFilter> resourceFilterIterator, 
                       HttpRequest httpRequest,
                       [Completer completer]) {
    if (completer == null) {
      completer = new Completer<HttpRequest>();
    }
    
    if (resourceFilterIterator.moveNext()) {
      resourceFilterIterator.current.filter(httpRequest).then(
        (httpRequest) {
          try {
            _iterateThroughFilters(resourceFilterIterator, 
                                 httpRequest, 
                                 completer);
          } catch (error) {
            completer.completeError(error);
          }
      }, onError: (error) => completer.completeError(error));
    } else {
      completer.complete(httpRequest);
    }
    
    return completer.future;
  }
  
  Future<HttpRequest> _callResource(HttpRequest httpRequest) {
    var completer = new Completer<HttpRequest>();
    var matchingKey;
    var matchingPattern;
    
    resources.forEach(
        (pattern, key) {
          if (pattern.matches(httpRequest.uri)) {
            if (matchingKey == null &&
                matchingPattern == null) {
              matchingKey = key;
              matchingPattern = pattern;
            } else {
              completer.completeError(
                  new MultipleMatchingResourcesError(httpRequest.uri.path));
            }
          }
    });
    
    if (completer.isCompleted) {
      return completer.future;
    }
    
    if (matchingKey == null) {
      completer.completeError(new ResourceNotFoundException(httpRequest.uri.path));
    } else {
      try {
        var resource = injector.getInstanceOfKey(matchingKey);
        httpRequest.response.write(resource);
        httpRequest.response.close();
      } catch (e) {
        completer.completeError(e);
      }
    }
    
    return completer.future;
  }
  
}

class ResourceScanner {
  List<Binding> bindings;
  Map<UriPattern, Key> get map {
    if (_map == null) {
      _scanResources();
    }
    
    return _map;
  }
  
  Map<UriPattern, Key> _map;
  
  ResourceScanner(List<Binding> this.bindings);
  
  void _scanResources() {
    _map = {};
    bindings.forEach(
      (binding) {
        var typeMirror = reflectType(binding.key.type);
        var pathMetadataMirror = typeMirror.metadata.firstWhere(
          (metadata) => metadata.reflectee is Path
        , orElse: () => null);
        
        if (pathMetadataMirror !=  null) {
          var pathMetadata = pathMetadataMirror.reflectee;
          var uriPattern = new UriParser(new UriTemplate(pathMetadata.path));
          _map[uriPattern] = binding.key;
        }
    });
  }
  
}

class FilterScanner {
  List<Binding> bindings;
  Map<UriPattern, Key> get map {
    if (_map == null) {
      _scanFilters();
    }
    
    return _map;
  }
  
  Map<UriPattern, Key> _map;
  
  FilterScanner(List<Binding> this.bindings);
  
  void _scanFilters() {
    _map = {};
    bindings.forEach(
      (binding) {
        var typeMirror = reflectType(binding.key.type);
        var filterMetadataMirror = typeMirror.metadata.firstWhere(
          (metadata) => metadata.reflectee is Filter
        , orElse: () => null);
        
        if (filterMetadataMirror !=  null) {
          var filterMetadata = filterMetadataMirror.reflectee;
          var uriPattern = new UriParser(new UriTemplate(filterMetadata.path));
          _map[uriPattern] = binding.key;
        }
    });
  }
  
}