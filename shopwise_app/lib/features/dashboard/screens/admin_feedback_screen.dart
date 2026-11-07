import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/feedback_model.dart';
import '../../../providers/feedback_provider.dart';
import '../../../providers/language_provider.dart';

class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  Future<void> _reply(
    BuildContext context,
    WidgetRef ref,
    FeedbackModel item,
    bool isBn,
  ) async {
    final controller = TextEditingController(text: item.adminResponse);
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBn ? 'মতামতের উত্তর' : 'Reply to feedback'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 7,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: isBn ? 'উত্তর' : 'Response',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isBn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(isBn ? 'উত্তর পাঠান' : 'Send reply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (response == null || response.trim().isEmpty || !context.mounted) return;

    try {
      await ref.read(feedbackRepositoryProvider).resolve(
            feedbackId: item.id,
            response: response,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isBn ? 'উত্তর পাঠানো হয়েছে।' : 'Reply sent.'),
        backgroundColor: AppColors.success,
      ),);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.error,
      ),);
    }
  }

  Future<void> _markResolved(
    BuildContext context,
    WidgetRef ref,
    FeedbackModel item,
  ) async {
    try {
      await ref.read(feedbackRepositoryProvider).markResolved(item.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.error,
      ),);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(appLocalizationsProvider);
    final claim = ref.watch(isFirebaseAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.isBn ? 'অ্যাডমিন প্যানেল' : 'Admin Panel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: claim.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Text(l.isBn
                  ? 'এই প্যানেল ব্যবহারের অনুমতি নেই।'
                  : 'You do not have permission to use this panel.',),
            );
          }
          final feedback = ref.watch(allFeedbackProvider);
          return feedback.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Text(l.isBn
                        ? 'এখনও কোনো মতামত আসেনি।'
                        : 'There is no feedback yet.',),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final resolved = item.status == 'Resolved';
                      final category = switch (item.category) {
                        'Bug' => l.isBn ? 'সমস্যা' : 'Bug',
                        'Feature' => l.isBn ? 'নতুন ফিচার' : 'Feature',
                        _ => l.isBn ? 'প্রশ্ন' : 'Question',
                      };
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    item.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  _StatusTag(
                                    label: category,
                                    color: AppColors.primary,
                                  ),
                                  _StatusTag(
                                    label: resolved
                                        ? (l.isBn ? 'সমাধান হয়েছে' : 'Resolved')
                                        : (l.isBn ? 'অপেক্ষমাণ' : 'Pending'),
                                    color: resolved
                                        ? AppColors.success
                                        : AppColors.accent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l.isBn ? 'ব্যবহারকারী' : 'User'}: ${item.userId}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Text(item.message),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(item.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              if (item.adminResponse.isNotEmpty) ...[
                                const Divider(height: 20),
                                Text(
                                  '${l.isBn ? 'বর্তমান উত্তর' : 'Current response'}: ${item.adminResponse}',
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _reply(context, ref, item, l.isBn),
                                    icon: const Icon(Icons.reply_rounded),
                                    label: Text(l.isBn ? 'উত্তর দিন' : 'Reply'),
                                  ),
                                  if (!resolved)
                                    TextButton.icon(
                                      onPressed: () => _markResolved(
                                          context, ref, item,),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: Text(l.isBn
                                          ? 'সমাধান হয়েছে'
                                          : 'Mark resolved',),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

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
