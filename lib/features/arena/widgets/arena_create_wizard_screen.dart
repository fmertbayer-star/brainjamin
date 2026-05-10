// TODO: copywriter polish (EN strings live in app_en.arb).

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mascot_empty_state.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';

class ArenaCreateWizardScreen extends StatefulWidget {
  const ArenaCreateWizardScreen({super.key});

  @override
  State<ArenaCreateWizardScreen> createState() =>
      _ArenaCreateWizardScreenState();
}

class _ArenaCreateWizardScreenState extends State<ArenaCreateWizardScreen> {
  final ArenaService _arenaService = ArenaService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();

  int _step = 0;

  /// `list` or `battle` (battle not selectable until Sprint 3.5d).
  String _mode = 'list';

  /// `preset` or `custom_topic`.
  String _sourceTab = 'preset';

  String? _categoryId;
  DateTime? _scheduledLocal;

  bool _checkingViability = false;
  bool? _topicViable;
  String? _topicSuggestion;

  bool _overlayCreating = false;
  bool _overlayGenerating = false;

  String? _createdArenaId;
  String? _inviteCode;
  String? _scheduleError;

  static const int _minLeadMs = 10 * 60 * 1000;
  static const int _maxLeadMs = 24 * 60 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    _categoryId = kV1CategoryIds.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  bool _scheduleValid(DateTime? dt) {
    if (dt == null) return false;
    final ms = dt.millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    return ms >= now + _minLeadMs && ms <= now + _maxLeadMs;
  }

  bool _step1FieldsValid(AppLocalizations l10n) {
    if (!_scheduleValid(_scheduledLocal)) {
      return false;
    }
    if (_sourceTab == 'preset') {
      return _categoryId != null && _categoryId!.isNotEmpty;
    }
    final t = _topicController.text.trim();
    return t.length >= 3 && t.length <= 80;
  }

  String _stepTitle(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return l10n.arena_create_step_basics;
      case 1:
        return l10n.arena_create_step_details;
      default:
        return l10n.arena_create_step_summary;
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 11)),
      firstDate: now,
      lastDate: now.add(const Duration(hours: 24)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 11))),
    );
    if (time == null || !mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _scheduledLocal = combined;
      _scheduleError = _scheduleValid(combined)
          ? null
          : AppLocalizations.of(context).arena_create_schedule_invalid;
    });
  }

  Future<void> _checkViability() async {
    final l10n = AppLocalizations.of(context);
    final t = _topicController.text.trim();
    if (t.length < 3 || t.length > 80) {
      return;
    }
    setState(() {
      _checkingViability = true;
      _topicViable = null;
      _topicSuggestion = null;
    });
    try {
      final r = await _arenaService.checkCustomTopicViability(t);
      if (!mounted) return;
      final v = r['viable'];
      setState(() {
        _topicViable = v == true;
        _topicSuggestion = r['suggestion'] is String ? r['suggestion'] as String : null;
        _checkingViability = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingViability = false;
        _topicViable = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.arena_join_error_generic)),
      );
    }
  }

  bool _isPoolInsufficient(ArenaServiceException e) {
    final m = e.message.toLowerCase();
    return m.contains('arena_pool_insufficient');
  }

  Future<void> _createArena() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _overlayCreating = true;
      _overlayGenerating = false;
    });
    try {
      final name = _nameController.text.trim();
      final scheduledMs = _scheduledLocal!.millisecondsSinceEpoch;
      final create = await _arenaService.createArena(
        mode: _mode,
        name: name.isEmpty ? null : name,
        sourceType: _sourceTab == 'preset' ? 'preset' : 'custom_topic',
        categoryId: _sourceTab == 'preset' ? _categoryId : null,
        customTopic: _sourceTab == 'custom_topic'
            ? _topicController.text.trim()
            : null,
        scheduledStartAt: scheduledMs,
      );
      final aid = create['arena_id'];
      final code = create['invite_code'];
      if (aid is! String ||
          aid.isEmpty ||
          code is! String ||
          code.isEmpty) {
        throw StateError('createArena missing arena_id or invite_code');
      }
      _createdArenaId = aid;
      _inviteCode = code;

      if (!mounted) return;
      setState(() {
        _overlayCreating = false;
        _overlayGenerating = true;
      });

      try {
        await _arenaService.generateArenaQuestions(aid);
      } on ArenaServiceException catch (ge) {
        if (!mounted) return;
        setState(() => _overlayGenerating = false);
        if (_isPoolInsufficient(ge)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.arena_pool_insufficient_message)),
          );
          setState(() => _step = 1);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.arena_join_error_generic}\n${ge.message}')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _overlayGenerating = false);
      final uri = Uri(
        path: '/arena/invite-share',
        queryParameters: {'arenaId': aid, 'inviteCode': code},
      );
      context.go(uri.toString());
    } on ArenaServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _overlayCreating = false;
        _overlayGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.arena_join_error_generic}\n${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overlayCreating = false;
        _overlayGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.arena_join_error_generic)),
      );
    }
  }

  Future<void> _retryGenerateOnly() async {
    final id = _createdArenaId;
    final code = _inviteCode;
    if (id == null || code == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _overlayGenerating = true);
    try {
      await _arenaService.generateArenaQuestions(id);
      if (!mounted) return;
      setState(() => _overlayGenerating = false);
      context.go(
        Uri(
          path: '/arena/invite-share',
          queryParameters: {'arenaId': id, 'inviteCode': code},
        ).toString(),
      );
    } on ArenaServiceException catch (e) {
      if (!mounted) return;
      setState(() => _overlayGenerating = false);
      if (_isPoolInsufficient(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.arena_pool_insufficient_message)),
        );
        setState(() => _step = 1);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arena_screen_create_cta)),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _stepTitle(l10n),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildStepBody(l10n)),
                _buildNavRow(l10n),
              ],
            ),
          ),
          if (_overlayCreating || _overlayGenerating)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: MascotEmptyState(
                  title: _overlayGenerating
                      ? l10n.arena_create_generating
                      : l10n.arena_create_creating,
                  body: '',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepBody(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return ListView(
          children: [
            RadioListTile<String>(
              title: Text(l10n.arena_create_mode_list),
              value: 'list',
              groupValue: _mode,
              onChanged: (v) {
                if (v != null) setState(() => _mode = v);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.arena_create_mode_battle),
              subtitle: Text(l10n.arena_create_mode_battle_disabled),
              value: 'battle',
              groupValue: _mode,
              // TODO: Battle Arena (Sprint 3.5d)
              onChanged: null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.arena_create_name_hint,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case 1:
        return ListView(
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'preset',
                  label: Text(l10n.arena_create_category_preset),
                ),
                ButtonSegment<String>(
                  value: 'custom_topic',
                  label: Text(l10n.arena_create_category_custom),
                ),
              ],
              selected: {_sourceTab},
              onSelectionChanged: (s) {
                setState(() => _sourceTab = s.first);
              },
            ),
            const SizedBox(height: 16),
            if (_sourceTab == 'preset')
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: InputDecoration(
                  labelText: l10n.arena_create_category_preset,
                ),
                items: kV1CategoryIds
                    .map(
                      (id) => DropdownMenuItem<String>(
                        value: id,
                        child: Text(_categoryLabel(l10n, id)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              )
            else ...[
              TextField(
                controller: _topicController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.arena_create_topic_hint,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    _checkingViability ? null : _checkViability,
                child: Text(l10n.arena_create_topic_check_viability),
              ),
              if (_checkingViability)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              if (_topicViable == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.arena_create_topic_viable)),
                    ],
                  ),
                ),
              if (_topicViable == false)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _topicSuggestion != null && _topicSuggestion!.isNotEmpty
                              ? l10n.arena_create_topic_not_viable(_topicSuggestion!)
                              : l10n.arena_create_topic_not_viable_no_suggestion,
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(l10n.arena_create_schedule_title,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickSchedule,
              child: Text(
                _scheduledLocal == null
                    ? l10n.arena_create_schedule_title
                    : _scheduledLocal!.toLocal().toString(),
              ),
            ),
            if (_scheduleError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _scheduleError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      default:
        return ListView(
          children: [
            Text('${l10n.arena_create_mode_list}: ${_mode == 'list' ? l10n.arena_create_mode_list : l10n.arena_create_mode_battle}'),
            Text('${l10n.arena_create_name_hint}: ${_nameController.text.trim().isEmpty ? '—' : _nameController.text.trim()}'),
            const SizedBox(height: 8),
            if (_sourceTab == 'preset')
              Text(
                '${l10n.arena_create_category_preset}: ${_categoryId != null ? _categoryLabel(l10n, _categoryId!) : '—'}',
              )
            else
              Text('${l10n.arena_create_topic_hint}: ${_topicController.text.trim()}'),
            Text(
              '${l10n.arena_create_schedule_title}: ${_scheduledLocal?.toLocal() ?? '—'}',
            ),
            const SizedBox(height: 24),
            if (_createdArenaId != null &&
                _inviteCode != null &&
                !_overlayGenerating)
              TextButton(
                onPressed: _retryGenerateOnly,
                child: Text(l10n.arena_create_generating_retry),
              ),
          ],
        );
    }
  }

  Widget _buildNavRow(AppLocalizations l10n) {
    final step1Ok = _step != 1 || _step1FieldsValid(l10n);
    return SafeArea(
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step -= 1),
              child: Text(l10n.arena_create_back),
            ),
          const Spacer(),
          if (_step < 2)
            FilledButton(
              onPressed: step1Ok && (_step != 1 || _scheduleValid(_scheduledLocal))
                  ? () {
                      if (_step == 1) {
                        setState(() {
                          _scheduleError = _scheduleValid(_scheduledLocal)
                              ? null
                              : l10n.arena_create_schedule_invalid;
                        });
                        if (!_scheduleValid(_scheduledLocal)) return;
                      }
                      setState(() => _step += 1);
                    }
                  : null,
              child: Text(l10n.arena_create_next),
            )
          else
            FilledButton(
              onPressed: (_overlayCreating || _overlayGenerating)
                  ? null
                  : _createArena,
              child: Text(l10n.arena_create_create_button),
            ),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'history':
        return l10n.arena_category_history;
      case 'geography':
        return l10n.arena_category_geography;
      case 'movies_tv':
        return l10n.arena_category_movies_tv;
      case 'music':
        return l10n.arena_category_music;
      case 'sports':
        return l10n.arena_category_sports;
      case 'science':
        return l10n.arena_category_science;
      case 'technology':
        return l10n.arena_category_technology;
      case 'literature':
        return l10n.arena_category_literature;
      case 'art':
        return l10n.arena_category_art;
      case 'food_drink':
        return l10n.arena_category_food_drink;
      case 'animals':
        return l10n.arena_category_animals;
      case 'nature':
        return l10n.arena_category_nature;
      case 'pop_culture':
        return l10n.arena_category_pop_culture;
      case 'mythology':
        return l10n.arena_category_mythology;
      case 'video_games':
        return l10n.arena_category_video_games;
      case 'fashion':
        return l10n.arena_category_fashion;
      case 'astrology':
        return l10n.arena_category_astrology;
      case 'health':
        return l10n.arena_category_health;
      case 'space':
        return l10n.arena_category_space;
      case 'world_capitals':
        return l10n.arena_category_world_capitals;
      default:
        return id;
    }
  }
}
