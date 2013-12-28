library bay.core;

import 'dart:async';
import 'dart:io';
import 'package:dado/dado.dart';
import 'exceptions.dart';
import 'router.dart';

class Bay {
  final HttpServer httpServer;
  final Injector injector;
  Router router;
  ResourceScanner resourceScanner;
  
  Bay._(Injector this.injector, HttpServer this.httpServer) {
    router = new Router(injector);
    
    httpServer.listen(
      (httpRequest) {
        router.handleRequest(httpRequest).then(
            (httpRequest) {},
            onError: (error) {
              if (error is ResourceNotFoundException) {
                httpRequest.response.statusCode = 404;
                httpRequest.response.write("Not found");
                httpRequest.response.close();
              } else {
                print(error);
                httpRequest.response.statusCode = 500;
                httpRequest.response.write("Internal Error");
                httpRequest.response.close();
              }
            }
        );
    }, onError: (error) {}, onDone: () {});
  }
  
  
  // TODO: Secure HttpServer
  static Future<Bay> init(Injector injector, 
                          {HttpServer httpServer, 
                           String address: "127.0.0.1", 
                           int port: 8080}) {
    var completer = new Completer<Bay>();
    
    if (httpServer != null) {
      completer.complete(new Bay._(injector, httpServer));
    } else {
      HttpServer.bind(address, port).then(
          (httpServer) {
            completer.complete(new Bay._(injector, httpServer));
          }, onError: (error) {
            completer.completeError(error);
          });
    }
    
    return completer.future;
  }
  
}
