import 'package:kyber_collection/kyber_collection.dart';

class LanDirectConnectJoinRequest {
  const LanDirectConnectJoinRequest({
    required this.ip,
    required this.port,
    this.baseCollection,
    this.spectator = false,
  });

  final String ip;
  final int port;
  final ModCollectionMetaData? baseCollection;
  final bool spectator;
}
