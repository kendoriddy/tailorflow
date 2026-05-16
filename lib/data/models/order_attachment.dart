import 'dart:convert';
import 'dart:typed_data';

class OrderAttachment {
  const OrderAttachment({
    required this.id,
    required this.orderId,
    required this.imageBase64,
    required this.mimeType,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String imageBase64;
  final String mimeType;
  final DateTime createdAt;

  Uint8List? get imageBytes {
    try {
      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }
}

class NewOrderAttachmentInput {
  const NewOrderAttachmentInput({
    required this.imageBase64,
    required this.mimeType,
  });

  final String imageBase64;
  final String mimeType;
}
