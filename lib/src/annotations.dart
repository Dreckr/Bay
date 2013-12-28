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
  
  const Method(String this.method);
}

class Consumes {
  final List<String> mediaTypes;
  
  const Consumes (List<String> this.mediaTypes);
}

class Produces {
  final List<String> mediaTypes;
  
  const Produces (List<String> this.mediaTypes);
}

// TODO: PathParam, QueryParam, BodyParam, CookieParam, DefaultValue