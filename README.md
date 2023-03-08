# Flutter工程条件编译打包脚本

## 原理

通过将 flutter run/build [--option] 命令替换为 bash flutter.sh run/build [--option] ，在原有flutter运行/打包流程前后执行内置及用户自定义脚本，从而实现对打包流程的自定义控制，默认内置功能为根据命令参数中的
--debug/release 以及 --flavor 渠道名，对代码条件编译.

脚本也可作为纯预处理使用，不运行任何flutter命令

## 用法语法

代码中使用形如以下的注释来进行代码块的条件标记

```dart
void main(List<String> arguments) {
  print(1);
  // #{{exp}}
  // print(2);
  // #{{default}}
  print(7);
  // #{{end}}
}
```

基本注释标记语法为:
```
// #{{exp | default | end}}
```

脚本使用方式：

将本工程内容放到Flutter项目的根目录下，然后执行：
```
bash flutter.sh [build|run] [--release|--debug|--profile]  [--replace] [--flavor flavorX]
```


--replace参数的作用：
```
1.exp为true时：如果有`--replace`参数，则exp与default之间的内容将替代default与end之间的内容;
如果没有`--replace`参数，exp与end之间的代码将一并作为最终的源码输出。
2.exp为false时：exp与default之间的内容不会写入到最终的输出，default与end之间的内容将被写入到输出；
```

exp
```
exp 支持的操作符有 ==、!=、in [...]、notIn [...]、&&、||等，整体类似于 C 语言中 #if 表达式 的用法。
```

另外，除了识别命令参数中的 --debug/release 以及 --flavor 渠道名，还可以使用 --replace 参数，只对项目的源文件进行代码注释和解除注释操作，之后即可正常使用 IDE 对所选模式的代码进行开发和调试。

如果还有进阶的需求，还可以在.hooks/目录下编写pre_script.dart、pre_script.sh、after_script.dart、after_script.sh等自定义脚本，在脚本中可以用类似如下方式对项目进行任意的处理：

```
import '../bin/parse_arguments.dart';
import 'change_package_name.dart';

void main(List<String> arguments) {
  print("Running pre_script.");
  var args = parse(arguments);
  var flavor = args.flavor;
  if (args.mode == 'release') {
    if (['cn', 'test'].contains(args.flavor))
      changeAndroidPackageNameAndAppName(
        packageName: 'com.debuggerx.flutter_app_' + args.flavor,
        appName: args.flavor == 'test' ? '测试版' : '中文版',
      );
    if (args.flavor == 'tw')
      changeIosBundleIdAndAppName(...);
  }
}
```

## 用到的第三方库
https://pub.dev/packages/expressions