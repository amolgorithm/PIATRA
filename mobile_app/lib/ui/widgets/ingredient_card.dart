import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../../core/constants/theme/app_theme.dart';

class IngredientCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const IngredientCard({super.key, required this.item, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onEdit,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildIcon(),
          title: Text(
            item.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Quantity: ${item.quantity}'),
              if (item.expiryDate != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _getExpiryIcon(),
                      size: 14,
                      color: _getExpiryColor(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: ${_formatDate(item.expiryDate!)}',
                      style: TextStyle(
                        color: _getExpiryColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expiry / status chip
              _buildStatusChip(),
              const SizedBox(width: 8),
              // Low stock indicator
              if (item.isLowStock())
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Low',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Overflow menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    if (onEdit != null) onEdit!();
                  } else if (value == 'delete') {
                    if (onDelete != null) onDelete!();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    switch (item.category.toLowerCase()) {
      case 'vegetables':
        icon = Icons.eco;
        break;
      case 'dairy':
        icon = Icons.local_drink;
        break;
      case 'meat':
        icon = Icons.food_bank;
        break;
      case 'fruits':
        icon = Icons.apple;
        break;
      default:
        icon = Icons.fastfood;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: AppTheme.primaryGreen,
        size: 28,
      ),
    );
  }

  Widget _buildStatusChip() {
    if (item.expiryDate == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getExpiryColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        item.expiryStatus,
        style: TextStyle(
          color: _getExpiryColor(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getExpiryIcon() {
    if (item.isExpired) return Icons.error;
    if (item.isExpiringSoon) return Icons.warning;
    return Icons.check_circle;
  }

  Color _getExpiryColor() {
    if (item.isExpired) return AppTheme.errorRed;
    if (item.isExpiringSoon) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}