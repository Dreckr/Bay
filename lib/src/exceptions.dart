library bay.exceptions;

class ResourceNotFoundException implements Exception {
  final String path;
  
  ResourceNotFoundException(String this.path);
  
  String toString() => "Resource not found for: $path";
  
}