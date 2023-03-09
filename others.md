[toc]

随着 Flutter 3 正式发布，Flutter 的跨平台之旅迈入高潮。现在，Flutter 3 增加了对 macOS 和 Linux 应用的稳定支持，这意味着我们可以仅用一套代码库，为 6 个平台构建精美的体验。

## 一套代码跨平台的问题

迄今为止，我已经使用 flutter 开发了数个跨平台项目，有的是相对常见的 Android / iOS 双平台项目，也有横跨桌面端、移动端和 Web 端这种平台差异更大的项目。由于 flutter 项目是使用同一套代码来编写所有目标平台的界面和逻辑，所以时常会出现以下情况：

### 不同平台下需要运行不同的代码逻辑

例如，在 Android 平台上，应用左上角默认的返回键图标是【<-】，而在 iOS 平台上，默认的返回键图标样式是【<】（参看：[平台行为差异和适配 - 图标](https://flutter.cn/docs/resources/platform-adaptations#iconography)），为了能够使应用在不同平台上可以表现得更加符合平台的风格和习惯，往往需要判断运行平台编写分支代码

一般做法
针对上面的例子，参看 flutter sdk 中 BackButton 的源码 `back_button.dart#L31`：

```
class BackButtonIcon extends StatelessWidget {
  const BackButtonIcon({ super.key });

  /// Returns the appropriate "back" icon for the given `platform`.
  static IconData _getIconData(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return Icons.arrow_back;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Icons.arrow_back_ios;
    }
  }

  @override
  Widget build(BuildContext context) => Icon(_getIconData(Theme.of(context).platform));
}
```

可以看到这里是利用 Theme.of(context).platform 在 APP 运行时获得平台，然后作为 switch 的条件，为 iOS/MacOS 平台返回与其他平台不同样式的返回键图标。应该说这是一种非常简单直接的处理办法，确实可以解决大部分类似的问题。

**存在的问题**

- 会导致编译打包后，单个平台的 APP 中会包含一些本平台并不需要的代码或资源

还是以上面的例子，flutter 开发的程序在构建打包时会进行名为 [Tree Shaking](https://zhuanlan.zhihu.com/p/272567200) 的死代码消除优化，自动将源代码中“不可及”的代码和依赖移除，从而减小最终产出的包大小。**但是，在条件分支中的代码并不属于“死代码”，** 编译器并不知道我们为 iOS/MacOS 以外平台的情况编写的代码在 iOS/MacOS 平台下是无用的。如果判断或分支很多，则有可能会增加最终的 APP 包大小，从而造成了浪费。

- 代码组织形式受限
  
由于总是需要用代码获取到的平台类型作为执行代码分支的依据，所以针对不同平台所编写的代码基本只能放在 if-else、switch-case和condition ? exp1 : exp2 这几种代码块中，针对不同平台的代码往往不得不挤在一起，不方便更选灵活地组织代码。

- 可能造成 debug 时被无关代码干扰

由于多种平台的独有代码共存，极端情况下源代码可能会变得相当冗长，在调试代码时，即使我们只想针对某种特定的平台进行调试，却不得不在一堆与当前平台无关的代码中自行分辨有效的代码。有时看了半天，才发现追了半天的逻辑并不属于当前正在调试的平台，使人相当抑郁。

- 不同平台下需要导入不同的 Library / Plugin

例如，有时我们想要在 Android 平台上使用 Material 组件库，而在 iOS 平台使用 Cupertino 的组件；
又或者，有时在 Android 平台我们想使用原生插件 A，而在 iOS 平台，由于种种原因，想要使用原生插件 B

**一般做法**

针对第一个问题，有时我们可能会使用和上面一样的方法，先判断平台类型，然后在分支中使用不同的组价；另外还有一个比较流行的库：[flutter_platform_widgets](https://pub.flutter-io.cn/packages/flutter_platform_widgets)，这个库的思路是对两种风格的组件做一次包装，提供统一的 API，这样代码中只写了一种代码，但在两种平台上会自动使用对应风格的组件。

而第二个问题，一般来说也是需要在 pubspec.yaml 加入所需的插件依赖，在代码中根据平台分支去分别调用。

**存在的问题**

- 还是会造成最终产物的资源浪费

原因与平台分支代码的情况类似，而且由于导入的 Library 一般都比较大，无用代码占用空间的增速会更加明显

- 可能由于插件冲突导致 APP 打包出错

比如存在 A 和 B 两个插件，它们都实现了 Android 和 iOS 的原生代码，并有自己的库文件，但是由于在 Android 下 A 插件运行效果较好，而 iOS 下只有 B 插件能正常使用，但是同时导入两个插件会由于它们的库文件冲突而导致编译打包失败，这就很麻烦了。

- **在某平台下特定库不可导入。** 最常见的问题就是，在 web 平台下不可以导入 dart:io 库，而经常使用 dart:html 库；而在其他平台下则正相反，导入dart:html 库会导致无法构建，而 dart:io 库却非常常用
  - 一般做法
  参看：[Dart SDK libraries and Flutter for web](https://github.com/flutter/flutter/issues/39998#issue-490489986)，可以使用如下方式针对 web 平台和非 web 平台引入不同的库：

  ```
  import 'b.dart' if (dart.library.io) 'c.dart'
  ```

  然后分别在 b.dart 和 c.dart 中导入平台允许使用的库，并编写逻辑。

  还有一种针对 dart:io 库的解决方案，即使用 [universal_io](https://github.com/dint-dev/universal_io) 这个第三方库替代dart:io，然后在代码中用 [kIsWeb](https://github.com/flutter/flutter/blob/2cde203b9c7a825cc0f0faa0a535b8314c106cba/packages/flutter/lib/src/foundation/constants.dart#L77) 常量来做判断。
  - 存在的问题

    - **条件引入的写法只能用于区分 web 和 非 web 平台** 由于条件引入这种写法生效的条件实际就只有 if (dart.library.io)和if (dart.library.html) 这两种，所以如果是想区分 Android 和 iOS 平台，或者区分移动端和桌面端，这种方法就无法使用了。

    - **写法非常死板繁琐** 如果要使用这种方法，基本上都需要编写三个源文件，写法非常固定。

    - **IDE 的代码转跳被限制** 如果使用了这种写法，当想要通过查看定义的方式向上查找源码时，总是会转跳到条件导入中前面一个源代码中的位置，相当不友好。

### 自定义平台/多渠道打包

比如同一个项目的 Android 端和 iOS 端，想要通过简单的参数设置可以分别打包出针对国内用户的普通版和针对海外用户的国际版，又或者一种在国内更常见的需求，需要向国内各大应用市场上传不同的“渠道包”。

**一般做法**
官方推荐的常规做法是使用 flavor，参考：[配置 flavors 构建双端](https://flutter.cn/docs/deployment/flavors)，通过一些配置，可以在编译打包时在打包命令中添加 --flavor [flavor_name] 的方式传入参数，在代码中即可拿到之前配置好的一些常量，得以实现不同渠道包的差异化。

**存在的问题**

- **配置非常繁琐**
这种方案需要针对每种渠道单独在原生侧设置很多繁琐的配置，而且有些设置依赖 Android Studio 或 Xcode 对原生项目的操作，配置使用的灵活性也不是很高，即使只是一个常量或者字符串的差异，也必须完整配置整套 flavor，非常麻烦。
- **同样会造成最终产物的资源浪费**
原因和上面相同，不再赘述。

## 其他语言或方案中的处理方式

### C/C++/C#/go/rust等

在 C 语言和以 C 语言为基础的很多语言中，有种称为“条件编译”的语言特性：[条件编译_百度百科](条件编译_百度百科)

C/C++ 语言的一大优势就是可以编写出“可移植性”高的代码，其中“条件编译”发挥了相当重要的作用（[对于C语言可移植性的思考](https://blog.51cto.com/vanshell/417068)）。

语法格式：
**if格式**
```C
# if 表达式

     语句序列①
[#else
     语句序列②]

# endif
```

功能：当表达式的值为真时，编译语句序列①，否则编译语句序列②。其中，#else和语句序列②可有可无。

**ifdef格式**
```

# ifdef 标识符

     语句序列①
[#else
     语句序列②]

# endif
```

功能：当标识符已被定义时（用#define定义），编译语句序列①，否则编译语句序列②。其中#else和语句序列②可有可无。

**ifndef格式**
```
# ifndef  标识符

     语句序列①
[#else
     语句序列②]

# endif
```

功能：该格式功能与ifdef相反

条件编译允许只编译源文件中满足条件的程序段，使生成的目标程序较短，从而减少了内存的开销，并提高程序的效率，可以按不同的条件去编译不同的程序部分，因而产生不同的目标代码文件。这对于程序的移植和调试是很有用的。同时，条件编译可以让程序在各种不同的软硬件环境下都得以正常运行。即提高了程序的可移植性和灵活性。

### Taro
Taro 是一个开放式跨端跨框架解决方案，支持使用 React/Vue/Nerv 等框架来开发 微信 / 京东 / 百度 / 支付宝 / 字节跳动 / QQ / 飞书 小程序 / H5 / RN 等应用。

> Taro 的设计初衷就是为了统一跨平台的开发方式，虽然 Taro 不像 Flutter 可以同时支持移动端、桌面端和 Web 等软硬件差异巨大的平台，但是由于它支持了众多厂家的“类小程序”应用开发，虽然已经尽力通过运行时框架、组件、API 去抹平多端差异，但是由于不同的平台之间还是存在一些无法消除的差异，所以为了更好的实现跨平台开发，Taro 中提供了如下的解决方案：
[Taro 文档 - 跨平台开发](https://taro-docs.jd.com/taro/docs/envs)

- 内置环境变量
Taro 在编译时提供了一些内置的环境变量来帮助用户做一些特殊处理。

```
process.env.TARO_ENV
用于判断当前的编译平台类型。

取值：weapp / swan / alipay / tt / qq / jd / h5 / rn
```

可以通过这个变量来区分不同环境，从而使用不同的逻辑。在编译阶段，会移除不属于当前编译类型的代码，只保留当前编译类型下的代码，例如：

1. 在微信小程序和 H5 端分别引用不同资源：

```
/** 源码 */
if (process.env.TARO_ENV === 'weapp') {
  require('path/to/weapp/name')
} else if (process.env.TARO_ENV === 'h5') {
  require('path/to/h5/name')
}

/**编译后（微信小程序）*/
if (true) {
  require('path/to/weapp/name')
}
/** 编译后（H5）*/
if (true) {
  require('path/to/h5/name')
}
```
2. 决定不同端要加载的组件
```
/** 源码（React JSX） */
<View>
  {process.env.TARO_ENV === 'weapp' && <ScrollViewWeapp />}
  {process.env.TARO_ENV === 'h5' && <ScrollViewH5 />}
</View>

/**编译后（微信小程序）*/
<View>
  {true && <ScrollViewWeapp />}
</View>
/** 编译后（H5）*/
<View>
  {true && <ScrollViewH5 />}
</View>
```
- 统一接口的多端文件
内置环境变量虽然可以解决大部分跨端的问题，但是会让代码中充斥着逻辑判断的代码，影响代码的可维护性，而且也让代码变得愈发丑陋。为了解决这种问题，Taro 提供了另外一种称为“统一接口的多端文件”跨端开发的方式作为补充，主要用于以下场景：

```
多端组件
多端脚本逻辑
多端页面路由
```
参考：[统一接口的多端文件](https://taro-docs.jd.com/taro/docs/envs#%E7%BB%9F%E4%B8%80%E6%8E%A5%E5%8F%A3%E7%9A%84%E5%A4%9A%E7%AB%AF%E6%96%87%E4%BB%B6)

### 小结

可以看出，以上列举的 C 语言和 Taro 框架所提供的解决方案，都可以解决部分 Flutter 现有方案中的问题，主要的一个点就是编译过程中可以将不属于本平台的代码移除。

### 已有方案

#### 宏替换工具 - definetool
**地址：** [fengdeyingzi / definetool](https://github.com/fengdeyingzi/definetool)

这是一个为编程语言加入define宏定义的工具，用于实现对不同版本、不同平台进行区分，实现原理是利用宏注释不需要的代码，该工具理论上适用于任何编程语言，作者是 风的影子

**使用方式**
1.在代码中加入宏注释
```
// #ifdef WINDOWS
print("hello windows");
// #endif

// #ifdef WEB
print("hello web");
// #endif
```
2.在代码所在目录运行findtool工具，并定义宏：WINDOWS
这个命令可直接在本项目上操作来查看效果
```
definetool -define WINDOWS
```
在编译时若没有此宏，会将define与endif之间的内容进行/**/注释，若有宏，则进行解除注释。

宏内定义的内容不要使用多行注释

#### Flutter 工程条件编译打包脚本 - FlutterX
**地址：** [debuggerx01 / FlutterX](https://github.com/debuggerx01/FlutterX)

这是作者[debuggerx01](https://github.com/debuggerx01)编写的一套脚本，原理和上面的 definetool 类似，原理是通过将 flutter run/build [--option] 命令替换为 bash flutter.sh run/build [--option] ，在原有 flutter 运行/打包流程前后执行内置及用户自定义脚本，从而实现对打包流程的自定义控制，默认内置功能为根据命令参数中的 --debug/release 以及 --flavor 渠道名，还可以使用 --replace 参数，只对项目的源文件进行注释的，对代码条件编译。

- 用法语法
代码中使用形如以下的注释来进行代码块的条件标记：

```
void main(List<String> arguments) {
  print(1);
  // #{{exp}}
  // print(2);
  // #{{default}}
  print(7);
  // #{{end}}
}
```

基本注释标记语法为 // #{{exp | default | end}}

exp 支持的操作符有 ==、!=、in [...]、notIn [...]、&&、||等，整体类似于 C 语言中 #if 表达式 的用法。

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

## 小结

如上两种方案其实都是借鉴了 C 语言中的“宏”和“条件编译”的思路实现的，好处是相对比较灵活，可以对项目源码进行以行为单位的替换操作，都可以解决一部分 Flutter 现有方案中的问题。
但是，这种思路也有一些问题，比如：

- 由于需要对非当前平台的代码进行注释操作，所以在代码中会出现大量的注释代码，这些代码在 IDE 中不会高亮显示，也不参与语法检查，对开发和代码审核不是很友好
- 需要对源文件进行操作，虽然两种方案都会做了自动的备份处理，但是仍有可能在某些情况下破坏项目源码
- 解决思路比较偏向于“通用”的源文件级代码替换，不太符合 Flutter / Dart 代码生成的思路

## 总结

本篇详细介绍了在 Flutter 开发跨平台应用时，对于平台独有代码的处理方式以及问题，参考了 C 语言和 Taro 框架的处理方法，并介绍了两种已有的源码替换方案和缺点。

>文章来源于：<https://www.debuggerx.com/2022/04/17/conditional-compilation-using-source-gen-in-flutter-1/>
>
>项目原地址：[debuggerx01 / FlutterX](https://github.com/debuggerx01/FlutterX)
