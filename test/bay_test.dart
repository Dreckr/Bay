import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:dado/dado.dart';
import 'package:logging/logging.dart';

void main () {
  var injector = new Injector([TestModule]);
  Bay.init(injector, port: 7070);
  
  Logger.root.level = Level.CONFIG;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

abstract class TestModule extends DeclarativeModule {
  String string = "I'm a FILTER!";
  
  TestResource testResource();
  
  TestFilter testFilter();
}


@Path("/test")
class TestResource {
  
  TestResource();
  
  @GET
  String rootTest() {
    return "Woot \o/";
  }
  
  @Path("/what")
  String test() {
    return "test what?";
  }
  
  @POST
  @Path("/what")
  String postTest() {
    return "test";
  }
}

@Filter("/test")
class TestFilter implements ResourceFilter {
  String testString;
  
  TestFilter(String this.testString);
  
  Future<HttpRequest> filter(HttpRequest httpRequest) {
    httpRequest.response.writeln(testString);
    
    return new Future.value(httpRequest);
  }
  
}
