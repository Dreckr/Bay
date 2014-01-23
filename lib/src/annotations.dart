library bay.annotations;

class Path {
  final String path;
  
  const Path(String this.path);
}

class Filter {
  final String path;
  
  const Filter(String this.path);
}

const Method DELETE = const Method("DELETE");
const Method GET = const Method("GET");
const Method POST = const Method("POST");
const Method PUT = const Method("PUT");

class Method {
  final String method;
  
  const Method(this.method);
}
//
//class Consumes {
//  final List<String> mediaTypes;
//  
//  const Consumes(this.mediaTypes);
//}
//
//class Produces {
//  final List<String> mediaTypes;
//  
//  const Produces (this.mediaTypes);
//}

class PathParam {
  final String param;
  
  const PathParam(this.param);
}

class QueryParam {
  final String param;
  
  const QueryParam(this.param);
}

class HeaderParam {
  final String param;
  
  const HeaderParam(this.param);
}


class CookieParam {
  final String param;

  const CookieParam(this.param);
}

class FormParam {
  final String param;

  const FormParam(this.param);
}

class DefaultValue {
  final String value;
  
  const DefaultValue(this.value);
}
