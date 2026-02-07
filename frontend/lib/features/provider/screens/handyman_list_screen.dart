import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/provider/widgets/provider_app_bar.dart';

/// Handyman List: grid of handyman profiles with online status, call/message/chat.
class HandymanListScreen extends StatelessWidget {
  const HandymanListScreen({super.key});

  static final List<Map<String, String>> _handymen = [
    {'name': 'John Doe'},
    {'name': 'Chrysta Ellis'},
    {'name': 'Jacky Sam'},
    {'name': 'Erica Mendiz'},
    {'name': 'Parsa Evana'},
    {'name': 'Brian Shaw'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Handyman List', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.customerPrimary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        shape: providerAppBarShape,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _handymen.length,
        itemBuilder: (context, index) {
          final h = _handymen[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
                      child: Text(
                        (h['name'] ?? 'H')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.customerPrimary),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.power, color: AppTheme.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      h['name']!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBtn(Icons.call),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.email),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.chat_bubble_outline),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _iconBtn(IconData icon) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.customerPrimary.withOpacity(0.15),
      child: Icon(icon, color: AppTheme.customerPrimary, size: 20),
    );
  }
}
