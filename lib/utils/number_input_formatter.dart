import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Cleaning the input: remove points (thousands) and replace comma with dot for parsing
    String newText = newValue.text.replaceAll('.', '');
    
    // Check if it's a valid number part (allow one comma)
    // We allow '-' at the beginning for negative numbers
    if (newText == '-') return newValue;

    // Split integer and decimal parts
    List<String> parts = newText.split(',');
    
    // If more than one comma, ignore the last input
    if (parts.length > 2) {
      return oldValue;
    }

    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // Handle negative sign
    bool isNegative = integerPart.startsWith('-');
    if (isNegative) integerPart = integerPart.substring(1);

    // Format integer part with dots
    final formatter = NumberFormat('#,###', 'es_UY');
    try {
      if (integerPart.isNotEmpty) {
         // parse to double to format, but since we stripped non-digits (except -), 
         // we might need to be careful with just parsing int if it exceeds size, 
         // but strictly it's a string of digits.
         // Simpler approach: Manual insertion of dots from right to left
         integerPart = _formatThousands(integerPart);
      }
    } catch (e) {
      return oldValue;
    }

    if (isNegative) integerPart = '-$integerPart';

    String newString = integerPart;
    if (parts.length > 1 || newText.endsWith(',')) {
      newString += ',$decimalPart';
    }

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  String _formatThousands(String s) {
    if (s.isEmpty) return s;
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}
