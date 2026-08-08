import 'package:collection/collection.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/join_server_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/services/lan_discovery_service.dart';
import 'package:kyber_launcher/injection_container.dart';

class LanServerBrowserHelper {
  static bool hasInstalledMods(LanServer server) {
    if (server.gameplayMods.isEmpty) {
      return true;
    }

    return server.gameplayMods.every(
      (mod) => ModHelper.isInstalled(mod.name, mod.version, ignoreCorrupted: true),
    );
  }

  static bool canJoinServer({required LanServer server}) {
    return joinBlockReason(server) == null;
  }

  /// User-facing reason when [canJoinServer] is false; null when join is allowed.
  static String? joinBlockReason(LanServer server) {
    if (!hasInstalledMods(server)) {
      return 'Install the required gameplay mods before joining this server.';
    }

    if (!sl.isRegistered<MaximaGameInstance>()) {
      return null;
    }

    final gameInstance = sl.get<MaximaGameInstance>();
    final instanceGameplayMods = ModHelper.getGameplayMods(gameInstance.mods);

    if (instanceGameplayMods.isEmpty && server.gameplayMods.isNotEmpty ||
        server.gameplayMods.isEmpty && instanceGameplayMods.isNotEmpty) {
      return 'Your running game instance mods do not match this server.';
    }

    final mappedServerMods = server.gameplayMods.map((e) => e.key).toList();
    final mappedInstanceMods = instanceGameplayMods
        .map((e) => '${e.details.name}@${e.details.version}')
        .toList();
    if (!const ListEquality<String>().equals(
      mappedServerMods,
      mappedInstanceMods,
    )) {
      return 'Your running game instance mods do not match this server.';
    }

    return null;
  }

  static ModCollectionMetaData resolveDirectConnectCollection(
    ModCollectionMetaData? base,
    JoinDialogResult result,
  ) {
    if (result.collection.localId == 'no-mods') {
      return base ?? ModCollectionMetaData.noMods();
    }

    if (base == null) {
      return result.collection;
    }

    return base.copyWith(
      mods: [...base.mods, ...result.collection.mods],
    );
  }

  static int addressClassPriority(String ip) {
    if (ip.startsWith('192.168.')) {
      return 0;
    }

    if (ip.startsWith('10.')) {
      return 1;
    }

    final parts = ip.split('.');
    if (parts.length == 4) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first == 172 && second != null && second >= 16 && second <= 31) {
        return 2;
      }
    }

    return 3;
  }

  static bool isOnLocalSubnet(String address, String? localPreferredAddress) {
    final local = localPreferredAddress;
    if (local == null || local.isEmpty) {
      return false;
    }

    return LanDiscoveryService.sharesClassCSubnet(local, address);
  }

  static bool shouldPreferServer(
    LanServer candidate,
    LanServer existing, {
    required String? localPreferredAddress,
  }) {
    final candidateOnSubnet = isOnLocalSubnet(
      candidate.address,
      localPreferredAddress,
    );
    final existingOnSubnet = isOnLocalSubnet(
      existing.address,
      localPreferredAddress,
    );
    if (candidateOnSubnet != existingOnSubnet) {
      return candidateOnSubnet;
    }

    final candidatePriority = addressClassPriority(candidate.address);
    final existingPriority = addressClassPriority(existing.address);
    if (candidatePriority != existingPriority) {
      return candidatePriority < existingPriority;
    }

    return candidate.lastSeen.isAfter(existing.lastSeen);
  }

  static LanServer mergeDiscoveredServer({
    required LanServer incoming,
    required LanServer? existingByName,
    required String? localPreferredAddress,
  }) {
    final preferred = existingByName == null
        ? incoming
        : (shouldPreferServer(
                incoming,
                existingByName,
                localPreferredAddress: localPreferredAddress,
              )
              ? incoming
              : existingByName);

    return preferred.copyWith(
      lastSeen: incoming.lastSeen,
      gameplayMods: incoming.gameplayMods.isNotEmpty
          ? incoming.gameplayMods
          : preferred.gameplayMods,
      playerCount: incoming.playerCount ?? preferred.playerCount,
      maxPlayers: incoming.maxPlayers ?? preferred.maxPlayers,
      requiresPassword: incoming.requiresPassword,
      levelSetup: incoming.levelSetup ?? preferred.levelSetup,
      name: incoming.name,
      address: preferred.address,
      port: incoming.port,
    );
  }
}
