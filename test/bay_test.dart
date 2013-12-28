import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:dado/dado.dart';

void main () {
  var injector = new Injector([TestModule]);
  Bay.init(injector, port: 7070);
}

abstract class TestModule extends DeclarativeModule {
  String string = "WTF??!";
  
  TestResource testResource();
  
  TestFilter testFilter();
}


@Path("/test")
class TestResource {
  
  @GET
  String test () {
    return "test";
  }
}

@Filter("/test")
class TestFilter implements ResourceFilter {
  String testString;
  
  TestFilter (String this.testString);
  
  Future<HttpRequest> filter(HttpRequest httpRequest) {
    httpRequest.response.writeln(testString);
    
    return new Future.value(httpRequest);
  }
  
}
