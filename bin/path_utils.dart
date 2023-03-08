import 'dart:io';

class PathUtils {
  // /a/.../xxx.dart => xxx.dart
  // /a/.../xxx => xxx
  static String baseName(FileSystemEntity file) {
    return file.path.substring(file.parent.path.length + 1);
  }
}

void main() {
  print(PathUtils.baseName(File('./path_utils.dart')));
  // apples-Mac-mini-1243:FlutterX apple$ dart bin/path_utils.dart
  // path_utils.dart
}