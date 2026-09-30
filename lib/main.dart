// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
//
// import 'core/theme/app_colors.dart';
// import 'features/auth/auth_gate.dart';
// import 'features/auth/signin/view.dart';
//
// Future<void> main() async {
//   await dotenv.load(fileName: ".env");
//   await Supabase.initialize(
//     url: dotenv.env['SUPABASE_URL']!,
//     anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
//     authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
//   );
//   // ProviderScope must wrap the whole app. Riverpod keeps all providers inside it.
//   runApp(const ProviderScope(child: MyApp()));
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Chat App',
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
//         scaffoldBackgroundColor: AppColors.background,
//       ),
//       // AuthGate opens Sign In or Home, depending on login.
//       home: const AuthGate(),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_gate.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return  MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      // The selected preset builds the whole app theme.
      theme: themeState.preset.toThemeData(),
      home: const AuthGate(),
    );
  }
}
