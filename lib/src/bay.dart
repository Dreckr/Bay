library bay.core;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:dado/dado.dart';
import 'package:logging/logging.dart';
import 'injector.dart';
import 'notFound.dart';
import 'plugin.dart';
import 'router.dart';

final _coreLogger = new Logger("bay.core");

abstract class Bay {
  HttpServer get httpServer;
  Injector get injector;
  Router get router;
  List<BayPlugin> get plugins;
  
  String get address => httpServer.address.address;
  int get port => httpServer.port;
  
  start();
  
  static Future<Bay> init(List<Module> modules, 
                           {HttpServer httpServer, 
                           address: "0.0.0.0", 
                           int port: 0,
                           int backlog: 0}) {
    
    modules = new List.from(modules, growable: true);
    
    if (httpServer != null) {
      return new Future.value(_init(modules, httpServer));
    } else {
      return HttpServer.bind(address, port, backlog: backlog).then(
          (httpServer) => _init(modules, httpServer));
      
    }
  }
  
  static Future<Bay> initSecure(List<Module> modules, 
                                address, 
                                int port, 
                                {int backlog: 0, 
                                 String certificateName, 
                                 bool requestClientCertificate: false}) {
    return HttpServer.bindSecure(address, 
        port, 
        backlog: backlog, 
        certificateName: certificateName, 
        requestClientCertificate: requestClientCertificate)
          .then((httpServer) => (_init(modules, httpServer)));
  }
  
  static Bay _init(List<Module> modules, HttpServer httpServer) {
    modules.add(new _BayModule(httpServer));
    var injector = new Injector(modules);
    
    var bay = injector.getInstanceOf(Bay);
    bay.start();
    
    return bay;
  }
  
  Future close({bool force: false});
  
}

class _BayImpl implements Bay {
  static final _logger = new Logger("bay.core.Bay");
  final HttpServer httpServer;
  final Injector injector;
  final Router router;
  final InjectorBindings injectorBindings;
  List<BayPlugin> _plugins;
  
  String get address => httpServer.address.address;
  int get port => httpServer.port;
  List<BayPlugin> get plugins => new UnmodifiableListView(_plugins);
  
  Set<HttpResponse> _pendingResponses = new Set();
  
  _BayImpl(this.injector, this.httpServer, this.router, this.injectorBindings);
  
  start() {
    _logger.config("Bay started");
    _listenServer();
    _initiatePlugins();
  }
  
  _listenServer() {
    _logger.config("Address: ${httpServer.address}");
    _logger.config("Port: ${httpServer.port}");
    
    runZoned(
      () => httpServer.listen(_handleRequest)
      , onError: (error, stackTrace) {});
  }
  
  _handleRequest(HttpRequest request) {
    if (request.connectionInfo != null) {
      _logger.finer("Receiving HttpRequest from "
          "${request.connectionInfo.remoteAddress}");
    }
    
    _pendingResponses.add(request.response);
    request.response.done.whenComplete(() {
      _pendingResponses.remove(request.response);
    });
    
    router.handleRequest(request)
      ..then((request) {
            if (request.connectionInfo != null) {
              _logger.finer("Responded HttpRequest from "
                  "${request.connectionInfo.remoteAddress}");
            }
          },
          onError: (error, stackTrace) {
            _logger.severe("Unknown error: $error\n$stackTrace", 
                error, stackTrace);
            if (request.response.contentLength == 0) {
              request.response.statusCode = 500;
            }
            
            request.response.write("Internal Error");
            request.response.close();
              
          })
      ..whenComplete(() {
          if (_pendingResponses.contains(request.response)) {
            request.response.close();
          }
        });
  }
  
  _initiatePlugins() {
    var pluginBindings = injectorBindings.withSuperType(BayPlugin);
    _plugins = [];
    
    pluginBindings.forEach((pluginBinding) {
      _logger.config("Plugin found: ${pluginBinding.key}");
      var plugin = pluginBinding.getInstance();
      
      if (plugin is BayPlugin) {
        plugin.init().then((plugin) {
          _logger.config("Plugin initiated: ${pluginBinding.key}");
          _plugins.add(plugin);
        });
      }
    });
  }
  
  Future close({bool force: false}) => httpServer.close(force: force);
  
}

class _BayModule extends BaseModule {
  
  HttpServer httpServer;
  
  _BayModule(this.httpServer);
  
  @override
  configure() {
    bind(HttpServer).instance = httpServer;
    bind(_BayImpl).scope = SingletonScope;
    bind(Bay).rebinding = _BayImpl;
    bind(Router).scope = SingletonScope;
    bind(NotFoundRequestHandler);
    bind(InjectorBindings);
  }
}
