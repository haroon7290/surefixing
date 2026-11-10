import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../shell/shell.dart';
import '../technicians/tech_widgets.dart';
import '../tools/tool_widgets.dart';

class _Saved {
  final List<User> technicians;
  final List<Tool> tools;
  const _Saved(this.technicians, this.tools);
}

/// Technicians and tools the user saved with the heart button.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Saved',
        subtitle: 'Technicians and tools you want to find again.',
        body: ListenableBuilder(
          listenable: Session.instance,
          builder: (context, _) {
            final u = Session.instance.user;
            return AsyncView<_Saved>(
              // Reloads whenever a heart is toggled anywhere in the app.
              token: '${u?.favoriteTechnicians.length}|${u?.favoriteTools.length}',
              load: () async {
                final res = await Api.map('/api/users/me/favorites');
                return _Saved(asJsonList(res['technicians']).map(User.fromJson).toList(), asJsonList(res['tools']).map(Tool.fromJson).toList());
              },
              builder: (context, d) => d.technicians.isEmpty && d.tools.isEmpty
                  ? EmptyState(
                      icon: AppIcons.heart,
                      title: 'Nothing saved yet',
                      message: 'Tap the heart on a technician or a tool to keep it here.',
                      action: Btn('Find technicians', kind: BtnKind.dark, onPressed: () => openSection(context, 'technicians')),
                    )
                  : PageList(children: [
                      if (d.technicians.isNotEmpty) ...[
                        const SectionTitle('Technicians', top: 4),
                        AutoGrid(minWidth: 300, gap: 16, maxColumns: 3, children: [for (final t in d.technicians) TechCard(t, onTap: () => openTechnician(context, t.id))]),
                      ],
                      if (d.tools.isNotEmpty) ...[
                        SectionTitle('Tools', top: d.technicians.isEmpty ? 4 : 28),
                        AutoGrid(
                          minWidth: context.isWide ? 230 : 150,
                          gap: context.isWide ? 16 : 12,
                          maxColumns: 5,
                          itemHeight: context.isWide ? 300 : 248,
                          children: [for (final t in d.tools) ToolCard(t, onTap: () => openTool(context, t.id))],
                        ),
                      ],
                    ]),
            );
          },
        ),
      );
}
