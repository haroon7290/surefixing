import 'package:flutter/material.dart';

import '../../kit.dart';
import 'tool_form_screen.dart';

/// The supplier's inventory: every listed tool with stock and status.
class MyToolsScreen extends StatefulWidget {
  const MyToolsScreen({super.key});

  @override
  State<MyToolsScreen> createState() => _MyToolsScreenState();
}

class _MyToolsScreenState extends State<MyToolsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Tool>>>();

  Future<void> _edit([Tool? tool]) async {
    await push(context, ToolFormScreen(tool: tool));
    _view.currentState?.reload();
  }

  Future<void> _toggle(Tool tool, bool listed) async {
    try {
      await Api.patch('/api/tools/${tool.id}', {'available': listed});
      toast(listed ? '"${tool.name}" is listed again' : '"${tool.name}" is hidden from the market', kind: ToastKind.success);
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'My tools',
      subtitle: 'What you rent out and sell. Hide a tool any time without deleting it.',
      actions: [Btn(context.isWide ? 'Add a tool' : 'Add', icon: AppIcons.add, size: context.isWide ? BtnSize.md : BtnSize.sm, onPressed: _edit)],
      body: AsyncView<List<Tool>>(
        key: _view,
        load: () async => (await Api.list('/api/tools', query: {'mine': 1, 'limit': 100})).map(Tool.fromJson).toList(),
        events: Live.rentals,
        builder: (context, tools) => tools.isEmpty
            ? EmptyState(
                icon: AppIcons.tools,
                title: 'List your first tool',
                message: 'Add photos, a daily rate and a deposit. Customers can request it right away.',
                action: Btn('Add a tool', icon: AppIcons.add, onPressed: _edit),
              )
            : PageList(
                onRefresh: () => _view.currentState!.reload(),
                children: [
                  AutoGrid(minWidth: 340, gap: 12, maxColumns: 3, children: [
                    for (final t in tools)
                      Panel(
                        onTap: () => _edit(t),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(R.md),
                              child: SizedBox.square(dimension: 68, child: CoverImage(t.image, category: toolCategory(t.category), iconSize: 28)),
                            ),
                            Gap.w12,
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(t.name, style: context.text.titleSmall!.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Gap.h2,
                                Text('${money(t.rentPricePerDay)} /day  ·  ${toolCategory(t.category).label}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Gap.h6,
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  Pill(t.stock == 0 ? 'All out' : '${t.stock} in stock', tone: t.stock == 0 ? Tone.warning : Tone.success, dot: true),
                                  if (t.hasInstallments) const Pill('Sells monthly', icon: AppIcons.calendar),
                                  if (t.ratingCount > 0) Pill(t.rating.toStringAsFixed(1), icon: AppIcons.starFill, tone: Tone.warning),
                                ]),
                              ]),
                            ),
                          ]),
                          Gap.h12,
                          Divider(color: c.line),
                          Gap.h4,
                          Row(children: [
                            Expanded(child: Text(t.available ? 'Listed in the market' : 'Hidden from the market', style: context.text.bodySmall!.copyWith(color: c.body, fontWeight: FontWeight.w600))),
                            Text(plural(t.rentalsCount, 'rental'), style: context.text.bodySmall),
                            Gap.w8,
                            Switch(value: t.available, onChanged: (v) => _toggle(t, v)),
                          ]),
                        ]),
                      ),
                  ]),
                ],
              ),
      ),
    );
  }
}
