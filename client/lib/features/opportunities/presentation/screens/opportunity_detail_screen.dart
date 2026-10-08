import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sports_z/features/opportunities/data/datasources/opportunities_api.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const _bgTop = AppColors.mustard900;
const _bgBottom = Color(0xFF120D02);
const _okColor = Color(0xFF5CD68A);
const _badColor = Color(0xFFFF8A80);

/// OP02: Opportunity detail.
/// [preview] list se aaya hua summary hai, taaki detail load hone tak
/// title/tags/deadline turant dikh jayein.
class OpportunityDetailScreen extends StatefulWidget {
  const OpportunityDetailScreen({
    super.key,
    required this.publicId,
    this.preview,
  });

  final String publicId;
  final Opportunity? preview;

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final _api = OpportunitiesApi();
  OpportunityDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _api.getById(widget.publicId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Text(
                        'Opportunity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final summary = _detail?.summary ?? widget.preview;

    // Summary bilkul nahi hai (seedha link se aaye) aur abhi load ho raha hai
    if (summary == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _ErrorBox(message: _error ?? 'Something went wrong.', onRetry: _load);
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.mustard800,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TopCard(item: summary),
          const SizedBox(height: 16),
          _InfoCard(item: summary),
          const SizedBox(height: 16),
          _Section(
            title: 'About',
            child: _sectionBody(_detail?.description),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Eligibility',
            child: _sectionBody(_detail?.eligibilitySummary),
          ),
        ],
      ),
    );
  }

  /// description / eligibility ka content: loading, error ya text.
  Widget _sectionBody(String? text) {
    if (_detail == null) {
      if (_loading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 3),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error ?? 'Could not load details.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final t = (text ?? '').trim();
    if (t.isEmpty) {
      return const Text(
        'Not provided yet.',
        style: TextStyle(color: Colors.white38, fontSize: 14),
      );
    }
    return Text(
      t,
      style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.5),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

IconData _sportIcon(String sport) {
  switch (sport) {
    case 'athletics':
      return Icons.directions_run;
    case 'wrestling':
      return Icons.sports_mma;
    case 'football':
      return Icons.sports_soccer;
    default:
      return Icons.emoji_events;
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.item});
  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final open = item.isOpen;
    final sub = [
      if (item.organizationName.isNotEmpty) item.organizationName,
      if (item.location.isNotEmpty) item.location,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.mustard500, AppColors.mustard700],
                  ),
                ),
                child: Icon(_sportIcon(item.sportId), color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: const TextStyle(color: Colors.white60, fontSize: 13.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Tag(text: _cap(item.type), color: AppColors.mustard300),
              const SizedBox(width: 8),
              _Tag(
                text: open ? 'Open' : 'Closed',
                color: open ? _okColor : _badColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item});
  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final deadline = item.deadline;
    final deadlineText = deadline == null ? 'No deadline' : formatDate(deadline);
    final deadlineLabel = item.isOpen ? 'Apply by' : 'Closed on';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.schedule,
            label: deadline == null ? 'Deadline' : deadlineLabel,
            value: deadlineText,
          ),
          _divider(),
          _InfoRow(
            icon: Icons.sports,
            label: 'Sport',
            value: _cap(item.sportId),
          ),
          if (item.location.isNotEmpty) ...[
            _divider(),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: item.location,
            ),
          ],
          if (item.organizationName.isNotEmpty) ...[
            _divider(),
            _InfoRow(
              icon: Icons.apartment,
              label: 'Organization',
              value: item.organizationName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.goldBright),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}