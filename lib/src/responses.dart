library bay.responses;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'package:http_server/http_server.dart';
import 'package:model_map/model_map.dart';
import 'bay.dart';
import 'resources.dart';

class ResponseHandler {
  final Bay bay;
  List<ResponseProcessor> processors = [];
  
  ResponseHandler(this.bay) {
    processors.add(new HttpResponseProcessor());
    processors.add(new ModelMapJsonResponseProcessor());
  }
  
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
    
    var processor = processors.firstWhere((processor) => 
        processor.accepts(resourceMethod, httpRequestBody, response),
        orElse: () => null);
    
    if (processor == null) {
      httpResponse.write(response.toString());
      httpResponse.close();
    } else {
      processor.processResponse(resourceMethod, httpRequestBody, response).then(
        (responseContent) {
          if (responseContent.shouldWrite) {
            httpResponse.headers.set("content-type", responseContent.type);
            httpResponse.write(responseContent.content);
          }
          
          httpResponse.close();
        }, onError: (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      );
    }
    
    return completer.future;
  }
  
}

abstract class ResponseProcessor {
  
  bool accepts(ResourceMethod resourceMethod, 
              HttpRequestBody httpRequestBody,
              response);
  
  Future<ResponseContent> processResponse(ResourceMethod resourceMethod, 
                                          HttpRequestBody httpRequestBody,
                                          response);
  
}

class ResponseContent {
  final String content;
  final String type;
  final bool shouldWrite;
  
  ResponseContent(this.content, this.type, [this.shouldWrite = true]);
}

class HttpResponseProcessor implements ResponseProcessor {
  
  bool accepts(ResourceMethod resourceMethod, 
               HttpRequestBody httpRequestBody,
               response) {
    return response is HttpRequest || response is HttpResponse || 
          response is HttpRequestBody;
  }
  
  Future<ResponseContent> processResponse(ResourceMethod resourceMethod, 
      HttpRequestBody httpRequestBody,
      response) {
    return new Future.value(new ResponseContent(null, null, false));
  }
}

class ModelMapJsonResponseProcessor implements ResponseProcessor {
  final ModelMap modelMap = new ModelMap();
  
  bool accepts(ResourceMethod resourceMethod, 
              HttpRequestBody httpRequestBody,
              response) {
    var accepts = httpRequestBody.request.headers.value(HttpHeaders.ACCEPT);
    return response is! Function && response is! Mirror && response != null &&
        response is! Stream && response is! Future &&
        (accepts.contains("*/*") || accepts.contains("application/json"));
  }
  
  Future<ResponseContent> processResponse(ResourceMethod resourceMethod, 
                                          HttpRequestBody httpRequestBody,
                                          response) {
    var completer = new Completer<ResponseContent>();
    
    try {
      var content = modelMap.serialize(response, JSON.encoder);
      var contentType = "application/json";
      completer.complete(new ResponseContent(content, contentType));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
    
    return completer.future;
  }
}