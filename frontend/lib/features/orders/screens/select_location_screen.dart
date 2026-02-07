import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Select location: address field, "Choose on map" link, empty state or search results.
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];
  bool _searched = false;

  void _onSearch(String q) {
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _searched = true;
      _results = [
        'N-35 Itahari Dulari SundarHaraicha',
        'N-35 Birtamode, Deonia Garamani -04',
        'N-35 Bhadrapur Hwy sangam chowk',
      ].where((s) => s.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _chooseOnMap() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map selection — coming soon')));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightLavender,
      appBar: AppBar(
        title: const Text('Select location', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkGrey,
        foregroundColor: AppTheme.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Enter Address',
                prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.darkGrey),
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _chooseOnMap,
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 22, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text('Choose on map', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _results.isEmpty && _searched
                  ? const Center(child: Text('No results', style: TextStyle(color: Colors.grey)))
                  : _results.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final addr = _results[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AppTheme.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(addr, style: const TextStyle(color: AppTheme.darkGrey)),
                                onTap: () => Navigator.pop(context, addr),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
