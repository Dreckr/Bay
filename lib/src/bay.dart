library bay.core;

import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:dado/dado.dart';
import 'exceptions.dart';
import 'router.dart';

final _coreLogger = new Logger("bay.core");

class Bay {
  static final _logger = new Logger("bay.core.Bay");
  final HttpServer httpServer;
  final Injector injector;
  Router router;
  
  Bay._(Injector this.injector, HttpServer this.httpServer) {
    _logger.config("Bay started");
    _logger.config("Address: ${httpServer.address}");
    _logger.config("Port: ${httpServer.port}");
    
    router = new Router(this);
    
    httpServer.listen(
      (httpRequest) {
        _logger.finer("Receiving HttpRequest from "
                       "${httpRequest.connectionInfo.remoteAddress}");
        router.handleRequest(httpRequest).then(
            (httpRequest) {
              _logger.finer("Responded HttpRequest from "
                  "${httpRequest.connectionInfo.remoteAddress}");
            },
            onError: (error) {
              if (error is ResourceNotFoundException) {
                _logger.finer("Resource not found: ${error.path}", error);
                if (httpRequest.response.contentLength == 0) {
                  httpRequest.response.statusCode = 404;
                }
                httpRequest.response.write("Not found");
                httpRequest.response.close();
              } else {
                _logger.severe("Unknown error: $error", error);
                if (httpRequest.response.contentLength == 0) {
                  httpRequest.response.statusCode = 500;
                }
                
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
