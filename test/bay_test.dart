import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:dado/dado.dart';
import 'package:route/url_pattern.dart';

void main () {
  var injector = new Injector([BayModule1]);
  injector.getInstanceOf(Application);
}

class Injectable {
  String test;
  
  Injectable (String this.test);
}

const B = 'b';

abstract class BayModule1 extends BayModule {
  String bla = 'a';
  @B String asdasd = 'b';
  Injectable injectable ();
  
  Application newApplication();
  
  @GET
  @Serve(r'/test/(\d+)')
  Service1 newService1();
}

class Application {
  BayRouter router;
  
  Application (BayRouter this.router) {
    HttpServer.bind('127.0.0.1', 1234).then((server) {
      router.bind(server);
    });
  }
}

class Service1 extends Service {
  Injectable injectable;
  
  Service1 (Injectable this.injectable);
  
  void serve (HttpRequest request, HttpResponse response) {
    response.write('Hello, Bay! Injectable was '
        '${(injectable != null ? '' : 'not ')}injected');
    response.close();
  }
}