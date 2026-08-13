// lib/ui/widgets/substitute_sheet.dart
//
// Bottom sheet for "what can I use instead of X." Backed by the
// /api/ingredients/{name}/substitutes endpoint, cosine similarity over a
// nutrient-vector cache, not a hardcoded substitution table.

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../services/substitution_service.dart';

class SubstituteSheet extends StatefulWidget {
  final String ingredientName;

  const SubstituteSheet({super.key, required this.ingredientName});

  static Future<void> show(BuildContext context, String ingredientName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubstituteSheet(ingredientName: ingredientName),
    );
  }

  @override
  State<SubstituteSheet> createState() => _SubstituteSheetState();
}

class _SubstituteSheetState extends State<SubstituteSheet> {
  bool _loading = true;
  String? _error;
  List<SubstituteResult> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await SubstitutionService.instance.getSubstitutes(widget.ingredientName);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results == null) {
        _error = SubstitutionService.instance.lastError ?? 'Something went wrong.';
      } else if (results.isEmpty) {
        _error = SubstitutionService.instance.lastError ?? '"${widget.ingredientName}" isn\'t in the ingredient database yet.';
      } else {
        _results = results;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Substitutes for ${widget.ingredientName}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'Closest match by nutrient profile, not just "similar sounding."',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryLight),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryLight)),
                )
              else
                ..._results.map((r) => _buildRow(r, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(SubstituteResult r, bool isDark) {
    final pct = (r.similarity.clamp(0, 1) * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              r.name[0].toUpperCase() + r.name.substring(1),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text('$pct% match', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
        ],
      ),
    );
  }
}
