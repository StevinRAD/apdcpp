import 'package:supabase_flutter/supabase_flutter.dart';

Uri apiUri(String endpoint, [Map<String, String>? queryParameters]) {
  final cleanEndpoint = endpoint.trim();
  if (cleanEndpoint.startsWith('http://') ||
      cleanEndpoint.startsWith('https://')) {
    return Uri.parse(cleanEndpoint).replace(queryParameters: queryParameters);
  }
  return Uri(path: cleanEndpoint, queryParameters: queryParameters);
}

String buildUploadUrl(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) {
    return '';
  }

  final cleanName = fileName.trim();
  if (cleanName.startsWith('http://') || cleanName.startsWith('https://')) {
    return cleanName;
  }

  try {
    return Supabase.instance.client.storage
        .from('uploads')
        .getPublicUrl(cleanName);
  } catch (_) {
    return '';
  }
}
