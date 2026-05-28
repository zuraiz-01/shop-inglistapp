import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/shopping_lists/providers/shopping_lists_provider.dart';
import 'features/shopping_lists/screens/create_list_screen.dart';
import 'features/shopping_lists/screens/home_screen.dart';
import 'features/shopping_lists/screens/list_detail_screen.dart';

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ShoppingListsProvider>(
          create: (_) => ShoppingListsProvider(),
          update: (_, authProvider, shoppingListsProvider) {
            final provider = shoppingListsProvider ?? ShoppingListsProvider();
            provider.updateCurrentUser(authProvider.currentUser);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: 'Shared Shopping Lists',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.signup: (_) => const SignupScreen(),
          AppRoutes.home: (_) => const HomeScreen(),
          AppRoutes.createList: (_) => const CreateListScreen(),
          AppRoutes.listDetail: (_) => const ListDetailScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
        },
      ),
    );
  }
}
