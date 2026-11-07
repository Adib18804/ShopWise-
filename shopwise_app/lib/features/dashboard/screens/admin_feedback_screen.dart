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
    final response = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      isBn ? 'মতামতের উত্তর' : 'Reply to feedback',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.message.trim().isEmpty
                          ? (isBn ? 'বার্তা নেই' : 'No message provided')
                          : item.message.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: isBn ? 'উত্তর' : 'Response',
                        hintText:
                            isBn ? 'আপনার উত্তর লিখুন' : 'Write your response',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(isBn ? 'বাতিল' : 'Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(controller.text),
                            icon: const Icon(Icons.send_rounded),
                            label: Text(isBn ? 'পাঠান' : 'Send reply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();

    if (response == null || response.trim().isEmpty || !context.mounted) {
      return;
    }

    try {
      await ref.read(feedbackRepositoryProvider).resolve(
            feedbackId: item.id,
            response: response,
          );
      if (!context.mounted) return;
      _showMessage(
        context,
        isBn ? 'উত্তর পাঠানো হয়েছে।' : 'Reply sent.',
        isError: false,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _errorText(error, isBn), isError: true);
    }
  }

  Future<void> _markResolved(
    BuildContext context,
    WidgetRef ref,
    FeedbackModel item,
    bool isBn,
  ) async {
    try {
      await ref.read(feedbackRepositoryProvider).markResolved(item.id);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _errorText(error, isBn), isError: true);
    }
  }

  void _showMessage(BuildContext context, String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  String _errorText(Object error, bool isBn) {
    final details = error.toString().replaceFirst('Exception: ', '').trim();
    return '${isBn ? 'সমস্যা হয়েছে' : 'Something went wrong'}: $details';
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _ErrorState(
          message: _errorText(error, l.isBn),
          isBn: l.isBn,
          onRetry: () => ref.invalidate(isFirebaseAdminProvider),
        ),
        data: (isAdmin) {
          if (isAdmin != true) {
            return _AccessDeniedState(isBn: l.isBn);
          }

          return _feedbackContent(context, ref, l.isBn);
        },
      ),
    );
  }

  Widget _feedbackContent(BuildContext context, WidgetRef ref, bool isBn) {
    AsyncValue<List<FeedbackModel>> feedbackState;
    try {
      feedbackState = ref.watch(allFeedbackProvider);
    } catch (error) {
      return _ErrorState(
        message: _errorText(error, isBn),
        isBn: isBn,
        onRetry: () => ref.invalidate(allFeedbackProvider),
      );
    }

    return feedbackState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => _ErrorState(
        message: _errorText(error, isBn),
        isBn: isBn,
        onRetry: () => ref.invalidate(allFeedbackProvider),
      ),
      data: (items) {
        if (items.isEmpty) return _EmptyFeedbackState(isBn: isBn);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    isBn
                        ? 'ব্যবহারকারীদের মতামত দেখুন এবং উত্তর দিন।'
                        : 'Review user feedback and send a response.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                for (final item in items)
                  _FeedbackCard(
                    item: item,
                    isBn: isBn,
                    onReply: () => _reply(context, ref, item, isBn),
                    onResolve: () => _markResolved(
                      context,
                      ref,
                      item,
                      isBn,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.item,
    required this.isBn,
    required this.onReply,
    required this.onResolve,
  });

  final FeedbackModel item;
  final bool isBn;
  final VoidCallback onReply;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final userName = item.userName.trim().isEmpty
        ? (isBn ? 'নামহীন ব্যবহারকারী' : 'Unnamed user')
        : item.userName.trim();
    final category = _categoryLabel(item.category, isBn);
    final resolved = item.status.trim().toLowerCase() == 'resolved';
    final message = item.message.trim().isEmpty
        ? (isBn ? 'কোনো বার্তা দেওয়া হয়নি।' : 'No message provided.')
        : item.message.trim();
    final response = item.adminResponse.trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  userName,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                _StatusTag(label: category, color: AppColors.primary),
                _StatusTag(
                  label: resolved
                      ? (isBn ? 'সমাধান হয়েছে' : 'Resolved')
                      : (isBn ? 'অপেক্ষমাণ' : 'Pending'),
                  color: resolved ? AppColors.success : AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (item.userId.trim().isNotEmpty)
              Text(
                '${isBn ? 'ব্যবহারকারী' : 'User'}: ${item.userId.trim()}',
                maxLines: 1,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 12),
            Text(message, softWrap: true),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (response.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                '${isBn ? 'বর্তমান উত্তর' : 'Current response'}: $response',
                softWrap: true,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded),
                  label: Text(isBn ? 'উত্তর দিন' : 'Reply'),
                ),
                if (!resolved)
                  TextButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(isBn ? 'সমাধান হয়েছে' : 'Mark resolved'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String value, bool isBn) {
    switch (value.trim().toLowerCase()) {
      case 'bug':
        return isBn ? 'সমস্যা' : 'Bug';
      case 'feature':
        return isBn ? 'নতুন ফিচার' : 'Feature';
      case 'question':
        return isBn ? 'প্রশ্ন' : 'Question';
      default:
        return value.trim().isEmpty
            ? (isBn ? 'অন্যান্য' : 'Other')
            : value.trim();
    }
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
          label.trim().isEmpty ? '—' : label.trim(),
          maxLines: 1,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
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

class _EmptyFeedbackState extends StatelessWidget {
  const _EmptyFeedbackState({required this.isBn});

  final bool isBn;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mark_chat_read_outlined,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                isBn ? 'কোনো ফিডব্যাক নেই' : 'No feedback yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                isBn
                    ? 'নতুন মতামত এলে এখানে দেখা যাবে।'
                    : 'New feedback will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _AccessDeniedState extends StatelessWidget {
  const _AccessDeniedState({required this.isBn});

  final bool isBn;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isBn
                ? 'এই প্যানেল ব্যবহারের অনুমতি নেই।'
                : 'You do not have permission to use this panel.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.isBn,
    required this.onRetry,
  });

  final String message;
  final bool isBn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isBn ? 'আবার চেষ্টা করুন' : 'Try again'),
              ),
            ],
          ),
        ),
      );
}
