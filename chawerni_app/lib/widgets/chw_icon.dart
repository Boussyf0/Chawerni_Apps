import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Icônes Lucide (stroke 2, rond) — path data portée de `ui_kits/app/icons.jsx`.
/// On reconstruit le SVG à la volée pour garder le trait exact de Lucide plutôt
/// que d'approximer avec les Material Icons (qui sont pleines, pas tracées).
class ChwIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final bool mirrorInRtl; // chevrons / flèche d'envoi : miroir en RTL

  const ChwIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = C.midad,
    this.mirrorInRtl = false,
  });

  static const Map<String, String> _paths = {
    'message-circle': '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
    'book-open':
        '<path d="M12 7v14"/><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"/>',
    'file-text':
        '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
    'settings':
        '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
    'send': '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    'copy':
        '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    'x': '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    'search':
        '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'hand':
        '<path d="M18 11V6a2 2 0 0 0-4 0v5"/><path d="M14 10V4a2 2 0 0 0-4 0v2"/><path d="M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="m7 15-1.76-1.76a2 2 0 0 0-2.83 2.82l3.6 3.6A8 8 0 0 0 12 22h2a8 8 0 0 0 8-8V7a2 2 0 0 0-4 0v5"/>',
    'check': '<path d="M20 6 9 17l-5-5"/>',
    'chevron':
        '<path d="m9 18 6-6-6-6"/>', // chevron-right (miroir en RTL)
    'scales-off': '<path d="M12 3v18"/>', // placeholder, non utilisé
  };

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round">'
        '${_paths[name] ?? ''}</svg>';
    Widget icon = SvgPicture.string(svg, width: size, height: size);
    if (mirrorInRtl && Directionality.of(context) == TextDirection.rtl) {
      icon = Transform.flip(flipX: true, child: icon);
    }
    return icon;
  }
}
