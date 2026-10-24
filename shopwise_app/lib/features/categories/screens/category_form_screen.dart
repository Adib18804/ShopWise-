import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/category_provider.dart';
import '../../../models/category_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/widgets/auth_text_field.dart';
import '../../../features/auth/widgets/auth_button.dart';

/// Category form screen (add/edit)
class CategoryFormScreen extends ConsumerStatefulWidget {
  final CategoryModel? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final success = isEditing
        ? await ref.read(categoryProvider.notifier).updateCategory(
              id: widget.category!.id,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            )
        : await ref.read(categoryProvider.notifier).createCategory(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(categoryProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'অপারেশন ব্যর্থ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'ক্যাটাগরি সম্পাদনা' : 'নতুন ক্যাটাগরি'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              AuthTextField(
                controller: _nameController,
                label: 'ক্যাটাগরির নাম *',
                hint: 'যেমন: খাবার, পানীয়',
                keyboardType: TextInputType.text,
                prefixIcon: const Icon(Icons.category),
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ক্যাটাগরির নাম প্রয়োজন';
                  }
                  if (value.trim().length < 2) {
                    return 'ক্যাটাগরির নাম কমপক্ষে ২ অক্ষর হতে হবে';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              AuthTextField(
                controller: _descriptionController,
                label: 'বিবরণ (ঐচ্ছিক)',
                hint: 'ক্যাটাগরি সম্পর্কে বিস্তারিত',
                keyboardType: TextInputType.multiline,
                prefixIcon: const Icon(Icons.description),
                enabled: !_isSubmitting,
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit button
              AuthButton(
                text: isEditing ? 'সংরক্ষণ করুন' : 'তৈরি করুন',
                onPressed: _handleSubmit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
