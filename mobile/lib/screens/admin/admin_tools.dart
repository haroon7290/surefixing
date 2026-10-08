import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/async_list.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../widgets/states.dart';
import '../shared/tool_detail_screen.dart';

/// Tool listing moderation (admin).
class AdminTools extends StatefulWidget {
  const AdminTools({super.key});

  @override
  State<AdminTools> createState() => _AdminToolsState();
}

class _AdminToolsState extends State<AdminTools> {
  final _list = GlobalKey<AsyncListState<Tool>>();

  Future<void> _remove(Tool t) async {
    final ok = await confirmDialog(context,
        title: 'Remove ${t.name}?',
        message: 'The listing is deleted and pending requests are cancelled.',
        confirm: 'Remove',
        destructive: true);
    if (!ok) return;
    try {
      await ApiClient.delete('/api/tools/${t.id}');
      toast('Listing removed');
      _list.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All tools')),
      body: AsyncList<Tool>(
        key: _list,
        load: () async => (await ApiClient.getList('/api/admin/tools')).map(Tool.fromJson).toList(),
        empty: const EmptyState(icon: Icons.handyman_outlined, title: 'No tools listed'),
        spacing: 8,
        itemBuilder: (c, t, _) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetImage(t.coverImage, width: 48, height: 48, placeholder: Catalog.tool(t.category))),
            title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${t.supplier.name} · ${Fmt.money(t.rentPricePerDay)}/day · ${t.stock} in stock'),
            trailing: IconButton(icon: Icon(Icons.delete_outline_rounded, color: c.palette.danger), onPressed: () => _remove(t)),
            onTap: () => push(c, ToolDetailScreen(toolId: t.id)),
          ),
        ),
      ),
    );
  }
}
