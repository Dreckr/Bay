library bay.responses;

import 'dart:async';
import 'dart:convert';
import 'package:http_server/http_server.dart';
import 'package:model_map/model_map.dart';
import 'bay.dart';
import 'resources.dart';

class ResponseHandler {
  final Bay bay;
  final ModelMap modelMap = new ModelMap();
  
  ResponseHandler(this.bay);
  
  Future handleResponse(ResourceMethod resourceMethod, 
                          HttpRequestBody httpRequestBody,
                          response) {
    var completer = new Completer();
    var httpResponse = httpRequestBody.request.response;
    
    if (response == null) {
      httpResponse.statusCode = 204;
      httpResponse.close();
      completer.complete(httpRequestBody);
      return completer.future;
    }
    
    _processResponse(resourceMethod, httpRequestBody, response)
      .then((stringResponse) {
        httpResponse.write(stringResponse);
        httpResponse.close();
        completer.complete(httpRequestBody);
    });
    
    return completer.future;
  }
  
  Future<String> _processResponse(ResourceMethod resourceMethod, 
                                    HttpRequestBody httpRequestBody,
                                    response) {
    var completer = new Completer<String>();
    var httpResponse = httpRequestBody.request.response;
    
    try {
      if (response is String) {
        httpResponse.headers.set("content-type", "text");
        completer.complete(response);
      } else if (response is bool || response is num) {
        httpResponse.headers.set("content-type", "text");
        completer.complete(response.toString());
      } else if (response is Iterable) {
        httpResponse.headers.set("content-type", "application/json");
        completer.complete(JSON.encode(modelMap.toList(response)));
      } else if (response is! Function){
        httpResponse.headers.set("content-type", "application/json");
        completer.complete(JSON.encode(modelMap.toMap(response)));
      } else {
        completer.complete("");
      }
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
    
    return completer.future;
  }
  
}