// Direct Dart invocation avoids analytics/cache writes to read-only cloud HOME.
// dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/check.dart [format]
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_style/dart_style.dart';

Future<void> main(List<String> args) async {
  final root = Directory.current.absolute.path;
  if (args.contains('format')) {
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    for (final folder in ['lib', 'test', 'tool']) {
      for (final file in Directory(
        folder,
      ).listSync(recursive: true).whereType<File>()) {
        if (file.path.endsWith('.dart'))
          file.writeAsStringSync(formatter.format(file.readAsStringSync()));
      }
    }
    print('Formatted Dart source.');
    return;
  }
  final sdk = File(Platform.resolvedExecutable).parent.parent.path;
  final collection = AnalysisContextCollection(
    includedPaths: ['$root/lib', '$root/test', '$root/tool'],
    resourceProvider: PhysicalResourceProvider(
      stateLocation: '$root/.dart_tool/analyzer-state',
    ),
    sdkPath: sdk,
  );
  var count = 0, files = 0;
  for (final context in collection.contexts) {
    for (final path in context.contextRoot.analyzedFiles()) {
      if (!path.endsWith('.dart')) continue;
      files++;
      final result = await context.currentSession.getResolvedUnit(path);
      if (result is ResolvedUnitResult) {
        for (final error in result.diagnostics) {
          print(
            '$path:${result.lineInfo.getLocation(error.offset).lineNumber}: ${error.diagnosticCode.lowerCaseName}: ${error.message}',
          );
          count++;
        }
      }
    }
  }
  print('Analyzed $files Dart files; $count issues.');
  await collection.dispose();
  exitCode = count == 0 ? 0 : 1;
}
