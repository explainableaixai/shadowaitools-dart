import 'dart:io';
import 'package:shadowaitools/shadowaitools.dart';
Future<void> main() async { final client = ShadowAIToolsClient(apiKey: Platform.environment['AQ_API_KEY'] ?? ''); try { print(await client.scan('dns-export.csv')); } finally { client.close(); } }
