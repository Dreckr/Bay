library bay.filters;

import 'dart:async';
import 'dart:io';

abstract class ResourceFilter {
  
  Future<HttpRequest> filter(HttpRequest httpRequest);
  
}
