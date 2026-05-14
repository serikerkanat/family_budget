import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../l10n/app_localizations.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategoryId;
  final TransactionType type;
  final Function(Category) onCategorySelected;
  final bool showLabel;

  const CategorySelector({
    Key? key,
    required this.selectedCategoryId,
    required this.type,
    required this.onCategorySelected,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = defaultCategories.where((cat) => cat.type == type).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            context.t('category'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedCategoryId;
              
              return GestureDetector(
                onTap: () => onCategorySelected(category),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category.icon,
                        color: isSelected 
                            ? Theme.of(context).primaryColor 
                            : Colors.grey[700],
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.categoryName(category.id),
                        style: TextStyle(
                          color: isSelected 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
