import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tarantool_storage/storage/bindings.dart';
import 'package:tarantool_storage/storage/extensions.dart';

import 'constants.dart';
import 'executor.dart';
import 'index.dart';
import 'space.dart';

class SpaceFormatPart {
  final String name;
  final String type;
  final bool nullable;

  SpaceFormatPart(this.name, this.type, {this.nullable = false});

  String format() => LuaArgument.singleTableArgument(
        [
          LuaField.quottedField(SchemaFields.name, name),
          LuaField.quottedField(SchemaFields.type, type),
          LuaField.boolField(SchemaFields.isNullable, nullable),
        ].join(comma),
      );
}

class IndexPart {
  final int field;
  final String type;
  final bool nullable;

  IndexPart(this.field, this.type, {this.nullable = false});

  String format() => LuaArgument.singleTableArgument(
        [
          LuaField.intField(SchemaFields.field, field),
          LuaField.quottedField(SchemaFields.type, type),
          LuaField.boolField(SchemaFields.isNullable, nullable),
        ].join(comma),
      );
}

class StorageSchema {
  final StorageExecutor _executor;
  final TarantoolBindings _bindings;

  StorageSchema(this._bindings, this._executor);

  StorageSpace spaceById(int id) => StorageSpace(_bindings, _executor, id);

  Future<StorageSpace> spaceByName(String name) => spaceId(name).then((id) => StorageSpace(_bindings, _executor, id));

  Future<int> spaceId(String space) => using((Arena arena) {
        Pointer<tarantool_message_t> message = arena<tarantool_message_t>();
        message.ref.type = tarantool_message_type.TARANTOOL_MESSAGE_CALL;
        message.ref.function = _bindings.addresses.tarantool_space_id_by_name.cast();
        final request = arena<tarantool_space_id_request_t>();
        request.ref.name = space.toNativeUtf8().cast();
        request.ref.name_length = space.length;
        message.ref.input = request.cast();
        return _executor.sendSingle(message).then((pointer) => pointer.address);
      });

  Future<bool> spaceExists(String space) => using((Arena arena) {
        Pointer<tarantool_message_t> message = arena<tarantool_message_t>();
        message.ref.type = tarantool_message_type.TARANTOOL_MESSAGE_CALL;
        message.ref.function = _bindings.addresses.tarantool_has_space.cast();
        final request = arena<tarantool_space_id_request_t>();
        request.ref.name = space.toNativeUtf8().cast();
        request.ref.name_length = space.length;
        message.ref.input = request.cast();
        return _executor.sendSingle(message).then((pointer) => pointer.address != 0);
      });

  Future<StorageIndex> indexByName(String spaceName, String indexName) {
    return spaceId(spaceName).then((spaceId) => indexId(spaceId, indexName).then((indexId) => StorageIndex(_bindings, _executor, spaceId, indexId)));
  }

  Future<bool> indexExists(int spaceId, String indexName) => using((Arena arena) {
        Pointer<tarantool_message_t> message = arena<tarantool_message_t>();
        message.ref.type = tarantool_message_type.TARANTOOL_MESSAGE_CALL;
        message.ref.function = _bindings.addresses.tarantool_index_id_by_name.cast();
        final request = arena<tarantool_index_id_request_t>();
        request.ref.space_id = spaceId;
        request.ref.name = indexName.toNativeUtf8().cast();
        request.ref.name_length = indexName.length;
        message.ref.input = request.cast();
        return _executor.sendSingle(message).then((pointer) => pointer.address != 0);
      });

  StorageIndex indexById(int spaceId, int indexId) => StorageIndex(_bindings, _executor, spaceId, indexId);

  Future<int> indexId(int spaceId, String index) => using((Arena arena) {
        Pointer<tarantool_message_t> message = arena<tarantool_message_t>();
        message.ref.type = tarantool_message_type.TARANTOOL_MESSAGE_CALL;
        message.ref.function = _bindings.addresses.tarantool_index_id_by_name.cast();
        final request = arena<tarantool_index_id_request_t>();
        request.ref.space_id = spaceId;
        request.ref.name = index.toNativeUtf8().cast();
        request.ref.name_length = index.length;
        message.ref.input = request.cast();
        return _executor.sendSingle(message).then((pointer) => pointer.address);
      });

  Future<void> createSpace(
    String name, {
    StorageEngine? engine,
    int? fieldCount,
    List<SpaceFormatPart>? format,
    int? id,
    bool? ifNotExists,
    bool? local,
    bool? synchronous,
    bool? temporary,
    String? user,
  }) {
    List<String> arguments = [];
    if (engine != null) arguments.add(LuaField.quottedField(SchemaFields.engine, engine.name));
    if (fieldCount != null && fieldCount > 0) arguments.add(LuaField.intField(SchemaFields.fieldCount, fieldCount));
    if (format != null) arguments.add(LuaField.stringField(SchemaFields.format, format.map((part) => part.format()).join(comma)));
    if (id != null) arguments.add(LuaField.intField(SchemaFields.id, id));
    if (ifNotExists != null) arguments.add(LuaField.boolField(SchemaFields.ifNotExists, ifNotExists));
    if (local != null) arguments.add(LuaField.boolField(SchemaFields.isLocal, local));
    if (synchronous != null) arguments.add(LuaField.boolField(SchemaFields.isSync, synchronous));
    if (temporary != null) arguments.add(LuaField.boolField(SchemaFields.temporary, temporary));
    if (user != null && user.isNotEmpty) arguments.add(LuaField.quottedField(SchemaFields.user, user));
    return _executor.evaluateLuaScript(LuaExpressions.createSpace + LuaArgument.singleQuottedArgument(name, options: arguments.join(comma)));
  }

  Future<void> alterSpace(
    String name, {
    int? fieldCount,
    List<SpaceFormatPart>? format,
    bool? synchronous,
    bool? temporary,
    String? user,
  }) {
    List<String> arguments = [name];
    if (fieldCount != null && fieldCount > 0) arguments.add(LuaField.intField(SchemaFields.fieldCount, fieldCount));
    if (format != null) arguments.add(LuaField.stringField(SchemaFields.format, format.map((part) => part.format()).join(comma)));
    if (synchronous != null) arguments.add(LuaField.boolField(SchemaFields.isSync, synchronous));
    if (temporary != null) arguments.add(LuaField.boolField(SchemaFields.temporary, temporary));
    if (temporary != null) arguments.add(LuaField.boolField(SchemaFields.temporary, temporary));
    return _executor.evaluateLuaScript(LuaExpressions.alterSpace(name) + LuaArgument.singleTableArgument(arguments.join(comma)));
  }

  Future<void> renameSpace(String from, String to) => _executor.evaluateLuaScript(LuaExpressions.renameSpace(from) + LuaArgument.singleQuottedArgument(to));

  Future<void> dropSpace(String name) => _executor.evaluateLuaScript(LuaExpressions.dropSpace(name));

  Future<void> createIndex(
    String spaceName,
    String indexName, {
    IndexType? type,
    int? id,
    bool? unique,
    bool? ifNotExists,
    List<IndexPart>? parts,
  }) {
    List<String> arguments = [];
    if (type != null) arguments.add(LuaField.quottedField(SchemaFields.type, type.name));
    if (id != null) arguments.add(LuaField.intField(SchemaFields.id, id));
    if (ifNotExists != null) arguments.add(LuaField.boolField(SchemaFields.ifNotExists, ifNotExists));
    if (unique != null) arguments.add(LuaField.boolField(SchemaFields.isUnique, unique));
    if (parts != null) arguments.add(LuaField.stringField(SchemaFields.parts, parts.map((part) => part.format()).join(comma)));
    return _executor.evaluateLuaScript(LuaExpressions.createIndex(spaceName) + LuaArgument.singleQuottedArgument(indexName, options: arguments.join(comma)));
  }

  Future<void> alterIndex(String spaceName, String indexName, {List<IndexPart>? parts}) {
    List<String> arguments = [if (parts != null) LuaField.stringField(SchemaFields.parts, parts.map((part) => part.format()).join(comma))];
    return _executor.evaluateLuaScript(LuaExpressions.alterIndex(spaceName, indexName) + LuaArgument.singleTableArgument(arguments.join(comma)));
  }

  Future<void> dropIndex(String spaceName, String indexName) => _executor.evaluateLuaScript(LuaExpressions.dropIndex(spaceName, indexName));

  Future<void> createUser(String name, String password, {bool? ifNotExists}) {
    List<String> arguments = [LuaField.quottedField(SchemaFields.password, password)];
    if (ifNotExists != null) arguments.add(LuaField.boolField(SchemaFields.ifNotExists, ifNotExists));
    return _executor.evaluateLuaScript(LuaExpressions.createUser + LuaArgument.singleQuottedArgument(name, options: arguments.join(comma)));
  }

  Future<void> changePassword(String name, String password) => _executor.evaluateLuaScript(LuaExpressions.changePassword(name, password));

  Future<void> userExists(String name) => _executor.evaluateLuaScript(LuaExpressions.userExists(name));

  Future<void> userGrant(
    String name, {
    required String privileges,
    String? objectType,
    String? objectName,
    String? roleName,
    bool? ifNotExists,
  }) {
    List<String> arguments = [name];
    if (roleName != null && roleName.isNotEmpty) {
      arguments.add(roleName.quotted);
      return _executor.evaluateLuaScript(LuaExpressions.userGrant + LuaArgument.arrayArgument(arguments));
    }
    arguments.add(privileges);
    arguments.add(objectType ?? universeObjectType);
    arguments.add(objectName ?? nil);
    return _executor.evaluateLuaScript(LuaExpressions.userGrant + LuaArgument.arrayArgument(arguments));
  }

  Future<void> userRevoke(
    String name, {
    required String privileges,
    String? objectType,
    String? objectName,
    String? roleName,
    bool? universe,
    bool? ifNotExists,
  }) {
    List<String> arguments = [name];
    if (roleName != null && roleName.isNotEmpty) {
      arguments.add(roleName.quotted);
      return _executor.evaluateLuaScript(LuaExpressions.userRevoke + LuaArgument.arrayArgument(arguments));
    }
    arguments.add(privileges);
    arguments.add(objectType ?? universeObjectType);
    arguments.add(objectName ?? nil);
    return _executor.evaluateLuaScript(LuaExpressions.userRevoke + LuaArgument.arrayArgument(arguments));
  }

  Future<void> upgrade() => _executor.evaluateLuaScript(LuaExpressions.schemaUpgrade);
}
