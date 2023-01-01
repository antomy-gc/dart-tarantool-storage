import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:tarantool_storage/storage/native_module.dart';
import 'bindings.dart';
import 'configuration.dart';
import 'constants.dart';
import 'lookup.dart';
import 'script.dart';

import 'executor.dart';

class Storage {
  late TarantoolBindings _bindings;
  late StorageLibrary _library;
  late StorageExecutor _executor;
  late RawReceivePort _shutdownPort;
  final bool activateReloader;

  StreamSubscription<ProcessSignal>? _reloadListener = null;
  bool _hasStorageLuaModule = false;

  Storage({String? libraryPath, this.activateReloader = false}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? StorageLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TarantoolBindings(_library.library);
    _executor = StorageExecutor(_bindings, _bindings.tarantool_generate_owner_id());
    _shutdownPort = RawReceivePort((_) => close());
  }

  Future<void> boot(StorageBootstrapScript script, StorageMessageLoopConfiguration loopConfiguration, {ReplicationConfiguration? replicationConfiguration}) async {
    if (initialized()) return;
    _hasStorageLuaModule = script.hasStorageLuaModule;
    final nativeConfiguration = loopConfiguration.native(_library.path);
    nativeConfiguration.ref.shutdown_port = _shutdownPort.sendPort.nativePort;
    _bindings.tarantool_initialize(
      Platform.executable.toNativeUtf8().cast<Char>(),
      script.write().toNativeUtf8().cast(),
      nativeConfiguration,
    );
    malloc.free(nativeConfiguration);
    if (_hasStorageLuaModule && replicationConfiguration != null) {
      await executor().executeLua(LuaExpressions.boot, arguments: [
        replicationConfiguration.user,
        replicationConfiguration.password,
        replicationConfiguration.delay.inSeconds,
      ]);
    }
    if (activateReloader) _reloadListener = ProcessSignal.sighup.watch().listen((event) => reload());
  }

  bool mutable() => _bindings.tarantool_is_read_only() == 0;

  bool initialized() => _bindings.tarantool_initialized() == 1;

  bool immutable() => _bindings.tarantool_is_read_only() == 1;

  Future<void> awaitInitialized() => Future.doWhile(() => Future.delayed(awaitStateDuration).then((value) => !initialized()));

  Future<void> awaitImmutable() => Future.doWhile(() => Future.delayed(awaitStateDuration).then((value) => !immutable()));

  Future<void> awaitMutable() => Future.doWhile(() => Future.delayed(awaitStateDuration).then((value) => mutable()));

  void shutdown() => _bindings.tarantool_shutdown(0);

  void close() {
    _executor.close();
    _shutdownPort.close();
    _reloadListener?.cancel();
  }

  StorageExecutor executor() => _executor;

  StorageLibrary library() => _library;

  Future<void> reload() async {
    StorageNativeModule.reloadAll();
    if (_hasStorageLuaModule) await executor().executeLua(LuaExpressions.reload);
  }

  void execute(void Function(StorageExecutor executor) executor) => executor(_executor);
}
