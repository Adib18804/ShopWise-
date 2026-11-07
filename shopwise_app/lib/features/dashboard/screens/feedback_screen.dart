import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/feedback_model.dart';
import '../../../providers/feedback_provider.dart';
import '../../../providers/language_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _category = 'Bug';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isBn) async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(feedbackSubmitProvider.notifier).submit(
          category: _category,
          message: _messageController.text,
        );
    if (!mounted) return;
    final result = ref.read(feedbackSubmitProvider);
    final error = result.hasError ? result.error.toString() : null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ??
          (isBn ? 'আপনার মতামত পাঠানো হয়েছে।' : 'Your feedback was sent.'),),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ),);
    if (error == null) _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(appLocalizationsProvider);
    final submitState = ref.watch(feedbackSubmitProvider);
    final feedbackState = ref.watch(myFeedbackProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.isBn ? 'সহায়তা ও মতামত' : 'Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.isBn ? 'আপনার মতামত জানান' : 'Send us feedback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: l.isBn ? 'বিষয়' : 'Category',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Bug',
                          child: Text(l.isBn ? 'সমস্যা' : 'Bug'),
                        ),
                        DropdownMenuItem(
                          value: 'Feature',
                          child: Text(l.isBn ? 'নতুন ফিচার' : 'Feature'),
                        ),
                        DropdownMenuItem(
                          value: 'Question',
                          child: Text(l.isBn ? 'প্রশ্ন' : 'Question'),
                        ),
                      ],
                      onChanged: submitState.isLoading
                          ? null
                          : (value) {
                              if (value != null) setState(() => _category = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageController,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 4000,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: l.isBn ? 'আপনার বার্তা' : 'Your message',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return l.isBn
                              ? 'বার্তা লিখুন'
                              : 'Please enter a message';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: submitState.isLoading
                          ? null
                          : () => _submit(l.isBn),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: submitState.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(l.isBn ? 'মতামত পাঠান' : 'Submit feedback'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l.isBn ? 'আমার মতামত' : 'My Feedback',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          feedbackState.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _InfoCard(
              icon: Icons.cloud_off_rounded,
              message: error.toString(),
              color: AppColors.error,
            ),
            data: (items) => items.isEmpty
                ? _InfoCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    message: l.isBn
                        ? 'এখনও কোনো মতামত পাঠানো হয়নি।'
                        : 'You have not sent any feedback yet.',
                    color: AppColors.primary,
                  )
                : Column(
                    children: items
                        .map((item) => _FeedbackCard(item: item, isBn: l.isBn))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item, required this.isBn});

  final FeedbackModel item;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    final resolved = item.status == 'Resolved';
    final category = switch (item.category) {
      'Bug' => isBn ? 'সমস্যা' : 'Bug',
      'Feature' => isBn ? 'নতুন ফিচার' : 'Feature',
      _ => isBn ? 'প্রশ্ন' : 'Question',
    };
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Tag(label: category, color: AppColors.primary),
                _Tag(
                  label: resolved
                      ? (isBn ? 'সমাধান হয়েছে' : 'Resolved')
                      : (isBn ? 'অপেক্ষমাণ' : 'Pending'),
                  color: resolved ? AppColors.success : AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.message),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (item.adminResponse.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                isBn ? 'ShopWise-এর উত্তর' : 'ShopWise response',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.adminResponse),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FeedbackModel>('item', item));
    properties.add(DiagnosticsProperty<bool>('isBn', isBn));
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(ColorProperty('color', color));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('message', message));
    properties.add(ColorProperty('color', color));
  }
}
