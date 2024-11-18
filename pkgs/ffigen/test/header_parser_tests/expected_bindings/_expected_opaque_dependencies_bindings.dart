// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

/// Opaque Dependencies Test
class NativeLibrary {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  NativeLibrary(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  NativeLibrary.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  ffi.Pointer<BAlias> func(
    ffi.Pointer<A> a,
  ) {
    return _func(
      a,
    );
  }

  late final _funcPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<BAlias> Function(ffi.Pointer<A>)>>(
          'func');
  late final _func =
      _funcPtr.asFunction<ffi.Pointer<BAlias> Function(ffi.Pointer<A>)>();

  ffi.Pointer<UB> func2(
    ffi.Pointer<UA> a,
  ) {
    return _func2(
      a,
    );
  }

  late final _func2Ptr =
      _lookup<ffi.NativeFunction<ffi.Pointer<UB> Function(ffi.Pointer<UA>)>>(
          'func2');
  late final _func2 =
      _func2Ptr.asFunction<ffi.Pointer<UB> Function(ffi.Pointer<UA>)>();
}

final class A extends ffi.Opaque {}

final class B extends ffi.Opaque {}

typedef BAlias = B;

final class C extends ffi.Opaque {}

final class NoDefinitionStructInD extends ffi.Opaque {}

final class D extends ffi.Struct {
  @ffi.Int()
  external int a;

  external ffi.Pointer<NoDefinitionStructInD> nds;
}

final class E extends ffi.Struct {
  external ffi.Pointer<C> c;

  external D d;
}

final class UA extends ffi.Opaque {}

final class UB extends ffi.Opaque {}

final class UC extends ffi.Opaque {}

final class UD extends ffi.Union {
  @ffi.Int()
  external int a;
}

final class UE extends ffi.Union {
  external ffi.Pointer<UC> c;

  external UD d;
}
