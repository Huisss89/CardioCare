import 'package:camera/camera.dart';

// Helper extension for camera finding
extension CameraListExtension on List<CameraDescription> {
  CameraDescription? firstWhereOrNull(bool Function(CameraDescription) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
