// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:swiftgen/swiftgen.dart';
import 'package:ffigen/ffigen.dart' as ffigen;
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  /*generate(Config(
    target: Target(
      triple: 'x86_64-apple-macosx10.14',
      sdk: Uri.directory('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'),
    ),
    input: SwiftFileInput(
      module: 'SwiftgenTest',
      files: [Uri.file('/Users/liama/dev/native/pkgs/swift2objc/test/integration/classes_and_methods_input.swift')],
    ),
    tempDir: Uri.directory('temp'),
    outputModule: 'SwiftgenTestWrapper',
    objcSwiftFile: Uri.file('SwiftgenTestWrapper.swift'),
    ffigen: FfiGenConfig(
      output: Uri.file('SwiftgenTestWrapper.dart'),
      outputObjC: Uri.file('SwiftgenTestWrapper.m'),
      externalVersions: ffigen.ExternalVersions(
        ios: ffigen.Versions(min: Version(12, 0, 0)),
        macos: ffigen.Versions(min: Version(10, 14, 0)),
      ),
    ),
  ));*/
  generate(Config(
    target: Target(
      triple: 'x86_64-apple-macosx14.0',
      sdk: Uri.directory('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'),
    ),
    input: SwiftModuleInput(
      module: 'AVFoundation',
    ),
    tempDir: Uri.directory('temp'),
    objcSwiftPreamble: 'import AVFoundation',
    outputModule: 'AVFoundationWrapper',
    objcSwiftFile: Uri.file('AVFoundationWrapper.swift'),
    ffigen: FfiGenConfig(
      output: Uri.file('AVFoundationWrapper.dart'),
      outputObjC: Uri.file('AVFoundationWrapper.m'),
      externalVersions: ffigen.ExternalVersions(
        ios: ffigen.Versions(min: Version(12, 0, 0)),
        macos: ffigen.Versions(min: Version(10, 14, 0)),
      ),
    ),
  ));
}
