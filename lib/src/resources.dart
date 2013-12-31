library bay.resources;

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

class Resource {
  final String path;
  final UriPattern pathPattern;
  final Key bindingKey;
  List<ResourceMethod> methods = new List();
  final ClassMirror classMirror;
  
  Resource(String path, Key bindingKey) :
    path = path,
    pathPattern = new UriParser(new UriTemplate(path)),
    bindingKey = bindingKey,
    classMirror = reflectClass(bindingKey.type) {
    _mapMethods();
  }
  
  void _mapMethods() {
    classMirror.declarations.forEach(
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
  final Resource owner;
  final Symbol name;
  final String path;
  final UriPattern pathPattern;
  final String method;
  final MethodMirror methodMirror;
  
  ResourceMethod(Resource owner, 
                 Symbol name,
                 String path,
                 String this.method) :
                   owner = owner,
                   path = path,
                   pathPattern = 
                   new UriParser(new UriTemplate(owner.path + path)),
                   name = name,
                   methodMirror = 
                   owner.classMirror.declarations[name];

}

String normalizePath(String path) {
  if (!path.startsWith("/")) {
    path = "/" + path;
  }
  
  if (path.endsWith("/")) {
    path = path.substring(0, path.length - 1);
  }
  
  return path;
}