import 'dart:io';

void main(List<String> arguments) {
  print("running default after_script.");
  var rootDir = Directory('./');
  rootDir.listSync(recursive: true).forEach((p) {
    if (p.path.endsWith('.bak')) {
      // 删除原始文件
      File(p.path.substring(0, p.path.length - 4)).deleteSync();
      // 将bak文件重命名为原始文件
      p.renameSync(p.path.substring(0, p.path.length - 4));
    }
  });
}
