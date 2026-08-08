import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_server_helper.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/join_server_dialog.dart';
import 'package:kyber_launcher/features/server_browser/helpers/lan_server_browser_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_direct_connect_join_request.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/services/lan_discovery_service.dart';
import 'package:logging/logging.dart';

class LanDiscoveryState {
  const LanDiscoveryState({
    this.servers = const [],
    this.scanning = false,
    this.message,
    this.selectedServer,
    this.pendingLanJoin,
    this.pendingDirectConnect,
  });

  final List<LanServer> servers;
  final bool scanning;
  final String? message;
  final LanServer? selectedServer;
  final LanServer? pendingLanJoin;
  final LanDirectConnectJoinRequest? pendingDirectConnect;

  LanDiscoveryState copyWith({
    List<LanServer>? servers,
    bool? scanning,
    String? message,
    LanServer? selectedServer,
    bool clearSelectedServer = false,
    bool clearMessage = false,
    LanServer? pendingLanJoin,
    bool clearPendingLanJoin = false,
    LanDirectConnectJoinRequest? pendingDirectConnect,
    bool clearPendingDirectConnect = false,
  }) {
    return LanDiscoveryState(
      servers: servers ?? this.servers,
      scanning: scanning ?? this.scanning,
      message: clearMessage ? null : (message ?? this.message),
      selectedServer:
          clearSelectedServer ? null : selectedServer ?? this.selectedServer,
      pendingLanJoin:
          clearPendingLanJoin ? null : pendingLanJoin ?? this.pendingLanJoin,
      pendingDirectConnect: clearPendingDirectConnect
          ? null
          : pendingDirectConnect ?? this.pendingDirectConnect,
    );
  }
}

class LanDiscoveryCubit extends Cubit<LanDiscoveryState> {
  LanDiscoveryCubit(this._service) : super(const LanDiscoveryState()) {
    _subscription = _service.servers.listen(_upsertServer);
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _removeStaleServers(),
    );
    startScan();
  }

  final LanDiscoveryService _service;
  final _logger = Logger('lan_discovery_cubit');
  late final StreamSubscription<LanServer> _subscription;
  late final Timer _cleanupTimer;
  String? _localPreferredAddress;

  Future<void> startScan() async {
    emit(state.copyWith(scanning: true));
    try {
      await _refreshLocalPreferredAddress();
      await _service.startListening();
      emit(state.copyWith(scanning: false));
    } catch (e, stack) {
      _logger.severe('Failed to start LAN discovery', e, stack);
      emit(
        state.copyWith(
          scanning: false,
          message: 'Failed to start LAN discovery',
        ),
      );
    }
  }

  void refresh() {
    _removeStaleServers();
  }

  void selectServer(LanServer? server) {
    emit(
      state.copyWith(
        selectedServer: server,
        clearSelectedServer: server == null,
      ),
    );
  }

  void requestJoin(LanServer server) {
    final blockReason = LanServerBrowserHelper.joinBlockReason(server);
    if (blockReason != null) {
      emit(state.copyWith(message: blockReason));
      return;
    }

    emit(state.copyWith(pendingLanJoin: server));
  }

  void clearPendingLanJoin() {
    if (state.pendingLanJoin == null) {
      return;
    }
    emit(state.copyWith(clearPendingLanJoin: true));
  }

  void requestDirectConnect({
    required String ip,
    required int port,
    ModCollectionMetaData? baseCollection,
    bool spectator = false,
  }) {
    Preferences.general.lastDirectConnectIp = ip;
    Preferences.general.lastDirectConnectPort = port;
    Preferences.general.lastDirectConnectCollectionId = baseCollection?.localId;

    emit(
      state.copyWith(
        pendingDirectConnect: LanDirectConnectJoinRequest(
          ip: ip,
          port: port,
          baseCollection: baseCollection,
          spectator: spectator,
        ),
      ),
    );
  }

  void clearPendingDirectConnect() {
    if (state.pendingDirectConnect == null) {
      return;
    }
    emit(state.copyWith(clearPendingDirectConnect: true));
  }

  Future<void> completeLanJoin(
    LanServer server,
    JoinDialogResult result,
  ) async {
    try {
      await KyberServerHelper.joinLanServer(
        server,
        selectedCollection: result.collection,
        spectator: result.spectator,
      );
    } catch (e, stack) {
      _logger.severe('Failed to join LAN server', e, stack);
      emit(
        state.copyWith(message: 'Failed to join LAN server: $e'),
      );
    }
  }

  Future<void> completeDirectConnectJoin(
    LanDirectConnectJoinRequest request,
    JoinDialogResult result,
  ) async {
    try {
      await KyberServerHelper.joinByAddress(
        ip: request.ip,
        port: request.port,
        selectedCollection: LanServerBrowserHelper.resolveDirectConnectCollection(
          request.baseCollection,
          result,
        ),
        spectator: request.spectator || result.spectator,
      );
    } catch (e, stack) {
      _logger.severe('Failed to join LAN server by address', e, stack);
      emit(
        state.copyWith(message: 'Failed to join LAN server: $e'),
      );
    }
  }

  Future<void> _refreshLocalPreferredAddress() async {
    _localPreferredAddress =
        await LanDiscoveryService.getPreferredLanAddressFromModule();
  }

  void _upsertServer(LanServer server) {
    final servers = [...state.servers];
    LanServer? existingByName;
    for (final entry in servers) {
      if (entry.port == server.port && entry.name == server.name) {
        existingByName = entry;
        break;
      }
    }

    servers.removeWhere(
      (entry) => entry.port == server.port && entry.name == server.name,
    );

    final resolved = LanServerBrowserHelper.mergeDiscoveredServer(
      incoming: server,
      existingByName: existingByName,
      localPreferredAddress: _localPreferredAddress,
    );
    servers.add(resolved);

    servers.sort((a, b) => a.name.compareTo(b.name));
    final selectedServer = state.selectedServer?.id == resolved.id
        ? resolved
        : state.selectedServer;
    emit(
      state.copyWith(
        servers: servers,
        clearMessage: true,
        selectedServer: selectedServer,
      ),
    );
  }

  void _removeStaleServers() {
    unawaited(_refreshLocalPreferredAddress());

    final now = DateTime.now();
    final servers = state.servers
        .where(
          (server) =>
              now.difference(server.lastSeen) < LanDiscoveryService.staleAfter,
        )
        .toList();
    if (servers.length != state.servers.length) {
      emit(state.copyWith(servers: servers));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _cleanupTimer.cancel();
    await _service.stopListening();
    return super.close();
  }
}
