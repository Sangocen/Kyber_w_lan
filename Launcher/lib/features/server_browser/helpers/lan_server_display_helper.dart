import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/kyber/models/maps.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';

class LanServerDisplayHelper {
  static String levelSubtitle(LevelSetup? levelSetup) {
    if (levelSetup == null) {
      return '';
    }

    final parts = <String>[
      if (levelSetup.modeName.isNotEmpty)
        levelSetup.modeName
      else if (levelSetup.mode.isNotEmpty)
        MapHelper.getMode(levelSetup.mode)?.name ?? levelSetup.mode,
      if (levelSetup.mapName.isNotEmpty)
        levelSetup.mapName
      else if (levelSetup.map.isNotEmpty)
        MapHelper.getMap(levelSetup.mode, levelSetup.map)?.name ??
            levelSetup.map,
    ];

    return parts.join(' | ').toUpperCase();
  }

  static String listEntrySubtitle(LanServer server) {
    final parts = <String>[
      if (levelSubtitle(server.levelSetup).isNotEmpty)
        levelSubtitle(server.levelSetup),
      if (server.gameplayMods.isNotEmpty)
        '${server.gameplayMods.length} required mod${server.gameplayMods.length == 1 ? '' : 's'}',
    ];

    return parts.join(' | ');
  }

  static Mode modeForServer(LanServer server) {
    final levelSetup = server.levelSetup;
    return modes
            .where((element) => element.mode == levelSetup?.mode)
            .firstOrNull ??
        Mode.customMode();
  }

  static Map<String, dynamic> mapForServer(LanServer server, Mode mode) {
    final levelSetup = server.levelSetup;
    if (levelSetup == null || mode.maps.isEmpty) {
      return maps.first;
    }

    return maps.singleWhere(
      (element) => element['map'] == levelSetup.map,
      orElse: () => maps.first,
    );
  }
}
