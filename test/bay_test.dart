import 'dart:io';
import 'package:bay/bay.dart';

void main () {
  TestModule module = new TestModule();
  
  HttpServer.bind('127.0.0.1', 7070).then((server) => module.listenOn(server));

}

class TestModule extends ServiceModule {
  
  String message = 'Dart is awesome!';
  
  void configureServices () {
    serve('/foo').using(AbstractRandomService).scopedIn(ServiceScope.SINGLETON);
    
    bind(AbstractRandomService).to(TestRandomService);
  }
  
}

abstract class AbstractRandomService extends Service {
  
  String message;
  
  void service (HttpRequest request, HttpResponse response);
}

class TestRandomService extends AbstractRandomService {
  
  String message;
  int called = 0;
  
  TestRandomService (String this.message);
  
  void service (HttpRequest request, HttpResponse response) {
    this.called++;
    response.write(message + '\nThis service has been called $called times');
    response.close();
  }
  
}
