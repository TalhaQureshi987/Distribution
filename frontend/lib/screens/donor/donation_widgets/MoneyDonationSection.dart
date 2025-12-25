// lib/screens/donor/donation_widgets/MoneyDonationSection.dart
import 'package:flutter/material.dart';

class MoneyDonationSection extends StatelessWidget {
  final String selectedAmount;
  final TextEditingController customAmountController;
  final Function(String) onAmountSelected;

  const MoneyDonationSection({
    Key? key,
    required this.selectedAmount,
    required this.customAmountController,
    required this.onAmountSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> presetAmounts = ['1000 PKR', '2500 PKR', '5000 PKR', '10000 PKR', '25000 PKR'];

    return Column(
      children: [
        Text("Donation Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: presetAmounts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == presetAmounts.length) {
                      return _buildAmountOption('Custom', selectedAmount == 'Custom');
                    }
                    return _buildAmountOption(presetAmounts[index], selectedAmount == presetAmounts[index]);
                  },
                ),
                if (selectedAmount == 'Custom') ...[
                  const SizedBox(height: 10),
                  Text("Custom Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildCustomAmountInput(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountOption(String amount, bool isSelected) {
    return GestureDetector(
      onTap: () => onAmountSelected(amount),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.brown : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.brown : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            amount,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: amount == 'Custom' ? 14 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, color: Colors.brown, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: customAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: ' PKR',
                hintText: 'Enter amount',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}