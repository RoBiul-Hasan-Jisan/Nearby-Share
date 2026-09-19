class AppException implements Exception {
  const AppException(this.message, {this.title = 'Something went wrong'});

  final String message;
  final String title;

  @override
  String toString() => 'AppException($title: $message)';
}
