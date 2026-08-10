class RaporUtils {
  static String getPredikat(double n) {
    if (n >= 90) return 'A (Mumtaz)';
    if (n >= 80) return 'B (Jayyid Jiddan)';
    if (n >= 70) return 'C (Jayyid)';
    if (n >= 60) return 'D (Maqbul)';
    return 'E (Rasib)';
  }

  static String sanitizeText(String text) {
    if (text.isEmpty) return '';

    return text
        .replaceAll(RegExp(r'[‘’`´ʼ′]'), "'")
        .replaceAll(RegExp(r'[“”]'), '"')
        .replaceAll(RegExp(r'[—–]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
