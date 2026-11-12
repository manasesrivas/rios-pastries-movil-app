import '../constants/api_constants.dart';

String? resolveImageUrl(String? image) {
  final path = image?.trim();
  if (path == null || path.isEmpty) return null;

  final uri = Uri.tryParse(path);
  if (uri == null) return path;
  if (uri.hasScheme || uri.hasAuthority) {
    return uri.hasAuthority && !uri.hasScheme
        ? Uri.parse(ApiConstants.baseUrl).resolveUri(uri).toString()
        : path;
  }

  if (uri.path.startsWith('image/upload/')) {
    return Uri.parse(
      'https://res.cloudinary.com/${ApiConstants.cloudinaryCloudName}/',
    ).resolveUri(uri).toString();
  }

  return Uri.parse(ApiConstants.baseUrl).resolveUri(uri).toString();
}
