#!/usr/bin/env bash

SCRIPT_ABS=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_ABS")


# readlink
# readlink是linux系统中一个常用工具，主要用来找出符号链接所指向的位置。

# 在Ubuntu系统中执行以下命令：
# $ readlink --help
# 可以查看readlink命令的帮助信息，或者执行

# $ man readlink
# 查看帮助手册。

# 从帮助信息中可以得到readlink命令的用途描述：
# "输出符号链接值或者权威文件名"

# 英文为：
# "print value of a symbolic link or canonical file name"

# 举例：
# 系统中的awk命令到底是执行哪个可以执行文件呢？
# $ readlink /usr/bin/awk
# /etc/alternatives/awk  ----> 其实这个还是一个符号连接
# $ readlink /etc/alternatives/awk
# /usr/bin/gawk  ----> 这个才是真正的可执行文件
# -f 选项：
# -f 选项可以递归跟随给出文件名的所有符号链接以标准化，除最后一个外所有组件必须存在。

# 简单地说，就是一直跟随符号链接，直到直到非符号链接的文件位置，限制是最后必须存在一个非符号链接的文件。
# $ readlink -f /usr/bin/awk
# /usr/bin/gawk


# dirname
# [dirname]

# 手册页“Print  NAME  with  its  trailing  /component  removed; if NAME contains no /’s, output ‘.’ (meaning the current directory).”
# 该命令可以取给定路径的目录部分（strip non-directory suffix from file name）。这个命令很少直接在shell命令行中使用，我们一般把它用在shell脚本中，用于取得脚本文件所在目录，然后将当前目录切换过去。

# ★常用示例

# 示例一:       # /usr/bin为获取到的目录
# [root@local ~]# dirname /usr/bin/sort
# /usr/bin

# 示例二:       # 如无/则获取当前目录.
# [root@local ~]# dirname stdio.h
# .

# 示例三:   	  # 含/和无/，其结果和不含/效果一样的
# [root@local ~]# dirname /usr/bin
# /usr
# [root@local ~]# dirname /usr/bin/
# /usr

# 示例四:       # 获取多个目录列表，以换行为分隔
# [root@local ~]# dirname dir1/file1 dir2/file2
# dir1
# dir2

# 示例五:       # 获取多个目录列表，以NUL为分隔
# [root@local ~]# dirname -z dir1/file1 dir2/file2
# dir1dir2

# ★脚本用法

# !/bin/bash

# # 跳转到脚本所在目录
# cd $(dirname "$0") || exit 1

# # 对上面的脚本的解释
# $0          	    当前Shell程序的文件名
# dirname $0  	    获取当前Shell程序的路径
# cd $(dirname $0)  进入当前Shell程序的目录
# exit 1            如果获取不到则退出脚本


# [basename]

# basename命令用于去掉文件名的目录和后缀（strip directory and suffix from filenames），对应的dirname命令用于截取目录

# ★常用示例

# 示例一        # 获取到最后文件名sort
# [root@local ~]# basename /usr/bin/sort
# sort

# 示例二        # 去除文件名后缀
# [root@local ~]# basename /usr/include/stdio.h .h
# stdio
# [root@local ~]# basename /usr/include/stdio.h stdio.h
# stdio.h

# 示例三        # 去除文件名后缀方式的另外一种方法
# [root@local ~]# basename -s .h /usr/include/stdio.h
# stdio

# 示例四        # 获取多个目录下的文件列表，以换行符\n为分隔
# [root@local ~]# basename -a dir1/file1 dir2/file2
# file1
# file2

# 示例五        # 获取多个目录下的文件列表，以NUL为分隔
# [root@local ~]# basename -a -z dir1/file1 dir2/file2
# file1file2


# shellcheck disable=SC2005
DART_EXE=$(command -v dart)

# apples-Mac-mini-1243:Quick_Start apple$ command -v dart
# /Users/apple/IDE/flutter/bin/dart


JUST_REPLACE=0
for i in "$@"
do
   [ "$i" == "--replace" ] && JUST_REPLACE=1
done

echo Original args is : [ "$@" ]
ARGS=("$@")

UNSET_NEXT=0
INDEX=0
for i in ${ARGS[*]}
    do
        [ 1 == $UNSET_NEXT ] && UNSET_NEXT=0 && unset ARGS[$INDEX]
        [ "--flavor" == "$i" ] && UNSET_NEXT=1 && unset ARGS[$INDEX]
        ((INDEX++))
    done

echo Passed args is : [ "${ARGS[*]}" ]

if [[ ! -x "$DART_EXE" ]]; then
  echo "Can't find dart executable file !"
fi

${DART_EXE} "$SCRIPT_DIR"/bin/pre_script.dart "$@"

if [[ "$JUST_REPLACE" == 0 ]]; then
  if [[ -f "./.hooks/pre_script.dart" ]]; then
    ${DART_EXE} ./.hooks/pre_script.dart "$@"
  fi

  if [[ -f "./pre_script.dart" ]]; then
    ${DART_EXE} ./pre_script.dart "$@"
  fi

  if [[ -f "./.hooks/pre_script.sh" ]]; then
    ./.hooks/pre_script.sh "$@"
  fi

  if [[ -f "./pre_script.sh" ]]; then
    ./pre_script.sh "$@"
  fi

  if [[ ${#ARGS[*]} -gt 0 ]]; then
    flutter pub get
    flutter ${ARGS[*]}
  else
    echo "no flutter command will run"
  fi

  ${DART_EXE} "$SCRIPT_DIR"/bin/after_script.dart "$@"

  if [[ -f "./.hooks/after_script.dart" ]]; then
    ${DART_EXE} ./.hooks/after_script.dart "$@"
  fi

  if [[ -f "./after_script.dart" ]]; then
    ${DART_EXE} ./after_script.dart "$@"
  fi

  if [[ -f "./.hooks/after_script.sh" ]]; then
    ./.hooks/after_script.sh "$@"
  fi

  if [[ -f "./after_script.sh" ]]; then
    ./after_script.sh "$@"
  fi

fi
