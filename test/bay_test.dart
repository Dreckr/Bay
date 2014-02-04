library bay.test;

import 'dart:async';
import 'dart:io';
import 'package:bay/bay.dart';
import 'package:logging/logging.dart';

// TODO(diego): Tests
// TODO(diego): Documentation
void main () {
  Bay.init([new TestModule()], port: 8080);
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}.'
          '${rec.error != null ? '${rec.error}\n${rec.stackTrace}' : ''}');
  });
  
}

class TestModule extends DeclarativeModule {
  String string = "I'm a STRING!";
  
  TestRequestHandler testHandler;
  
  TestPlugin testPlugin;
}

class TestPlugin implements BayPlugin {
  Bay bay;
  
  TestPlugin(this.bay);
  
  Future<BayPlugin> init() {
    print("Test Init!! Look I have an $bay");
    
    return new Future.value(this);
  }
}

class TestRequestHandler extends RequestHandler {
  String testString;
  
  TestRequestHandler(this.testString);
  
  bool accepts(HttpRequest request) => true;
  
  Future<HttpRequest> handle(HttpRequest request) {
    request.response.write(testString);
    request.response.close();
    
    return new Future.value(request);
  }
}
