import 'package:intl/intl.dart';

class FormatUtils {
  
  /// Formats a number with dot as thousand separator and comma as decimal separator.
  /// Example: 1.234,56
  static String formatValue(double amount) {
    // es_UY locale uses dot for thousands and comma for decimal
    return NumberFormat.decimalPattern('es_UY').format(amount);
  }

  /// Formats currency with custom symbols.
  /// UYU -> $U 1.234,56
  /// USD -> U$S 1.234,56
  static String formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(
      locale: 'es_UY', 
      symbol: '', // We add symbol manually to control spacing and format
      decimalDigits: 2
    );
    
    final valueStr = formatter.format(amount).trim();
    
    if (currency == 'USD') {
      return "U\$S $valueStr";
    } else {
      // Default to UYU ($U)
      return "\$U $valueStr";
    }
  }

  /// For charts where space is limited, maybe compact? 
  /// Or just standard. User asked for dot/comma.
  static String formatForChart(double value) {
     return NumberFormat.compact(locale: 'es_UY').format(value);
  }
}
