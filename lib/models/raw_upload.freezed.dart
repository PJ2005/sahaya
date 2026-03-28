// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'raw_upload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RawUpload {

 String get id; String get ngoId; String get cloudinaryUrl; String get cloudinaryPublicId; String get fileType;@TimestampConverter() DateTime get uploadedAt; UploadStatus get status;
/// Create a copy of RawUpload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RawUploadCopyWith<RawUpload> get copyWith => _$RawUploadCopyWithImpl<RawUpload>(this as RawUpload, _$identity);

  /// Serializes this RawUpload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RawUpload&&(identical(other.id, id) || other.id == id)&&(identical(other.ngoId, ngoId) || other.ngoId == ngoId)&&(identical(other.cloudinaryUrl, cloudinaryUrl) || other.cloudinaryUrl == cloudinaryUrl)&&(identical(other.cloudinaryPublicId, cloudinaryPublicId) || other.cloudinaryPublicId == cloudinaryPublicId)&&(identical(other.fileType, fileType) || other.fileType == fileType)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ngoId,cloudinaryUrl,cloudinaryPublicId,fileType,uploadedAt,status);

@override
String toString() {
  return 'RawUpload(id: $id, ngoId: $ngoId, cloudinaryUrl: $cloudinaryUrl, cloudinaryPublicId: $cloudinaryPublicId, fileType: $fileType, uploadedAt: $uploadedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $RawUploadCopyWith<$Res>  {
  factory $RawUploadCopyWith(RawUpload value, $Res Function(RawUpload) _then) = _$RawUploadCopyWithImpl;
@useResult
$Res call({
 String id, String ngoId, String cloudinaryUrl, String cloudinaryPublicId, String fileType,@TimestampConverter() DateTime uploadedAt, UploadStatus status
});




}
/// @nodoc
class _$RawUploadCopyWithImpl<$Res>
    implements $RawUploadCopyWith<$Res> {
  _$RawUploadCopyWithImpl(this._self, this._then);

  final RawUpload _self;
  final $Res Function(RawUpload) _then;

/// Create a copy of RawUpload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ngoId = null,Object? cloudinaryUrl = null,Object? cloudinaryPublicId = null,Object? fileType = null,Object? uploadedAt = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ngoId: null == ngoId ? _self.ngoId : ngoId // ignore: cast_nullable_to_non_nullable
as String,cloudinaryUrl: null == cloudinaryUrl ? _self.cloudinaryUrl : cloudinaryUrl // ignore: cast_nullable_to_non_nullable
as String,cloudinaryPublicId: null == cloudinaryPublicId ? _self.cloudinaryPublicId : cloudinaryPublicId // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as UploadStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [RawUpload].
extension RawUploadPatterns on RawUpload {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RawUpload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RawUpload() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RawUpload value)  $default,){
final _that = this;
switch (_that) {
case _RawUpload():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RawUpload value)?  $default,){
final _that = this;
switch (_that) {
case _RawUpload() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ngoId,  String cloudinaryUrl,  String cloudinaryPublicId,  String fileType, @TimestampConverter()  DateTime uploadedAt,  UploadStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RawUpload() when $default != null:
return $default(_that.id,_that.ngoId,_that.cloudinaryUrl,_that.cloudinaryPublicId,_that.fileType,_that.uploadedAt,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ngoId,  String cloudinaryUrl,  String cloudinaryPublicId,  String fileType, @TimestampConverter()  DateTime uploadedAt,  UploadStatus status)  $default,) {final _that = this;
switch (_that) {
case _RawUpload():
return $default(_that.id,_that.ngoId,_that.cloudinaryUrl,_that.cloudinaryPublicId,_that.fileType,_that.uploadedAt,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ngoId,  String cloudinaryUrl,  String cloudinaryPublicId,  String fileType, @TimestampConverter()  DateTime uploadedAt,  UploadStatus status)?  $default,) {final _that = this;
switch (_that) {
case _RawUpload() when $default != null:
return $default(_that.id,_that.ngoId,_that.cloudinaryUrl,_that.cloudinaryPublicId,_that.fileType,_that.uploadedAt,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RawUpload implements RawUpload {
  const _RawUpload({required this.id, required this.ngoId, required this.cloudinaryUrl, required this.cloudinaryPublicId, required this.fileType, @TimestampConverter() required this.uploadedAt, required this.status});
  factory _RawUpload.fromJson(Map<String, dynamic> json) => _$RawUploadFromJson(json);

@override final  String id;
@override final  String ngoId;
@override final  String cloudinaryUrl;
@override final  String cloudinaryPublicId;
@override final  String fileType;
@override@TimestampConverter() final  DateTime uploadedAt;
@override final  UploadStatus status;

/// Create a copy of RawUpload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RawUploadCopyWith<_RawUpload> get copyWith => __$RawUploadCopyWithImpl<_RawUpload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RawUploadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RawUpload&&(identical(other.id, id) || other.id == id)&&(identical(other.ngoId, ngoId) || other.ngoId == ngoId)&&(identical(other.cloudinaryUrl, cloudinaryUrl) || other.cloudinaryUrl == cloudinaryUrl)&&(identical(other.cloudinaryPublicId, cloudinaryPublicId) || other.cloudinaryPublicId == cloudinaryPublicId)&&(identical(other.fileType, fileType) || other.fileType == fileType)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ngoId,cloudinaryUrl,cloudinaryPublicId,fileType,uploadedAt,status);

@override
String toString() {
  return 'RawUpload(id: $id, ngoId: $ngoId, cloudinaryUrl: $cloudinaryUrl, cloudinaryPublicId: $cloudinaryPublicId, fileType: $fileType, uploadedAt: $uploadedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class _$RawUploadCopyWith<$Res> implements $RawUploadCopyWith<$Res> {
  factory _$RawUploadCopyWith(_RawUpload value, $Res Function(_RawUpload) _then) = __$RawUploadCopyWithImpl;
@override @useResult
$Res call({
 String id, String ngoId, String cloudinaryUrl, String cloudinaryPublicId, String fileType,@TimestampConverter() DateTime uploadedAt, UploadStatus status
});




}
/// @nodoc
class __$RawUploadCopyWithImpl<$Res>
    implements _$RawUploadCopyWith<$Res> {
  __$RawUploadCopyWithImpl(this._self, this._then);

  final _RawUpload _self;
  final $Res Function(_RawUpload) _then;

/// Create a copy of RawUpload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ngoId = null,Object? cloudinaryUrl = null,Object? cloudinaryPublicId = null,Object? fileType = null,Object? uploadedAt = null,Object? status = null,}) {
  return _then(_RawUpload(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ngoId: null == ngoId ? _self.ngoId : ngoId // ignore: cast_nullable_to_non_nullable
as String,cloudinaryUrl: null == cloudinaryUrl ? _self.cloudinaryUrl : cloudinaryUrl // ignore: cast_nullable_to_non_nullable
as String,cloudinaryPublicId: null == cloudinaryPublicId ? _self.cloudinaryPublicId : cloudinaryPublicId // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as UploadStatus,
  ));
}


}

// dart format on
