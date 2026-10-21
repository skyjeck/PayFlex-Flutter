// lib/core/network/custom_exception.dart

class AppException implements Exception {
  final String? message;
  final String? prefix;
  final dynamic data;

  AppException([this.message, this.prefix, this.data]);

  @override
  String toString() => "$prefix$message";
}

class FetchDataException extends AppException {
  FetchDataException([String? message, dynamic data])
    : super(message, "Error During Communication: ", data);
}

class BadRequestException extends AppException {
  BadRequestException([String? message, dynamic data]) : super(message, "Invalid Request: ", data);
}

class UnauthorisedException extends AppException {
  UnauthorisedException([String? message, dynamic data]) : super(message, "Unauthorised: ", data);
}
