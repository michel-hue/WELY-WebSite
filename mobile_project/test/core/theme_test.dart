import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/theme/app_theme.dart';
import 'package:mobile_project/core/theme/tokens.dart';

void main() {
  test('light ivoire theme with Inter', () {
    final theme = buildAppTheme();
    expect(theme.scaffoldBackgroundColor, WellyColors.ivoire);
    expect(theme.brightness.name, 'light');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.colorScheme.primary, WellyColors.ink);
    expect(theme.colorScheme.secondary, WellyColors.laiton);
  });
}
