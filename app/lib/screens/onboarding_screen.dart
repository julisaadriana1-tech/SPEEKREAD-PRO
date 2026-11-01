import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final Set<String> _goals = {};
  String _role = 'Project Manager';
  final Set<String> _interests = {'project-management'};
  int _dailyGoal = 10;
  String _level = 'A2';
  bool _saving = false;

  static const _goalOptions = {
    'meetings': 'Participar en reuniones',
    'presentations': 'Hacer presentaciones',
    'clients': 'Hablar con clientes',
    'emails': 'Leer y escribir correos',
    'travel': 'Viajar',
    'daily': 'Vida cotidiana',
  };
  static const _roles = [
    'Project Manager', 'Analista', 'Líder de equipo',
    'Scrum Master', 'Product Owner', 'Otro',
  ];
  static const _interestOptions = {
    'project-management': 'Gestión de proyectos',
    'leadership': 'Liderazgo',
    'technology': 'Tecnología',
    'digital': 'Transformación digital',
    'data': 'Análisis de datos',
    'productivity': 'Productividad',
    'communication': 'Comunicación empresarial',
    'risk': 'Gestión de riesgos',
    'daily-life': 'Vida cotidiana',
    'finance': 'Finanzas personales',
    'travel': 'Viajes',
  };
  static const _levels = {
    'A1': 'Principiante: entiendo frases muy simples',
    'A2': 'Básico: leo correos cortos con ayuda',
    'B1': 'Intermedio: sigo una reunión si hablan despacio',
    'B2': 'Intermedio alto: leo documentos de trabajo',
    'C1': 'Avanzado: presento con algo de esfuerzo',
  };

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).saveOnboarding(
            jobRole: _role,
            goals: _goals.toList(),
            interests: _interests.toList(),
            dailyGoalMin: _dailyGoal,
            cefrLevel: _level,
          );
      ref.invalidate(profileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      setState(() => _saving = false);
    }
  }

  Widget _chips(Map<String, String> options, Set<String> selected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            FilterChip(
              label: Text(e.value),
              selected: selected.contains(e.key),
              onSelected: (v) => setState(
                  () => v ? selected.add(e.key) : selected.remove(e.key)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final steps = <(String, String, Widget)>[
      (
        '¿Para qué querés el inglés?',
        'Elegí todo lo que aplique.',
        _chips(_goalOptions, _goals)
      ),
      (
        '¿Cuál es tu rol?',
        'Adaptamos las lecturas a tu día a día.',
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in _roles)
            ChoiceChip(
                label: Text(r),
                selected: _role == r,
                onSelected: (_) => setState(() => _role = r)),
        ])
      ),
      (
        '¿Qué temas te interesan?',
        'Las lecciones de hoy priorizan estos temas.',
        _chips(_interestOptions, _interests)
      ),
      (
        'Tu meta y tu nivel',
        'Podés cambiarlos después desde Perfil.',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5 min')),
              ButtonSegment(value: 10, label: Text('10 min')),
              ButtonSegment(value: 15, label: Text('15 min')),
            ],
            selected: {_dailyGoal},
            onSelectionChanged: (s) => setState(() => _dailyGoal = s.first),
          ),
          const SizedBox(height: 20),
          for (final e in _levels.entries)
            ListTile(
              onTap: () => setState(() => _level = e.key),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _level == e.key
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _level == e.key
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(e.key,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(e.value),
            ),
        ])
      ),
    ];
    final (title, subtitle, body) = steps[_step];
    final last = _step == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                  value: (_step + 1) / steps.length,
                  borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 32),
              Text(title,
                  style: text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, style: text.bodyLarge),
              const SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(child: body)),
              Row(children: [
                if (_step > 0)
                  TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Atrás')),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => last ? _finish() : setState(() => _step++),
                    child: Text(last ? 'Empezar' : 'Continuar'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
