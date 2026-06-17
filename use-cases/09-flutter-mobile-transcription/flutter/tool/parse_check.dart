// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:speechmatics_translate/data/transcript_parser.dart';

void main(List<String> args) {
  final j = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final p = parseJsonV2(j, diarized: true);
  print('segments: ${p.segments.length}');
  print('languages: ${p.languages}');
  print('fullText: ${p.fullText}');
  for (final s in p.segments) {
    print('  [${s.speaker} ${s.time}] ${s.parts.map((x) => "${x.lang}:${x.text}").join(" | ")}');
  }
}
