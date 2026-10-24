import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/category_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'category_form_screen.dart';

/// Categories list screen
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // Load categories on init
    Future.microtask(() => ref.read(categoryProvider.notifier).loadCategories());
  }

  Future<void> _handleRefresh() async {
    await ref.read(categoryProvider.notifier).refreshCategories();
  }

  Future<void> _handleDelete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ক্যাটাগরি ডিলিট করুন'),
        content: Text('আপনি কি "$name" ক্যাটাগরি ডিলিট করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('হ্যাঁ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(categoryProvider.notifier).deleteCategory(id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্যাটাগরি ডিলিট হয়েছে'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(categoryProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'ক্যাটাগরি ডিলিট করতে ব্যর্থ'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ক্যাটাগরি'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: categoryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryState.categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'কোন ক্যাটাগরি নেই',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'নতুন ক্যাটাগরি যোগ করুন',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categoryState.categories.length,
                    itemBuilder: (context, index) {
                      final category = categoryState.categories[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.category,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (category.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  category.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (category.productCount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${category.productCount} টি পণ্য',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () async {
                                  final result = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute<bool>(
                                      builder: (_) => CategoryFormScreen(
                                        category: category,
                                      ),
                                    ),
                                  );

                                  if (result == true) {
                                    _handleRefresh();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: AppColors.error,
                                onPressed: () =>
                                    _handleDelete(category.id, category.name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => const CategoryFormScreen(),
            ),
          );

          if (result == true) {
            _handleRefresh();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
