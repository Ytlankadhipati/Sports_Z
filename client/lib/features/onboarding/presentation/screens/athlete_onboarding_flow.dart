import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/screens/home_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

/// Final v3.0 onboarding sequence. O03/O04 are intentionally absent.
enum AthleteOnboardingStep {
  basicIdentity('O01', 'Basic identity'),
  dateOfBirth('O02', 'Date of birth'),
  sportSelection('O05', 'Choose your sport'),
  sportDetails('O06', 'Sport details'),
  about('O07', 'About you'),
  physical('O08', 'Physical information'),
  privacy('O09', 'Privacy defaults'),
  complete('O10', 'Profile complete'),
  sportszId('O11', 'Your SportsZ ID'),
  verify('O12', 'Verification');

  const AthleteOnboardingStep(this.id, this.title);
  final String id;
  final String title;
}

class AthleteOnboardingFlow extends ConsumerStatefulWidget {
  const AthleteOnboardingFlow({super.key});

  @override
  ConsumerState<AthleteOnboardingFlow> createState() =>
      _AthleteOnboardingFlowState();
}

class _AthleteOnboardingFlowState extends ConsumerState<AthleteOnboardingFlow> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _bio = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _search = TextEditingController();
  final Map<String, dynamic> _profile = {};
  final List<Map<String, dynamic>> _sports = [];
  final Map<String, Map<String, dynamic>> _sportConfigs = {};
  final Set<String> _selectedSports = {};
  String? _gender;
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _fetchingSports = false;
  bool _fetchingConfig = false;
  String? _error;

  static const _steps = AthleteOnboardingStep.values;
  static const _gold = Color(0xFFBB8610);
  static const _pale = Color(0xFFFFF8E7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resume();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _region.dispose();
    _bio.dispose();
    _height.dispose();
    _weight.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;
      try {
        data = await ref.read(profileControllerProvider.notifier).loadProfile();
      } on DioException catch (error) {
        if (apiExceptionFrom(error)?.statusCode != 404) rethrow;
        data = <String, dynamic>{};
      }
      if (data.isNotEmpty) {
        _profile.addAll(data);
        _name.text = data['full_name'] as String? ?? '';
        _city.text = data['city'] as String? ?? '';
        _region.text = data['region'] as String? ?? '';
        _bio.text = data['bio'] as String? ?? '';
        final savedGender = (data['gender'] as String?)?.toLowerCase();
        _gender =
            const {
              'female',
              'male',
              'non_binary',
              'prefer_not_to_say',
            }.contains(savedGender)
            ? savedGender
            : null;
        final physical = data['physical'];
        if (physical is Map) {
          _height.text = physical['height_cm']?.toString() ?? '';
          _weight.text = physical['weight_kg']?.toString() ?? '';
        }
        final privacy = data['privacy'];
        if (privacy is Map) {
          _discoverable = privacy['discoverable'] as bool? ?? true;
          _contactPolicy =
              privacy['contact_policy'] as String? ?? 'connections_only';
        }
        final sports = data['sports'];
        if (sports is List) {
          for (final item in sports.whereType<Map>()) {
            final id = item['sport_id']?.toString();
            if (id != null && id.isNotEmpty) _selectedSports.add(id);
          }
        }
        _step = _resumeAt(data);
      }
      if (mounted) setState(() => _loading = false);
      if (_step == 2) await _loadSports();
      if (_step == 7) await _refreshProfile();
      if (_step == 3) await _loadConfigs();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  int _resumeAt(Map<String, dynamic> p) {
    if ((p['full_name'] as String? ?? '').isEmpty ||
        (p['gender'] as String? ?? '').isEmpty) {
      return 0;
    }
    if (p['date_of_birth'] == null) return 1;
    if ((p['sports'] as List? ?? const []).isEmpty) return 2;
    if (p['bio'] == null) return 3;
    if (p['bio'] == '') return 4;
    if (p['physical'] == null) return 5;
    if (p['privacy'] == null) return 6;
    if (p['sportsz_id'] == null) return 7;
    return 7;
  }

  Future<void> _refreshProfile() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ref
          .read(profileControllerProvider.notifier)
          .loadProfile();
      _profile.addAll(data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSports() async {
    setState(() {
      _fetchingSports = true;
      _error = null;
    });
    try {
      _sports
        ..clear()
        ..addAll(
          await ref
              .read(profileControllerProvider.notifier)
              .loadSportsCatalog(),
        );
      if (mounted) setState(() => _fetchingSports = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchingSports = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _fetchingConfig = true;
      _error = null;
    });
    try {
      for (final id in _selectedSports) {
        final data = await ref
            .read(profileControllerProvider.notifier)
            .loadSportConfig(id);
        final sport = data['sport'];
        if (sport is Map) _sportConfigs[id] = Map<String, dynamic>.from(sport);
      }
      if (mounted) setState(() => _fetchingConfig = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchingConfig = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  Future<bool> _save(Map<String, dynamic> patch) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(profileControllerProvider.notifier)
          .saveProfile(patch);
      _profile.addAll(data);
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continue() async {
    if (_saving) return;
    switch (_step) {
      case 0:
        if (!(_formKey.currentState?.validate() ?? false) || _gender == null) {
          setState(() => _error = 'Choose your gender to continue.');
          return;
        }
        if (!await _save({
          'full_name': _name.text.trim(),
          'gender': _gender,
          'city': _city.text.trim(),
          'region': _region.text.trim(),
        })) {
          return;
        }
      case 1:
        if (_profile['date_of_birth'] == null) {
          setState(() => _error = 'Select your date of birth.');
          return;
        }
      case 2:
        if (_selectedSports.isEmpty) {
          setState(() => _error = 'Choose at least one sport.');
          return;
        }
        final chosen = _selectedSports
            .map(
              (id) =>
                  _sports.firstWhere((s) => s['sport_id']?.toString() == id),
            )
            .toList();
        final sports = chosen
            .map(
              (s) => {
                'sport_id': s['sport_id'],
                'sport_name': s['name'],
                'positions': <String>[],
                'level': null,
              },
            )
            .toList();
        if (!await _save({'sports': sports})) return;
      case 3:
        if (_selectedSports.any((id) => !_sportConfigs.containsKey(id))) {
          setState(
            () => _error = 'Sport details are not available yet. Please retry.',
          );
          return;
        }
      case 4:
        if (!await _save({'bio': _bio.text.trim()})) return;
      case 5:
        final h = double.tryParse(_height.text.trim());
        final w = double.tryParse(_weight.text.trim());
        if (_height.text.isNotEmpty && (h == null || h < 30 || h > 300)) {
          setState(() => _error = 'Enter a height between 30 and 300 cm.');
          return;
        }
        if (_weight.text.isNotEmpty && (w == null || w < 1 || w > 500)) {
          setState(() => _error = 'Enter a weight between 1 and 500 kg.');
          return;
        }
        if (!await _save({
          'physical': {'height_cm': h, 'weight_kg': w},
        })) {
          return;
        }
      case 6:
        if (!await _save({
          'privacy': {
            'discoverable': _discoverable,
            'contact_policy': _contactPolicy,
            'field_overrides': <String, dynamic>{},
          },
        })) {
          return;
        }
      case 7:
        await _refreshProfile();
      case 8:
        await _refreshProfile();
      case 9:
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        }
        return;
    }
    if (!mounted) return;
    setState(() {
      _step = (_step + 1).clamp(0, _steps.length - 1);
      _error = null;
    });
    if (_step == 2 && _sports.isEmpty) await _loadSports();
    if (_step == 3) await _loadConfigs();
  }

  bool _discoverable = true;
  String _contactPolicy = 'connections_only';

  Future<void> _back() async {
    if (_step == 0) {
      final didPop = await Navigator.maybePop(context);
      if (!didPop && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _pickDob() async {
    final initial =
        DateTime.tryParse(_profile['date_of_birth']?.toString() ?? '') ??
        DateTime(2000, 1, 1);
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select date of birth',
    );
    if (value == null) return;
    final iso =
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    if (await _save({'date_of_birth': iso})) setState(() {});
  }

  String? get _formattedDob {
    final date = DateTime.tryParse(_profile['date_of_birth']?.toString() ?? '');
    if (date == null) return null;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? get _ageCategory {
    final birthDate = DateTime.tryParse(
      _profile['date_of_birth']?.toString() ?? '',
    );
    if (birthDate == null) return null;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= 18 ? 'Adult' : 'Youth';
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final saving = _saving;
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }
    if (_error != null && _profile.isEmpty && _step == 0) return _errorPage();
    final step = _steps[_step];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: saving ? null : _back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _pale,
                      border: Border.all(color: const Color(0xFFD8B45B)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      step.id,
                      style: const TextStyle(
                        color: Color(0xFF6E4F0A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _steps.length,
                        minHeight: 6,
                        color: _gold,
                        backgroundColor: const Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Step ${_step + 1} of ${_steps.length}',
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
                child: _body(step),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : _step == 2
                          ? _loadSports
                          : _step == 3
                          ? _loadConfigs
                          : _continue,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: saving || _fetchingSports || _fetchingConfig
                      ? null
                      : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: saving || _fetchingConfig
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_step == 9 ? 'Go to home' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPage() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: _gold),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: _resume, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 15,
          height: 1.45,
          color: Color(0xFF5F6368),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
  InputDecoration _decoration(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
      );

  Widget _body(AthleteOnboardingStep step) => switch (step) {
    AthleteOnboardingStep.basicIdentity => _identity(),
    AthleteOnboardingStep.dateOfBirth => _dob(),
    AthleteOnboardingStep.sportSelection => _sportSelection(),
    AthleteOnboardingStep.sportDetails => _sportDetails(),
    AthleteOnboardingStep.about => _about(),
    AthleteOnboardingStep.physical => _physical(),
    AthleteOnboardingStep.privacy => _privacy(),
    AthleteOnboardingStep.complete => _complete(),
    AthleteOnboardingStep.sportszId => _id(),
    AthleteOnboardingStep.verify => _verify(),
  };

  Widget _identity() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Tell us about yourself',
          'Add the basic details for your athlete profile.',
        ),
        TextFormField(
          controller: _name,
          decoration: _decoration('Full name'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your full name.' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: _decoration('Gender'),
          items: const [
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
            DropdownMenuItem(
              value: 'prefer_not_to_say',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _city,
          decoration: _decoration('City (optional)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _region,
          decoration: _decoration('Region / state (optional)'),
        ),
      ],
    ),
  );
  Widget _dob() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'When were you born?',
        'We use this to calculate your age category. Your exact date stays private.',
      ),
      const Text(
        'Date of birth',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formattedDob ?? 'Choose a date',
                  style: TextStyle(
                    color: _formattedDob == null
                        ? const Color(0xFF8A8A8A)
                        : const Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.calendar_month_outlined, color: _gold),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _pale,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF6E4F0A),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR AGE CATEGORY',
                    style: TextStyle(
                      color: Color(0xFF6E4F0A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ageCategory ?? 'Not calculated',
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Calculated automatically from your date of birth.',
                    style: TextStyle(
                      color: Color(0xFF5F6368),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF6D7378), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your exact date of birth is never shown on your public profile.',
                style: TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _sportSelection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Choose your sport',
        'Select a primary sport and any additional sports.',
      ),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: _decoration(
          'Search sports',
          suffix: const Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 14),
      if (_fetchingSports)
        const Center(child: CircularProgressIndicator(color: _gold))
      else if (_sports.isEmpty)
        const _EmptyCatalog()
      else
        ..._sports
            .where(
              (s) => (s['name']?.toString().toLowerCase() ?? '').contains(
                _search.text.toLowerCase(),
              ),
            )
            .map((sport) {
              final id = sport['sport_id']?.toString() ?? '';
              final selected = _selectedSports.contains(id);
              return Card(
                color: selected ? _pale : Colors.white,
                child: CheckboxListTile(
                  value: selected,
                  title: Text(sport['name']?.toString() ?? 'Sport'),
                  subtitle: selected
                      ? Text(
                          _selectedSports.first == id
                              ? 'Primary sport'
                              : 'Additional sport',
                        )
                      : null,
                  activeColor: _gold,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selectedSports.add(id);
                    } else {
                      _selectedSports.remove(id);
                    }
                  }),
                ),
              );
            }),
    ],
  );
  Widget _sportDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Sport details',
        'Details are based on the selected sports’ published configuration.',
      ),
      if (_selectedSports.isEmpty) const Text('Select a sport first.'),
      ..._selectedSports.map((id) {
        final config = _sportConfigs[id];
        final item = _sports
            .where((sport) => sport['sport_id']?.toString() == id)
            .firstOrNull;
        final sportConfig = config?['config'];
        final fields = sportConfig is Map ? sportConfig['fields'] : null;
        final detail = config == null
            ? 'Sport configuration is unavailable.'
            : fields is List && fields.isNotEmpty
            ? 'Configured sport details are available.'
            : 'No sport detail fields are configured.';
        return Card(
          color: _pale,
          child: ListTile(
            title: Text(item?['name']?.toString() ?? id),
            subtitle: Text(detail),
          ),
        );
      }),
    ],
  );
  Widget _about() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('About you', 'Share a short introduction. This is optional.'),
      TextField(
        controller: _bio,
        maxLength: 500,
        maxLines: 5,
        decoration: _decoration(
          'Bio',
          hint: 'Tell others a little about yourself',
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () async {
            _bio.clear();
            if (await _save({'bio': ''}) && mounted) setState(() => _step++);
          },
          child: const Text('Skip'),
        ),
      ),
    ],
  );
  Widget _physical() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Physical information',
        'Measurements are optional and can be updated later.',
      ),
      TextField(
        controller: _height,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _decoration('Height', hint: 'cm'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _weight,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _decoration('Weight', hint: 'kg'),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () async {
            if (await _save({'physical': <String, dynamic>{}}) && mounted) {
              setState(() => _step++);
            }
          },
          child: const Text('Skip'),
        ),
      ),
    ],
  );
  Widget _privacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Privacy defaults',
        'Choose how people can find and contact you.',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Discoverable'),
        subtitle: const Text('Allow your profile to appear in athlete search.'),
        value: _discoverable,
        activeThumbColor: _gold,
        onChanged: (v) => setState(() => _discoverable = v),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _contactPolicy,
        decoration: _decoration('Who can contact you?'),
        items: const [
          DropdownMenuItem(
            value: 'connections_only',
            child: Text('Connections only'),
          ),
          DropdownMenuItem(value: 'anyone', child: Text('Anyone')),
          DropdownMenuItem(value: 'nobody', child: Text('Nobody')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _contactPolicy = v);
        },
      ),
    ],
  );
  Widget _complete() {
    final sports = _profile['sports'] as List? ?? const [];
    final primary = sports
        .whereType<Map>()
        .where((s) => s['is_primary'] == true)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Your profile is ready',
          'Your profile details have been saved.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _pale,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile['full_name']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(primary?['sport_name']?.toString() ?? 'Sport not selected'),
              const SizedBox(height: 16),
              Text('Profile completion: ${_profile['completion'] ?? 0}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _id() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Your SportsZ ID', 'This ID was issued by SportsZ.'),
      if (_profile['sportsz_id'] is String)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pale,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold),
          ),
          child: Column(
            children: [
              Text(
                _profile['sportsz_id'].toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(_profile['full_name']?.toString() ?? ''),
              const SizedBox(height: 4),
              Text(_primarySportName()),
            ],
          ),
        )
      else
        const Text(
          'A SportsZ ID has not been issued yet. It will appear here when available.',
        ),
      const SizedBox(height: 18),
      const Text(
        'SportsZ ID is not a government ID.',
        style: TextStyle(color: Color(0xFF5F6368)),
      ),
    ],
  );
  String _primarySportName() {
    final sports = _profile['sports'] as List? ?? const [];
    final s = sports
        .whereType<Map>()
        .where((x) => x['is_primary'] == true)
        .firstOrNull;
    return s?['sport_name']?.toString() ?? '';
  }

  Widget _verify() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Ready to verify?',
        'Verification is optional and handled in the verification flow.',
      ),
      const Icon(Icons.verified_user_outlined, size: 64, color: _gold),
      const SizedBox(height: 16),
      const Text('You can start verification later from your account.'),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The verification request flow is not available yet.',
            ),
          ),
        ),
        child: const Text('Verify now'),
      ),
    ],
  );
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(Icons.sports, size: 42, color: Color(0xFF8A8A8A)),
        SizedBox(height: 12),
        Text(
          'No sports are available yet.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Please try again when the SportsZ catalog is ready.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5F6368)),
        ),
      ],
    ),
  );
}
