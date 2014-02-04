library bay.notFound;

import 'dart:async';
import 'dart:io';
import 'handler.dart';

class NotFoundRequestHandler extends RequestHandler {
  
  int get priority => 0;
  
  bool accepts(HttpRequest request) {
    return true;
  }
  
  Future<HttpRequest> handle(HttpRequest request) {
    request.response.statusCode = HttpStatus.NOT_FOUND;
    request.response.write('Not found');
    request.response.close();
    
    return new Future.value(request);
  }
  
}