library bay.handler;

import 'dart:async';
import 'dart:io';

abstract class RequestHandler {

  int get priority => 100;

  bool accepts(HttpRequest request);

  Future<HttpRequest> handle(HttpRequest request);

}