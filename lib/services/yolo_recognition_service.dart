library;

/// Conditionally exports the native IO implementation on platforms where `dart:io`
/// (and `dart:ffi`) is supported (Android, iOS, desktop), and the web stub implementation
/// on web targets to eliminate FFI compilation errors.
export 'yolo_recognition_service_web.dart'
    if (dart.library.io) 'yolo_recognition_service_io.dart';
