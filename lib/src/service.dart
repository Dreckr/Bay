import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:creek/creek.dart';
import 'package:dado/dado.dart';

abstract class Service {
  Route route;
  
  void service (HttpRequest request, HttpResponse response);
  
}

abstract class ServiceModule extends Module {
  RouterConfiguration get configuration => this._router.configuration;
  Router _router;
  Router get router => this._router;
  Map<Uri, ServiceBinding> _services = new Map<Uri, ServiceBinding>();
  
  ServiceModule() : super() {
    this._router = new Router();
    this.bind(Router).to(this._router);
    this.configureServices();
  }
  
  ServiceModule.childOf(Module parent) : super.childOf(parent) {
    this._router = parent.getInstanceOf(Router);
    
    if (this._router == null) {
      this._router = new Router();
      this.bind(Router).to(this._router);
    }
    
    this.configureServices();
  }
  
  void configureServices ();
  
  ServiceBinding serve (Object path) {
    var uri;
    
    if (path is Uri)
      uri = path;
    else if (path is String)
      uri = Uri.parse(path);
    else
      throw new Exception('$path is of type ${path.runtimeType} when String or Uri were expected');
    
    var route = router.findRoute(uri);
    var serviceBinding = new ServiceBinding(this, route);
    
    var serviceBindingHandler = new ServiceBindingHandler(serviceBinding);
    
    route.listen(
        serviceBindingHandler.onData, 
        onError: serviceBindingHandler.onError, 
        onDone: serviceBindingHandler.onDone);
    
    return serviceBinding;
  }
  
  void listenOn (Stream<HttpRequest> server) {
    server.listen((httpRequest) => this._routeRequest(httpRequest));
  }
  
  void _routeRequest (HttpRequest httpRequest) {
    if (!this._router.routeRequest(httpRequest)) {
      httpRequest.response.statusCode = HttpStatus.NOT_FOUND;
      httpRequest.response.close();
    }
  }
  
}


class ServiceBinding {
  ServiceModule _module;
  DefaultBinding _binding;
  Route route;
  ServiceScope scope = ServiceScope.REQUEST;
  
  ServiceBinding (this._module, this.route);
  
  ServiceBinding using (Type type) {
    this._binding = this._module.getByType(type);
    return this;
  }
  
  ServiceBinding scopedIn (ServiceScope scope) {
    this.scope = scope;
  }
  
  Service getService () {
    var service;
    
    if (this._binding == null)
      throw new Exception('No binding defined for service');
    
    if (this.scope == ServiceScope.REQUEST)
      service = this._binding.newInstance();
    else if(this.scope == ServiceScope.SINGLETON)
      service = this._binding.singleton;
    else
      throw new Exception('Unknown scope $scope');
    
    if (!(service is Service))
      throw new Exception('Injected service is invalid. A service must be subtype of Service');
    
    service.route = this.route;
    
    return service;
  }
}

class ServiceScope {
  static final ServiceScope REQUEST = new ServiceScope._(0);
  static final ServiceScope SINGLETON = new ServiceScope._(1);

  int value;

  ServiceScope._(this.value);
}

class ServiceBindingHandler {
  ServiceBinding binding;
  
  ServiceBindingHandler (this.binding);
  
  void onData (HttpRequest request) {
    var service = this.binding.getService();
    service.service(request, request.response);
  }
  
  void onError (error) {
    throw error;
  }
  
  void onDone () {
    print('Done... -.-');
  }
}