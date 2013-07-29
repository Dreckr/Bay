library bay;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:dado/dado.dart';
import 'package:route/server.dart' as Route;
import 'mirror_utils.dart';

abstract class BayModule extends Module {
  
  void configure (Injector injector) {
    super.configure(injector);
    var routerBinding = new RouterBinding();
    injector.setBinding(routerBinding.key, routerBinding);
  }
  
}

class RouterBinding extends Binding {
  BayRouter _singletonInstance;
  
  RouterBinding () : 
    super(new Key.forType(BayRouter), BayRouter._classMirror);
  
  Object getInstance (Injector injector) {
    return new BayRouter(injector);
  }
  
  Object getSingleton (Injector injector) {
    if (_singletonInstance == null)
      _singletonInstance = getInstance(injector);
    
    return _singletonInstance;
  }
  
  void verifyCircularDependency (Injector injector, 
                                 {List<Key> dependencyStack}) {}

}

class BayRouter implements Route.Router {
  static final ClassMirror _classMirror = reflectClass(BayRouter);
  Injector injector;
  Route.Router _router;
  
  Stream<HttpRequest> get defaultStream {
    if (_router = null)
      return null;
    
    return _router.defaultStream;
  }
  
  BayRouter (Injector this.injector);
  
  void bind (Stream<HttpRequest> httpRequestStream) {
    var router = _createRouter(httpRequestStream);
    this._router = router;
  }
  
  Route.Router _createRouter (Stream<HttpRequest> httpRequestStream) {
    Route.Router router = new Route.Router(httpRequestStream);
    Map<Resource, Key> services = new Map<Resource, Key>();
    Map<Resource, Key> filters = new Map<Resource, Key>();
    
    injector.bindings.forEach((key, binding) {
      var metadata;
      
      try {
        metadata = binding.declarationMirror.metadata;
      } on UnimplementedError catch (e) {
        return;
      }
      
      var path = metadata.firstWhere((m) => m.reflectee is Serve,
          orElse: () => null);
      var method = metadata.firstWhere((m) => m.reflectee is Method,
          orElse: () => null);
      
      if (path == null) 
        return;
      
      var resource = new Resource(Route.urlPattern(path.reflectee.url), 
          (method != null ? method.reflectee.method : null));
      
      if (declarationProvidesClass(binding.declarationMirror, 
          Service._symbol)) {
        services[resource] = key;
      } else if (declarationProvidesClass(binding.declarationMirror, 
          Filter._symbol)) {
        filters[resource] = key;
      }
     });
    
    services.forEach((resource, key) {
      router.serve(resource.url, method: resource.method).listen((httpRequest) {
        var service = injector.getInstanceOf(key.name, annotatedWith: key.annotation) as Service;
        service.serve(httpRequest, httpRequest.response);
      });
    });
    
    filters.forEach((resource, key) {
      router.filter(resource.url, (httpRequest) {
        var filter = injector.getInstanceOf(key.name, annotatedWith: key.annotation) as Filter;
        return filter.filter(httpRequest, httpRequest.response);
      });
    });
    
    return router;
  }
  
  Stream<HttpRequest> serve(Pattern url, {String method}) {
    if (_router == null)
      throw new ArgumentError('Router has not been binded yet.');
    
    return _router.serve(url, method: method);
  }
  
  void filter(Pattern url, Route.Filter filter) {
    if (_router == null)
      throw new ArgumentError('Router has not been binded yet.');
    
    _router.filter(url, filter);
  }
}
class Resource {
  final Pattern url;
  final String method;
  
  Resource (Pattern this.url, String this.method);
}

abstract class Filter {
  static final Symbol _symbol = reflectClass(Filter).qualifiedName;
  
  Future<bool> filter (HttpRequest httpRequest, HttpResponse httpResponse);
  
}

abstract class Service {
  static final Symbol _symbol = reflectClass(Service).qualifiedName;
  
  void serve (HttpRequest httpRequest, HttpResponse httpResponse);
  
}

const DELETE = const Method('DELETE');
const GET = const Method('GET');
const POST = const Method('POST');
const PUT = const Method('PUT');

class Method {
  final String method;
  const Method (String this.method);
}

class Serve {
  final Pattern url;
  
  const Serve (Pattern this.url);
}