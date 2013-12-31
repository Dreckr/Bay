library bay.filters;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:uri/uri.dart';
import 'annotations.dart';
import 'bay.dart';

class FilterScanner {
  final Bay bay;
  
  FilterScanner(Bay this.bay);
  
  Map<UriPattern, Key> scanFilters() {
    var filters = {};
    bay.injector.bindings.forEach(
      (binding) {
        var typeMirror = reflectType(binding.key.type);
        var filterMetadataMirror = typeMirror.metadata.firstWhere(
          (metadata) => metadata.reflectee is Filter
        , orElse: () => null);
        
        if (filterMetadataMirror !=  null) {
          var filterMetadata = filterMetadataMirror.reflectee;
          var uriPattern = new UriParser(new UriTemplate(filterMetadata.path));
          filters[uriPattern] = binding.key;
        }
    });
    
    return filters;
  }
  
}

abstract class ResourceFilter {
  
  Future<HttpRequest> filter(HttpRequest httpRequest);
  
}
