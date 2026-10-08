import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/cards.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import 'tool_form_screen.dart';

class MyToolsScreen extends StatefulWidget {
  const MyToolsScreen({super.key});

  @override
  State<MyToolsScreen> createState() => _MyToolsScreenState();
}

class _MyToolsScreenState extends State<MyToolsScreen> {
  List<Tool>? _tools;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getList('/api/tools', query: {'mine': '1', 'limit': '100'});
      if (mounted) {
        setState(() {
          _tools = res.map(Tool.fromJson).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Tool? t]) async {
    final changed = await push<bool>(context, ToolFormScreen(toolId: t?.id));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _tools;
    return Scaffold(
      appBar: AppBar(title: Text('My tools${tools == null ? '' : ' (${tools.length})'}')),
      body: tools == null
          ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
          : RefreshIndicator(
              onRefresh: _load,
              child: tools.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.handyman_outlined,
                        title: 'List your first tool',
                        message: 'Add photos, a daily price and stock. Customers can rent or buy on installments.',
                        actionLabel: 'Add a tool',
                        onAction: () => _edit(),
                      ),
                    ])
                  : LayoutBuilder(
                      builder: (_, box) => GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: box.maxWidth > 900 ? 4 : (box.maxWidth > 600 ? 3 : 2),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: tools.length,
                        itemBuilder: (_, i) => ToolCard(
                          tool: tools[i],
                          onTap: () => _edit(tools[i]),
                          trailing:
                              Pill('${tools[i].stock} left', color: tools[i].stock > 0 ? context.palette.success : context.palette.danger),
                        ),
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-tool',
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add tool'),
      ),
    );
  }
}
