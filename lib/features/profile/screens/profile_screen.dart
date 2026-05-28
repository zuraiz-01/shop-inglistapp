import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Profile',
      description: 'User profile and account actions will be added here.',
    );
  }
}
