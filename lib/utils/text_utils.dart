/// Tiện ích xử lý chuỗi tiếng Việt
library;

const _withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Đưa chuỗi về dạng chữ thường, bỏ dấu tiếng Việt và khoảng trắng thừa để so sánh khi tìm kiếm.
/// Vd: "  Trà Sữa  Đào " → "tra sua dao"
String normalizeForSearch(String input) {
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = _withDiacritics.indexOf(char);
    buffer.write(index >= 0 ? _withoutDiacritics[index] : char);
  }
  return buffer
      .toString()
      // Dấu dạng tổ hợp (Unicode NFD, vd chữ gõ từ một số bàn phím): bỏ luôn ký tự dấu rời
      .replaceAll(RegExp('[̀-ͯ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
