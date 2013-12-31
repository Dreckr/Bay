library bay.resources;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:logging/logging.dart';
import 'package:uri/uri.dart';
import 'annotations.dart';
import 'bay.dart';

final _resourcesLogger = new Logger("bay.resources");

class ResourceScanner {
  static final _logger = new Logger("bay.resources.ResourceScanner");
  final Bay bay;
  
  ResourceScanner(this.bay);
  
  List<Resource> scanResources() {
    _logger.config("Scanning resources...");
    var resources = [];
    bay.injector.bindings.forEach(
      (binding) {
        var typeMirror = reflectType(binding.key.type);
        var pathMetadataMirror = typeMirror.metadata.firstWhere(
          (metadata) => metadata.reflectee is Path
        , orElse: () => null);
        
        if (pathMetadataMirror !=  null) {
          var path = normalizePath(pathMetadataMirror.reflectee.path);
          resources.add(new Resource(path, binding.key));
          
          _logger.config("Resource class found: ${binding.key.type}");
        }
    });
    
    return resources;
  }
  
}

class ResourceExecutor {
  final Bay bay;
  
  ResourceExecutor(this.bay);
  
  Future<HttpRequest> execute(Resource resourceDescriptor, 
                               HttpRequest httpRequest) {
    var resourceObject = 
        bay.injector.getInstanceOfKey(resourceDescriptor.bindingKey);
    var resourceMirror = reflect(resourceObject);
    
  }
  
  MethodMirror _findMethod(ClassMirror classMirror, HttpRequest httpRequest) {
    classMirror.declarations.forEach(
      (name, declaration) {
        
    });
  }
  
}

class Resource {
  final String path;
  final UriPattern pathPattern;
  final Key bindingKey;
  List<ResourceMethod> methods = new List();
  ClassMirror _resourceMirror;
  
  Resource(String path, Key this.bindingKey) :
    path = path,
    pathPattern = new UriParser(new UriTemplate(path)) {
    _resourceMirror = reflectClass(bindingKey.type);
    _mapMethods();
  }
  
  void _mapMethods() {
    _resourceMirror.declarations.forEach(
      (name, declaration) {
        if (declaration is MethodMirror) {
          var pathMetadataMirror = declaration.metadata.firstWhere(
              (metadata) => metadata.reflectee is Path
              , orElse: () => null);
          
          var methodMetadataMirror = declaration.metadata.firstWhere(
              (metadata) => metadata.reflectee is Method
              , orElse: () => null);
          
          if (pathMetadataMirror == null && methodMetadataMirror == null)
            return;
          
          var method;
          if (methodMetadataMirror != null) {
            method = methodMetadataMirror.reflectee.method;
          } else {
            method = "GET";
          }
          
          var path = "";
          if (pathMetadataMirror != null) {
            path += normalizePath(pathMetadataMirror.reflectee.path);
          }
          
          methods.add(new ResourceMethod(this, name, path, method));
        }
    });
  }
  
}

class ResourceMethod {
  final Resource parent;
  final Symbol name;
  final String path;
  final UriPattern pathPattern;
  final String method;
  
  ResourceMethod(Resource parent, 
                 Symbol this.name,
                 String path,
                 String this.method) :
                   parent = parent,
                   path = path,
                   pathPattern = 
                   new UriParser(new UriTemplate(parent.path + path));
  
}

String normalizePath(String path) {
  if (!path.startsWith("/")) {
    path = "/" + path;
  }
  
  if (path.endsWith("/")) {
    path = path.substring(0, path.length - 2);
  }
  
  return path;
}