// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../base/file_system.dart';
import '../../base/logger.dart';
import '../../macos/xcode.dart';
import '../../project.dart';
import 'ios_migrator.dart';

/// Xcode 11.4 requires linked and embedded frameworks to contain all targeted architectures before build phases are run.
/// This caused issues switching between a real device and simulator due to architecture mismatch.
/// Remove the linking and embedding logic from the Xcode project to give the tool more control over these.
class RemoveFrameworkLinkAndEmbeddingMigration extends IOSMigrator {
  RemoveFrameworkLinkAndEmbeddingMigration(
      IosProject project,
      Logger logger,
      Xcode xcode,
      ) : _xcodeProjectInfoFile = project.xcodeProjectInfoFile,
        _xcode = xcode,
        super(logger);

  final File _xcodeProjectInfoFile;
  final Xcode _xcode;

  /// Inspect [project] for necessary migrations and rewrite files as needed.
  @override
  bool migrate() {
    return _migrateXcodeProjectInfoFile();
  }

  bool _migrateXcodeProjectInfoFile() {
    if (!_xcodeProjectInfoFile.existsSync()) {
      logger.printTrace('Xcode project not found, skipping migration');
      return true;
    }

    bool migrationFailure = false;
    processFileLines(_xcodeProjectInfoFile, (String line) {
      // App.framework Frameworks reference.
      // isa = PBXFrameworksBuildPhase;
      // files = (
      //    3B80C3941E831B6300D905FE /* App.framework in Frameworks */,
      if (line.contains('3B80C3941E831B6300D905FE')) {
        return null;
      }

      // App.framework Embed Framework reference (build phase to embed framework).
      // 3B80C3951E831B6300D905FE /* App.framework in Embed Frameworks */,
      if (line.contains('3B80C3951E831B6300D905FE')
          || line.contains('741F496821356857001E2961')) { // Ephemeral add-to-app variant.
        return null;
      }

      // App.framework project file reference (seen in Xcode navigator pane).
      // isa = PBXGroup;
      // children = (
      //	 3B80C3931E831B6300D905FE /* App.framework */,
      if (line.contains('3B80C3931E831B6300D905FE')
          || line.contains('741F496521356807001E2961')) { // Ephemeral add-to-app variant.
        return null;
      }

      // Flutter.framework Frameworks reference.
      // isa = PBXFrameworksBuildPhase;
      // files = (
      //   9705A1C61CF904A100538489 /* Flutter.framework in Frameworks */,
      if (line.contains('9705A1C61CF904A100538489')) {
        return null;
      }

      // Flutter.framework Embed Framework reference (build phase to embed framework).
      // 9705A1C71CF904A300538489 /* Flutter.framework in Embed Frameworks */,
      if (line.contains('9705A1C71CF904A300538489')
          || line.contains('741F496221355F47001E2961')) { // Ephemeral add-to-app variant.
        return null;
      }

      // Flutter.framework project file reference (seen in Xcode navigator pane).
      // isa = PBXGroup;
      // children = (
      //	 9740EEBA1CF902C7004384FC /* Flutter.framework */,
      if (line.contains('9740EEBA1CF902C7004384FC')
          || line.contains('741F495E21355F27001E2961')) { // Ephemeral add-to-app variant.
        return null;
      }

      // Embed and thin frameworks in a script instead of using Xcode's link / embed build phases.
      const String thinBinaryScript = 'xcode_backend.sh\\" thin';
      if (line.contains(thinBinaryScript)) {
        return line.replaceFirst(thinBinaryScript, 'xcode_backend.sh\\" embed_and_thin');
      }

      if (line.contains('/* App.framework ') || line.contains('/* Flutter.framework ')) {
        migrationFailure = true;
      }

      return line;
    });

    if (migrationFailure) {
      // Print scary message if the user is on Xcode 11.4 or greater, or if Xcode isn't installed.
      final bool xcodeIsInstalled = _xcode.isInstalled;
      if(!xcodeIsInstalled || (_xcode.majorVersion > 11 || (_xcode.majorVersion == 11 && _xcode.minorVersion >= 4))) {
        logger.printError('Your Xcode project requires migration. See https://github.com/flutter/flutter/issues/50568 for details.');
        return false;
      }
    }

    return true;
  }
}
