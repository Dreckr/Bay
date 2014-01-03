import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:dado/dado.dart';
import 'package:http_server/http_server.dart';
import 'package:inject/inject.dart';
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
  SimpleModel postTest(SimpleModel simpleGuy) {
    return simpleGuy;
  }
}

class SimpleModel {
  String user;
  String password;
  
  SimpleModel();
  
  SimpleModel.valued(this.user, this.password);
}

@Filter("/test")
class TestFilter implements ResourceFilter {
  String testString;
  
  TestFilter(String this.testString);
  
  Future<HttpRequestBody> filter(HttpRequestBody httpRequestBody) {
    httpRequestBody.request.response.headers.set("injected-string", testString);
    
    return new Future.value(httpRequestBody);
  }
  
}
