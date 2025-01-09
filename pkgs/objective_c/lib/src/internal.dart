// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'c_bindings_generated.dart' as c;
import 'objective_c_bindings_generated.dart' as objc;
import 'selector.dart';

typedef ObjectPtr = Pointer<c.ObjCObject>;
typedef BlockPtr = Pointer<c.ObjCBlockImpl>;
typedef VoidPtr = Pointer<Void>;

final class UseAfterReleaseError extends StateError {
  UseAfterReleaseError() : super('Use after release error');
}

final class DoubleReleaseError extends StateError {
  DoubleReleaseError() : super('Double release error');
}

final class UnimplementedOptionalMethodException implements Exception {
  final String clazz;
  final String method;
  UnimplementedOptionalMethodException(this.clazz, this.method);

  @override
  String toString() =>
      '$runtimeType: Instance of $clazz does not implement $method';
}

final class FailedToLoadClassException implements Exception {
  final String clazz;
  FailedToLoadClassException(this.clazz);

  @override
  String toString() => '$runtimeType: Failed to load Objective-C class: $clazz';
}

final class FailedToLoadProtocolException implements Exception {
  final String protocol;
  FailedToLoadProtocolException(this.protocol);

  @override
  String toString() =>
      '$runtimeType: Failed to load Objective-C protocol: $protocol';
}

/// Failed to load a method of a protocol.
///
/// This means that a method that was seen in the protocol declaration at
/// compile time was missing from the protocol at runtime. This is usually
/// caused by a version mismatch between the compile time header and the runtime
/// framework (eg, running an app on an older iOS device).
///
/// To fix this, check whether the method exists at runtime, using
/// `ObjCProtocolMethod.isAvailable`, and implement fallback logic if it's
/// missing.
final class FailedToLoadProtocolMethodException implements Exception {
  final String protocol;
  final String method;
  FailedToLoadProtocolMethodException(this.protocol, this.method);

  @override
  String toString() =>
      '$runtimeType: Failed to load Objective-C protocol method: '
      '$protocol.$method';
}

final class ObjCRuntimeError extends Error {
  final String message;
  ObjCRuntimeError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

extension GetProtocolName on Pointer<c.ObjCProtocol> {
  /// Returns the name of the protocol.
  String get name => c.getProtocolName(this).cast<Utf8>().toDartString();
}

/// Only for use by ffigen bindings.
Pointer<c.ObjCSelector> registerName(String name) {
  final cstr = name.toNativeUtf8();
  final sel = c.registerName(cstr.cast());
  calloc.free(cstr);
  return sel;
}

/// Only for use by ffigen bindings.
ObjectPtr getClass(String name) {
  final cstr = name.toNativeUtf8();
  final clazz = c.getClass(cstr.cast());
  calloc.free(cstr);
  if (clazz == nullptr) {
    throw FailedToLoadClassException(name);
  }
  return clazz;
}

/// Only for use by ffigen bindings.
Pointer<c.ObjCProtocol> getProtocol(String name) {
  final cstr = name.toNativeUtf8();
  final clazz = c.getProtocol(cstr.cast());
  calloc.free(cstr);
  if (clazz == nullptr) {
    throw FailedToLoadProtocolException(name);
  }
  return clazz;
}

/// Only for use by ffigen bindings.
objc.NSMethodSignature? getProtocolMethodSignature(
  Pointer<c.ObjCProtocol> protocol,
  Pointer<c.ObjCSelector> sel, {
  required bool isRequired,
  required bool isInstanceMethod,
}) {
  final sig =
      c.getMethodDescription(protocol, sel, isRequired, isInstanceMethod).types;
  if (sig == nullptr) {
    return null;
  }
  final sigObj = objc.NSMethodSignature.signatureWithObjCTypes_(sig);
  if (sigObj == null) {
    throw ObjCRuntimeError(
        'Failed to construct signature for Objective-C protocol method: '
        '${protocol.name}.${sel.toDartString()}');
  }
  return sigObj;
}

/// Only for use by ffigen bindings.
final msgSendPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSend);

/// Only for use by ffigen bindings.
final msgSendFpretPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSendFpret);

/// Only for use by ffigen bindings.
final msgSendStretPointer =
    Native.addressOf<NativeFunction<Void Function()>>(c.msgSendStret);

/// Only for use by ffigen bindings.
final useMsgSendVariants =
    Abi.current() == Abi.iosX64 || Abi.current() == Abi.macosX64;

/// Only for use by ffigen bindings.
bool respondsToSelector(ObjectPtr obj, Pointer<c.ObjCSelector> sel) =>
    _objcMsgSendRespondsToSelector(obj, _selRespondsToSelector, sel);
final _selRespondsToSelector = registerName('respondsToSelector:');
final _objcMsgSendRespondsToSelector = msgSendPointer
    .cast<
        NativeFunction<
            Bool Function(ObjectPtr, Pointer<c.ObjCSelector>,
                Pointer<c.ObjCSelector> aSelector)>>()
    .asFunction<
        bool Function(
            ObjectPtr, Pointer<c.ObjCSelector>, Pointer<c.ObjCSelector>)>();

// _FinalizablePointer exists because we can't access `this` in the initializers
// of _ObjCReference's constructor, and we have to have an owner to attach the
// Dart_FinalizableHandle to. Ideally _ObjCReference would be the owner.
@pragma('vm:deeply-immutable')
final class _FinalizablePointer<T extends NativeType> implements Finalizable {
  final Pointer<T> ptr;
  _FinalizablePointer(this.ptr);
}

bool _dartAPIInitialized = false;
void _ensureDartAPI() {
  if (!_dartAPIInitialized) {
    _dartAPIInitialized = true;
    c.Dart_InitializeApiDL(NativeApi.initializeApiDLData);
  }
}

c.Dart_FinalizableHandle _newFinalizableHandle(
    _FinalizablePointer finalizable) {
  _ensureDartAPI();
  return c.newFinalizableHandle(finalizable, finalizable.ptr.cast());
}

Pointer<Bool> _newFinalizableBool(Object owner) {
  _ensureDartAPI();
  return c.newFinalizableBool(owner);
}

@pragma('vm:deeply-immutable')
abstract final class _ObjCReference<T extends NativeType>
    implements Finalizable {
  final _FinalizablePointer<T> _finalizable;
  final c.Dart_FinalizableHandle? _ptrFinalizableHandle;
  final Pointer<Bool> _isReleased;

  _ObjCReference(this._finalizable,
      {required bool retain, required bool release})
      : _ptrFinalizableHandle =
            release ? _newFinalizableHandle(_finalizable) : null,
        _isReleased = _newFinalizableBool(_finalizable) {
    assert(_isValid(_finalizable.ptr));
    if (retain) {
      _retain(_finalizable.ptr);
    }
  }

  bool get isReleased => _isReleased.value;

  void _release(void Function(ObjectPtr) releaser) {
    if (isReleased) {
      throw DoubleReleaseError();
    }
    assert(_isValid(_finalizable.ptr));
    if (_ptrFinalizableHandle != null) {
      c.deleteFinalizableHandle(_ptrFinalizableHandle, _finalizable);
      releaser(_finalizable.ptr.cast());
    }
    _isReleased.value = true;
  }

  void release() => _release(c.objectRelease);

  Pointer<T> autorelease() {
    _release(c.objectAutorelease);
    return _finalizable.ptr;
  }

  @override
  bool operator ==(Object other) =>
      other is _ObjCReference && _finalizable.ptr == other._finalizable.ptr;

  @override
  int get hashCode => _finalizable.ptr.hashCode;

  Pointer<T> get pointer {
    if (isReleased) {
      throw UseAfterReleaseError();
    }
    assert(_isValid(_finalizable.ptr));
    return _finalizable.ptr;
  }

  Pointer<T> retainAndReturnPointer() {
    final ptr = pointer;
    _retain(ptr);
    return ptr;
  }

  Pointer<T> retainAndAutorelease() {
    final ptr = pointer;
    _retain(ptr);
    c.objectAutorelease(ptr.cast());
    return ptr;
  }

  void _retain(Pointer<T> ptr);
  bool _isValid(Pointer<T> ptr);
}

// Wrapper around _ObjCObjectRef/_ObjCBlockRef. This is needed because
// deeply-immutable classes must be final, but the ffigen bindings need to
// extend ObjCObjectBase/ObjCBlockBase.
class _ObjCRefHolder<T extends NativeType, Ref extends _ObjCReference<T>> {
  final Ref ref;

  _ObjCRefHolder(this.ref);

  @override
  bool operator ==(Object other) => other is _ObjCRefHolder && ref == other.ref;

  @override
  int get hashCode => ref.hashCode;
}

@pragma('vm:deeply-immutable')
final class _ObjCObjectRef extends _ObjCReference<c.ObjCObject> {
  _ObjCObjectRef(ObjectPtr ptr, {required super.retain, required super.release})
      : super(_FinalizablePointer(ptr));

  @override
  void _retain(ObjectPtr ptr) => c.objectRetain(ptr);

  @override
  bool _isValid(ObjectPtr ptr) => _isValidObject(ptr);
}

/// Only for use by ffigen bindings.
class ObjCObjectBase extends _ObjCRefHolder<c.ObjCObject, _ObjCObjectRef> {
  ObjCObjectBase(ObjectPtr ptr, {required bool retain, required bool release})
      : super(_ObjCObjectRef(ptr, retain: retain, release: release));
}

// Returns whether the object is valid and live. The pointer must point to
// readable memory, or be null. May (rarely) return false positives.
bool _isValidObject(ObjectPtr ptr) {
  if (ptr == nullptr) return false;
  return _isValidClass(c.getObjectClass(ptr));
}

final _allClasses = <ObjectPtr>{};

bool _isValidClass(ObjectPtr clazz) {
  if (_allClasses.contains(clazz)) return true;

  // If the class is missing from the list, it either means we haven't created
  // the set yet, or more classes have been loaded since we created the set, or
  // the class is actually invalid. To rule out the first two cases, rebulid the
  // set then try again. This is expensive, but only happens if asserts are
  // enabled, and only happens more than O(1) times if there are actually
  // invalid objects in use, which shouldn't happen in correct code.
  final countPtr = calloc<UnsignedInt>();
  final classList = c.copyClassList(countPtr);
  final count = countPtr.value;
  calloc.free(countPtr);
  _allClasses.clear();
  for (var i = 0; i < count; ++i) {
    _allClasses.add(classList[i]);
  }
  calloc.free(classList);

  return _allClasses.contains(clazz);
}

@pragma('vm:deeply-immutable')
final class _ObjCBlockRef extends _ObjCReference<c.ObjCBlockImpl> {
  _ObjCBlockRef(BlockPtr ptr, {required super.retain, required super.release})
      : super(_FinalizablePointer(ptr));

  @override
  void _retain(BlockPtr ptr) => c.blockRetain(ptr.cast());

  @override
  bool _isValid(BlockPtr ptr) => c.isValidBlock(ptr);
}

/// Only for use by ffigen bindings.
class ObjCBlockBase extends _ObjCRefHolder<c.ObjCBlockImpl, _ObjCBlockRef> {
  ObjCBlockBase(BlockPtr ptr, {required bool retain, required bool release})
      : super(_ObjCBlockRef(ptr, retain: retain, release: release));
}

final _blockClosureRegistry = <int, Function>{};

int _blockClosureRegistryLastId = 0;

final _blockClosureDisposer = () {
  _ensureDartAPI();
  return RawReceivePort((dynamic msg) {
    final id = msg as int;
    assert(_blockClosureRegistry.containsKey(id));
    _blockClosureRegistry.remove(id);
  }, 'ObjCBlockClosureDisposer')
    ..keepIsolateAlive = false;
}();

/// Only for use by ffigen bindings.
int get blockClosureDisposePort => _blockClosureDisposer.sendPort.nativePort;

/// Only for use by ffigen bindings.
int registerBlockClosure(Function closure) {
  ++_blockClosureRegistryLastId;
  assert(!_blockClosureRegistry.containsKey(_blockClosureRegistryLastId));
  _blockClosureRegistry[_blockClosureRegistryLastId] = closure;
  return _blockClosureRegistryLastId;
}

/// Only for use by ffigen bindings.
typedef DisposeBlockFn = NativeFunction<Void Function(Int64, Int64)>;
Pointer<DisposeBlockFn> get disposeObjCBlockWithClosure =>
    Native.addressOf<DisposeBlockFn>(c.disposeObjCBlockWithClosure);

/// Only for use by ffigen bindings.
Function getBlockClosure(int id) {
  assert(_blockClosureRegistry.containsKey(id));
  return _blockClosureRegistry[id]!;
}

typedef NewWaiterFn = NativeFunction<VoidPtr Function()>;
typedef AwaitWaiterFn = NativeFunction<Void Function(VoidPtr)>;
typedef NativeWrapperFn = BlockPtr Function(
    BlockPtr, BlockPtr, Pointer<NewWaiterFn>, Pointer<AwaitWaiterFn>);

/// Only for use by ffigen bindings.
BlockPtr wrapBlockingBlock(
        NativeWrapperFn nativeWrapper, BlockPtr raw, BlockPtr rawListener) =>
    nativeWrapper(
      raw,
      rawListener,
      Native.addressOf<NewWaiterFn>(c.newWaiter),
      Native.addressOf<AwaitWaiterFn>(c.awaitWaiter),
    );

// Not exported by ../objective_c.dart, because they're only for testing.
int get lastClosureRegistryId => _blockClosureRegistryLastId;
bool isClosureOfBlock(int id) => _blockClosureRegistry.containsKey(id);
bool isValidBlock(BlockPtr block) => c.isValidBlock(block);
bool isValidClass(ObjectPtr clazz) => _isValidClass(clazz);
bool isValidObject(ObjectPtr object) => _isValidObject(object);
