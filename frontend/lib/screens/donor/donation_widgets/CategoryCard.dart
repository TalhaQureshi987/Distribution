// lib/screens/donor/donation_widgets/CategoryCard.dart
import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryCard({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> categories = ['Food', 'Medicine', 'Clothes', 'Money'];
    final List<IconData> categoryIcons = [
      Icons.restaurant,
      Icons.medical_services,
      Icons.checkroom,
      Icons.attach_money,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Container(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category;
              final icon = categoryIcons[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => onCategorySelected(category),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.brown : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isSelected ? Colors.brown : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.brown.withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.brown,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}