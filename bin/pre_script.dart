import 'dart:io';
import 'path_utils.dart';
import 'parse_arguments.dart';
import 'expressions/expressions.dart';
import 'flavors.dart';

// 带有下面这些后缀的文件不被处理
const BLACK_FILE_EXT = [
  'md',
  'sh',
  'bat',
  'py',
];

// https://github.com/appsup-dart/expressions
final _ctx = {
  'debug': 'debug',
  'release': 'release',
  'profile': 'profile',
  'default': 'default',
};

/// 正则捕获到的表达式
String? exp;
late String mode;
late String flavor;
late bool isReplace;

enum STATE {
  none,
  notMatch,
  caching,
  replace,
  inDefault,
}

void main(List<String> arguments) {
  print("Running default pre_script.");
  var args = parse(arguments);
  mode = args.mode;
  flavor = args.flavor;
  isReplace = args.isReplaceMode;

  if (!FLAVORS.contains(flavor) && flavor != 'default')
    throw Exception('Undefined flavor !!!');

  _ctx.addEntries(FLAVORS.map((e) => MapEntry(e, e)));

  _ctx.addAll({
    'mode': mode,
    'flavor': flavor,
  });

  var rootDir = Directory('./');
  // 开始处理文件
  rootDir.listSync().forEach(walkPath);
}

File? file;
// 新的文件内容将被写到这个缓冲区中，最后将内容输出到文件
StringBuffer sb = StringBuffer();
// 当“宏”中的表达式为true时，截止到下一个宏之间的源代码都要临时写入这里面
StringBuffer tmp = StringBuffer();
// 当前要处理的行处于何种操作范围
STATE state = STATE.none;
/// 对“宏”进行匹配的正则
RegExp re = RegExp(r'// #\{\{(.+)\}\}');

Match? ma;
/// 本文件是否有需要处理的“宏”
bool modified = false;

const evaluator = const ExpressionEvaluator();
late List<String> lines;

// vars for replace mode
int currentLineIndex = 0;
List<ReplaceOperation> operations = [];
List<ReplaceOperation> tempOperations = [];
List<ReplaceOperation> currentTempOperations = [];

final _commentReg = RegExp(' *\/\/');

var lastIndent = -1;

/// 对dart源码进行预处理的函数
void walkPath(FileSystemEntity path) {
  // 文件类型
  var stat = path.statSync();
  if (stat.type == FileSystemEntityType.directory) {
    // 对非隐藏文件夹递归做预处理
    Directory(path.path)
        .listSync()
        .where((f) => !PathUtils.baseName(f).startsWith('.'))
        .forEach(walkPath);
  } else if (stat.type == FileSystemEntityType.file && BLACK_FILE_EXT.indexWhere((ele) => path.path.endsWith(ele)) < 0) {
    // 在白名单之外的文件做预处理
    file = File(path.path);
    sb.clear();
    // 如果文件中含有预处理“宏”相关的表达式，则modified为true
    modified = false;
    state = STATE.none;
    if (isReplace) {
      currentLineIndex = 0;
      operations.clear();
      tempOperations.clear();
      currentTempOperations.clear();
    }
    try {
      lines = file!.readAsLinesSync();
      lines.forEach((line) {
        currentLineIndex++; // 1...
        ma = re.firstMatch(line);
        if (ma != null) {
          // 这里可能是宏的开始，也可能是宏的结束
          lastIndent = line.indexOf('// #{{');
          modified = true;
          // 提取表达式
          exp = ma!.group(1);
          if (exp == "default") {
            if (isReplace) {
              if (currentTempOperations.isNotEmpty && !currentTempOperations.first.commented) {
                tempOperations.forEach((ele) => ele.commented = true);
              }

              tempOperations.addAll(currentTempOperations);
              currentTempOperations.clear();
            }

            // 默认代码块开始
            if (tmp.isNotEmpty) {
              sb.write(tmp);
              print([
                "${file!.path} modified" + '\n',
                "-" * 80 + '\n',
                tmp.toString(),
                "-" * 80 + '\n',
              ].join());
              state = STATE.replace;
            } else {
              state = STATE.inDefault;
            }
          } else if (exp == "end") {
            // 默认代码块结束
            state = STATE.none;
            if (isReplace) {
              if (tmp.isEmpty) {
                // 说明匹配到了默认代码块，应该将之前的代码全注释掉
                tempOperations.forEach((ele) => ele.commented = true);
              } else {
                // 之前有匹配到的代码块，应该将默认代码块注释掉
                currentTempOperations.forEach((ele) => ele.commented = true);
              }
              tempOperations.addAll(currentTempOperations);
              operations.addAll(tempOperations);
              tempOperations.clear();
              currentTempOperations.clear();
            }
            tmp.clear();
          } else {
            // # {{ exp }}
            if (evaluator.eval(Expression.parse(exp!), _ctx)) {
              // exp 判定为true，下面将要把exp与default之间的代码缓存到tmp中
              tmp.clear();
              state = STATE.caching;
            } else {
              // exp 判定为false，exp与default之间的代码不缓存
              state = STATE.notMatch;
            }

            if (isReplace) {
              if (state == STATE.caching) {
                tempOperations.forEach((ele) => ele.commented = true);
                currentTempOperations.forEach((ele) => ele.commented = true);
              }
              tempOperations.addAll(currentTempOperations);
              currentTempOperations.clear();
            }
          }
        } else {
          // none状态时直接将line写入sb
          if ([STATE.none, STATE.inDefault].contains(state)) {
            sb.writeln(line);
          } else if (state == STATE.caching) {
            // 缓存中状态，将用于替换的内容移除注释后写入缓存
            tmp.writeln(line.replaceFirst('// ', ''));
            // 这样就跳过了没有匹配上的替换代码块和默认内容
          }

          if (isReplace && [STATE.notMatch, STATE.caching, STATE.replace, STATE.inDefault].contains(state)) {
            currentTempOperations.add(ReplaceOperation(currentLineIndex, lastIndent, state == STATE.notMatch));
          }
        }
      });

      // 如果文件需要进行预处理
      if (modified) {
        if (isReplace) {
          // 按照操作清单对文件进行处理
          operations.forEach((operation) {
            if (operation.commented && !lines[operation.lineNumber - 1].startsWith(_commentReg) && lines[operation.lineNumber - 1].trim().length > 0) {
              lines[operation.lineNumber - 1] = '${' ' * operation.indent}// ${lines[operation.lineNumber - 1].substring(operation.indent)}';
            } else if (!operation.commented && lines[operation.lineNumber - 1].startsWith(_commentReg)) {
              lines[operation.lineNumber - 1] = lines[operation.lineNumber - 1].replaceFirst('// ', '');
            }
          });
          file!.deleteSync();
          File(path.path).writeAsStringSync(lines.join('\n') + '\n', flush: true);
          print("${file!.path} modified");
        } else {
          // 如果不是替换模式，则先备份一下，然后将处理过的文件写入原文件
          file!.renameSync(path.path + '.bak');
          File(path.path).writeAsStringSync(sb.toString(), flush: true);
        }
      }
    } catch (e) {
      if (!(e is FileSystemException)) {
        rethrow;
      }
    }
  }
}

class ReplaceOperation {
  /// 代码所处于的行号
  int lineNumber;
  int indent;
  // 该行代码是否应该被注释掉
  bool commented;

  ReplaceOperation(this.lineNumber, this.indent, this.commented);
}
