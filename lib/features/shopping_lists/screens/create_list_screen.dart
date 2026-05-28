import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class CreateListScreen extends StatelessWidget {
  const CreateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Create List',
      description:
          'List creation fields and Firestore writes will be added here.',
    );
  }
}
