library bay.core;

import 'dart:async';
import 'dart:io';
import 'package:dado/dado.dart';
import 'package:logging/logging.dart';
import 'package:http_server/http_server.dart';
import 'router.dart';

final _coreLogger = new Logger("bay.core");

// TODO(diego): Tests
// TODO(diego): Viewable
// TODO(diego): Serve static files
// TODO(diego): OPTIONS default response
// TODO(diego): Log everything
// TODO(diego): Document everything
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
    
    httpServer.transform(new HttpBodyHandler()).listen(
      (HttpRequestBody httpBody) {
        _logger.finer("Receiving HttpRequest from "
                       "${httpBody.request.connectionInfo.remoteAddress}");
        
        router.handleRequest(httpBody).then(
            (httpRequest) {
              _logger.finer("Responded HttpRequest from "
                  "${httpRequest.request.connectionInfo.remoteAddress}");
            },
            onError: (error, stackTrace) {
              if (error is ResourceNotFoundException) {
                _logger.finer("Resource not found: ${error.path}", error);
                if (httpBody.request.response.contentLength == 0) {
                  httpBody.request.response.statusCode = 404;
                }
                httpBody.request.response.write("Not found");
                httpBody.request.response.close();
              } else {
                _logger.severe("Unknown error: $error\n$stackTrace", 
                    error, stackTrace);
                if (httpBody.request.response.contentLength == 0) {
                  httpBody.request.response.statusCode = 500;
                }
                
                httpBody.request.response.write("Internal Error");
                httpBody.request.response.close();
                
              }
            }
        );
    }, onError: (error) {}, onDone: () {});
  }
  
  // TODO: Secure HttpServer
  static Future<Bay> init(Injector injector, 
                          {HttpServer httpServer, 
                           String address: "0.0.0.0", 
                           int port: 80}) {
    var completer = new Completer<Bay>();
    
    if (httpServer != null) {
      completer.complete(new Bay._(injector, httpServer));
    } else {
      HttpServer.bind(address, port).then(
          (httpServer) {
            completer.complete(new Bay._(injector, httpServer));
          }, onError: (error, stackTrace) {
            completer.completeError(error, stackTrace);
          });
    }
    
    return completer.future;
  }
  
}
