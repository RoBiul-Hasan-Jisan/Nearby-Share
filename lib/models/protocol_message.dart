import 'dart:convert';
import 'dart:typed_data';

/// Tiny control protocol sent as Nearby "bytes" payloads next to the file payloads.
///
/// offer    sender -> receiver  {sender, files:[{name,size}]}
/// accept   receiver -> sender
/// reject   receiver -> sender
/// cancel   either side
/// complete receiver -> sender  {saved, failed}
enum MessageType { offer, accept, reject, cancel, complete }

class ProtocolMessage {
  const ProtocolMessage(this.type, this.transferId, [this.data = const {}]);

  final MessageType type;
  final String transferId;
  final Map<String, dynamic> data;

  Uint8List encode() => Uint8List.fromList(
        utf8.encode(jsonEncode({'v': 1, 't': type.name, 'id': transferId, 'd': data})),
      );

  static ProtocolMessage? decode(Uint8List? bytes) {
    if (bytes == null) return null;
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final type = MessageType.values.byName(map['t'] as String);
      final data = (map['d'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      return ProtocolMessage(type, map['id'] as String, data);
    } catch (_) {
      return null;
    }
  }
}
