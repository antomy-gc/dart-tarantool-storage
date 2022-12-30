import 'dart:io';

import 'package:path/path.dart';
import 'package:tar/tar.dart';
import 'package:tarantool_storage/storage/constants.dart';
import 'package:tarantool_storage/storage/lookup.dart';

import 'compile.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Specify dart execution entry point');
    exit(1);
  }
  final root = Directory.current.uri;
  final entryPoint = File(args[0]);
  if (!entryPoint.existsSync()) {
    print('Specify dart execution entry point');
    exit(1);
  }
  final dotDartTool = findDotDartTool();
  if (dotDartTool == null) {
    print("Run 'dart pub get'");
    exit(1);
  }
  final projectRoot = findProjectRoot();
  if (projectRoot == null) {
    print("Project root not found (parent of 'pubspec.yaml')");
    exit(1);
  }
  final projectName = basename(projectRoot);
  final packageRoot = findPackageRoot(dotDartTool);
  final packageNativeRoot = Directory(packageRoot.toFilePath() + Directories.native);
  final resultPackageRoot = Directory(root.toFilePath() + Directories.package);
  final nativeRoot = Directory(root.toFilePath() + Directories.native);
  final luaRoot = Directory(root.toFilePath() + Directories.lua);
  if (!resultPackageRoot.existsSync()) resultPackageRoot.createSync();
  if (nativeRoot.existsSync()) copyNative(nativeRoot, resultPackageRoot);
  if (luaRoot.existsSync()) copyLua(luaRoot, resultPackageRoot);
  copyLibrary(packageNativeRoot, resultPackageRoot);
  compileDart(resultPackageRoot, entryPoint);
  compileNative(resultPackageRoot, projectName);
  archive(resultPackageRoot, projectName);
}

void copyLibrary(Directory packageNativeRoot, Directory resultPackageRoot) {
  File(packageNativeRoot.path + slash + storageLibraryName).copySync(resultPackageRoot.path + slash + storageLibraryName);
}

void copyNative(Directory nativeRoot, Directory resultPackageRoot) {
  nativeRoot.listSync(recursive: true).whereType<File>().forEach((element) => element.copySync(resultPackageRoot.path + slash + basename(element.path)));
}

void copyLua(Directory luaRoot, Directory resultPackageRoot) {
  luaRoot.listSync(recursive: true).whereType<File>().forEach((element) => element.copySync(resultPackageRoot.path + slash + basename(element.path)));
}

void compileDart(Directory resultPackageRoot, File entryPoint) {
  final compile = Process.runSync(
    CompileOptions.dartExecutable,
    [
      CompileOptions.compileCommand,
      FileExtensions.exe,
      entryPoint.path,
      CompileOptions.outputOption,
      resultPackageRoot.path + slash + basenameWithoutExtension(entryPoint.path) + dot + FileExtensions.exe,
    ],
    runInShell: true,
  );
  if (compile.exitCode != 0) {
    print(compile.stderr.toString());
    exit(compile.exitCode);
  }
}

Future<void> archive(Directory resultPackageRoot, String projectName) async {
  final tarEntries = Stream<TarEntry>.fromIterable(
    resultPackageRoot.listSync().whereType<File>().map((file) => TarEntry.data(TarHeader(name: basename(file.path)), file.readAsBytesSync())),
  );
  await tarEntries.transform(tarWriter).transform(gzip.encoder).pipe(File(projectName + dot + FileExtensions.tarGz).openWrite());
}
