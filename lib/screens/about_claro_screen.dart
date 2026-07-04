import 'package:flutter/material.dart';

class AboutClaroScreen extends StatelessWidget {
  const AboutClaroScreen({super.key});

  static const _accentRed = Color(0xFF6B2020);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _accentRed),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tungkol sa CLARO', style: TextStyle(color: _accentRed, fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            Text(
              'Alamin ang Tungkol sa Amin!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [BoxShadow(color: theme.shadowColor.withAlpha(20), blurRadius: 6)],
              ),
              child: Text(
                'Ang CLARO ay isang AI-powered mobile application na tumutulong sa mga mamimili ng groceries na maunawaan ang nutritional information ng mga lokal na de-latang pagkain. Sa pamamagitan ng pag-scan ng produkto, agad na makikita ng mga user ang pinasimpleng nutrition summaries, health advisories, allergen warnings, at product comparisons, pati na rin ang mga accessibility features tulad ng voice assistance, upang mas makagawa ng mas maalam at mas healthy na desisyon sa pagbili.',
                style: TextStyle(color: theme.colorScheme.onSurface, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Tungkol sa Mga Developer', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _DevCard(name: 'Mary Faith Ardientes', role: 'Project Manager'),
                _DevCard(name: 'Jay Bhie Bite', role: 'Front-end Developer'),
                _DevCard(name: 'Rochelle Ann Salucop', role: 'Back-end Developer'),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _DevCard extends StatelessWidget {
  final String name;
  final String role;
  const _DevCard({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 4),
        Text(role, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
      ],
    );
  }
}
