import 'package:flutter/material.dart';

import '../data/guide_sections.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// 各画面の機能や、そこに登場する用語・仕組みを画面単位でまとめたガイド。
/// 用語をアルファベット/カテゴリ順に並べた用語集(GlossaryScreen)とは異なり、
/// 「この画面では何ができるか」という視点で読める導入向けの解説を提供する。
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('ガイド', 'Guide')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: guideSections.length,
          itemBuilder: (context, i) =>
              _GuideSectionCard(section: guideSections[i]),
        ),
      ),
    );
  }
}

class _GuideSectionCard extends StatelessWidget {
  final GuideSection section;
  const _GuideSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: Icon(
          section.icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(section.overview),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final topic in section.topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
