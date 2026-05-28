import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'List Detail',
      description:
          'Shopping items, purchase state, and sharing controls will be added here.',
    );
  }
}
