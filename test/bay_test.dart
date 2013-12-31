import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:dado/dado.dart';
import 'package:inject/inject.dart';
import 'package:logging/logging.dart';

void main () {
  var injector = new Injector([TestModule]);
  Bay.init(injector, port: 7070);
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

abstract class TestModule extends DeclarativeModule {
  String string = "I'm a STRING!";
  
  TestResource testResource();
  
  TestFilter testFilter();
}


@Path("/test")
class TestResource {
  
  TestResource();
  
  @GET
  String rootTest(@inject TestFilter filter, 
                   @QueryParam("someparam") int someParam,
                   @HeaderParam("someotherparam") int someOtherParam) {
    return filter.testString + " -  ${someParam + someOtherParam}";
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
    httpRequest.response.headers.set("injected-string", testString);
    
    return new Future.value(httpRequest);
  }
  
}
