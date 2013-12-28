library bay.errors;

class MultipleMatchingResourcesError extends Error {
  final String path;
  
  MultipleMatchingResourcesError(String this.path);
  
  String toString() => "Multiple resources matching: $path";
  
}