// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String,
  text: json['text'] as String,
  timestamp: const TimestampConverter().fromJson(
    json['timestamp'] as Timestamp,
  ),
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'text': instance.text,
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
    };
