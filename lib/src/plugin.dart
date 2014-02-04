library bay.plugin;

import 'dart:async';

abstract class BayPlugin {
  
  Future<BayPlugin> init();
  
}