import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/ui/screens/cook_mode_screen.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Future<AppState> _state() async {
  final state = AppState(
    store: MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  return state;
}

void main() {
  test('app bars pick status-bar icons that contrast with the paper', () {
    final light = morphThemeData(
      MorphColors.light,
    ).appBarTheme.systemOverlayStyle!;
    expect(light.statusBarBrightness, Brightness.light);
    expect(light.statusBarIconBrightness, Brightness.dark);
    final dark = morphThemeData(
      MorphColors.dark,
    ).appBarTheme.systemOverlayStyle!;
    expect(dark.statusBarBrightness, Brightness.dark);
    expect(dark.statusBarIconBrightness, Brightness.light);
    // Like AppBar's own default, Android's navigation bar stays untouched.
    expect(light.systemNavigationBarColor, isNull);
    expect(light.systemNavigationBarIconBrightness, isNull);
  });

  testWidgets('transparent app bars on light paper use dark icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: morphThemeData(MorphColors.light),
        home: Scaffold(
          appBar: AppBar(title: const Text('PDF')),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('screens without an app bar follow the theme', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const ThemedApp()),
    );
    await tester.pumpAndSettle();
    // The outermost region is the app-wide default under every route.
    final root = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(root.value.statusBarBrightness, Brightness.light);
    expect(root.value.statusBarIconBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('cook mode keeps light icons on its dark page', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final recipe = PersonalRecipe.create(
      title: 'Soup',
      timeMinutes: 10,
      servings: 2,
      ingredients: [PersonalRecipeIngredient(name: 'Water', qty: 1, unit: 'l')],
      steps: [PersonalRecipeStep(text: 'Simmer.')],
    ).asRecipe();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: morphThemeData(MorphColors.light),
          home: CookModeScreen(recipe: recipe),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });
}
