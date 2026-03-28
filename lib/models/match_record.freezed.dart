// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProofObject {

 List<String> get photoUrls; String get note;@TimestampConverter() DateTime get submittedAt;
/// Create a copy of ProofObject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProofObjectCopyWith<ProofObject> get copyWith => _$ProofObjectCopyWithImpl<ProofObject>(this as ProofObject, _$identity);

  /// Serializes this ProofObject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProofObject&&const DeepCollectionEquality().equals(other.photoUrls, photoUrls)&&(identical(other.note, note) || other.note == note)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(photoUrls),note,submittedAt);

@override
String toString() {
  return 'ProofObject(photoUrls: $photoUrls, note: $note, submittedAt: $submittedAt)';
}


}

/// @nodoc
abstract mixin class $ProofObjectCopyWith<$Res>  {
  factory $ProofObjectCopyWith(ProofObject value, $Res Function(ProofObject) _then) = _$ProofObjectCopyWithImpl;
@useResult
$Res call({
 List<String> photoUrls, String note,@TimestampConverter() DateTime submittedAt
});




}
/// @nodoc
class _$ProofObjectCopyWithImpl<$Res>
    implements $ProofObjectCopyWith<$Res> {
  _$ProofObjectCopyWithImpl(this._self, this._then);

  final ProofObject _self;
  final $Res Function(ProofObject) _then;

/// Create a copy of ProofObject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? photoUrls = null,Object? note = null,Object? submittedAt = null,}) {
  return _then(_self.copyWith(
photoUrls: null == photoUrls ? _self.photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ProofObject].
extension ProofObjectPatterns on ProofObject {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProofObject value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProofObject() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProofObject value)  $default,){
final _that = this;
switch (_that) {
case _ProofObject():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProofObject value)?  $default,){
final _that = this;
switch (_that) {
case _ProofObject() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> photoUrls,  String note, @TimestampConverter()  DateTime submittedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProofObject() when $default != null:
return $default(_that.photoUrls,_that.note,_that.submittedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> photoUrls,  String note, @TimestampConverter()  DateTime submittedAt)  $default,) {final _that = this;
switch (_that) {
case _ProofObject():
return $default(_that.photoUrls,_that.note,_that.submittedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> photoUrls,  String note, @TimestampConverter()  DateTime submittedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProofObject() when $default != null:
return $default(_that.photoUrls,_that.note,_that.submittedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProofObject implements ProofObject {
  const _ProofObject({required final  List<String> photoUrls, required this.note, @TimestampConverter() required this.submittedAt}): _photoUrls = photoUrls;
  factory _ProofObject.fromJson(Map<String, dynamic> json) => _$ProofObjectFromJson(json);

 final  List<String> _photoUrls;
@override List<String> get photoUrls {
  if (_photoUrls is EqualUnmodifiableListView) return _photoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photoUrls);
}

@override final  String note;
@override@TimestampConverter() final  DateTime submittedAt;

/// Create a copy of ProofObject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProofObjectCopyWith<_ProofObject> get copyWith => __$ProofObjectCopyWithImpl<_ProofObject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProofObjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProofObject&&const DeepCollectionEquality().equals(other._photoUrls, _photoUrls)&&(identical(other.note, note) || other.note == note)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_photoUrls),note,submittedAt);

@override
String toString() {
  return 'ProofObject(photoUrls: $photoUrls, note: $note, submittedAt: $submittedAt)';
}


}

/// @nodoc
abstract mixin class _$ProofObjectCopyWith<$Res> implements $ProofObjectCopyWith<$Res> {
  factory _$ProofObjectCopyWith(_ProofObject value, $Res Function(_ProofObject) _then) = __$ProofObjectCopyWithImpl;
@override @useResult
$Res call({
 List<String> photoUrls, String note,@TimestampConverter() DateTime submittedAt
});




}
/// @nodoc
class __$ProofObjectCopyWithImpl<$Res>
    implements _$ProofObjectCopyWith<$Res> {
  __$ProofObjectCopyWithImpl(this._self, this._then);

  final _ProofObject _self;
  final $Res Function(_ProofObject) _then;

/// Create a copy of ProofObject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? photoUrls = null,Object? note = null,Object? submittedAt = null,}) {
  return _then(_ProofObject(
photoUrls: null == photoUrls ? _self._photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$MatchRecord {

 String get id; String get taskId; String get volunteerId; double get matchScore; MatchStatus get status; String get missionBriefing; String get whatToBring; ProofObject? get proof; String? get adminReviewNote;@TimestampConverter() DateTime? get completedAt;
/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchRecordCopyWith<MatchRecord> get copyWith => _$MatchRecordCopyWithImpl<MatchRecord>(this as MatchRecord, _$identity);

  /// Serializes this MatchRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.volunteerId, volunteerId) || other.volunteerId == volunteerId)&&(identical(other.matchScore, matchScore) || other.matchScore == matchScore)&&(identical(other.status, status) || other.status == status)&&(identical(other.missionBriefing, missionBriefing) || other.missionBriefing == missionBriefing)&&(identical(other.whatToBring, whatToBring) || other.whatToBring == whatToBring)&&(identical(other.proof, proof) || other.proof == proof)&&(identical(other.adminReviewNote, adminReviewNote) || other.adminReviewNote == adminReviewNote)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,volunteerId,matchScore,status,missionBriefing,whatToBring,proof,adminReviewNote,completedAt);

@override
String toString() {
  return 'MatchRecord(id: $id, taskId: $taskId, volunteerId: $volunteerId, matchScore: $matchScore, status: $status, missionBriefing: $missionBriefing, whatToBring: $whatToBring, proof: $proof, adminReviewNote: $adminReviewNote, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $MatchRecordCopyWith<$Res>  {
  factory $MatchRecordCopyWith(MatchRecord value, $Res Function(MatchRecord) _then) = _$MatchRecordCopyWithImpl;
@useResult
$Res call({
 String id, String taskId, String volunteerId, double matchScore, MatchStatus status, String missionBriefing, String whatToBring, ProofObject? proof, String? adminReviewNote,@TimestampConverter() DateTime? completedAt
});


$ProofObjectCopyWith<$Res>? get proof;

}
/// @nodoc
class _$MatchRecordCopyWithImpl<$Res>
    implements $MatchRecordCopyWith<$Res> {
  _$MatchRecordCopyWithImpl(this._self, this._then);

  final MatchRecord _self;
  final $Res Function(MatchRecord) _then;

/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskId = null,Object? volunteerId = null,Object? matchScore = null,Object? status = null,Object? missionBriefing = null,Object? whatToBring = null,Object? proof = freezed,Object? adminReviewNote = freezed,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,volunteerId: null == volunteerId ? _self.volunteerId : volunteerId // ignore: cast_nullable_to_non_nullable
as String,matchScore: null == matchScore ? _self.matchScore : matchScore // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,missionBriefing: null == missionBriefing ? _self.missionBriefing : missionBriefing // ignore: cast_nullable_to_non_nullable
as String,whatToBring: null == whatToBring ? _self.whatToBring : whatToBring // ignore: cast_nullable_to_non_nullable
as String,proof: freezed == proof ? _self.proof : proof // ignore: cast_nullable_to_non_nullable
as ProofObject?,adminReviewNote: freezed == adminReviewNote ? _self.adminReviewNote : adminReviewNote // ignore: cast_nullable_to_non_nullable
as String?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProofObjectCopyWith<$Res>? get proof {
    if (_self.proof == null) {
    return null;
  }

  return $ProofObjectCopyWith<$Res>(_self.proof!, (value) {
    return _then(_self.copyWith(proof: value));
  });
}
}


/// Adds pattern-matching-related methods to [MatchRecord].
extension MatchRecordPatterns on MatchRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchRecord value)  $default,){
final _that = this;
switch (_that) {
case _MatchRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchRecord value)?  $default,){
final _that = this;
switch (_that) {
case _MatchRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String taskId,  String volunteerId,  double matchScore,  MatchStatus status,  String missionBriefing,  String whatToBring,  ProofObject? proof,  String? adminReviewNote, @TimestampConverter()  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchRecord() when $default != null:
return $default(_that.id,_that.taskId,_that.volunteerId,_that.matchScore,_that.status,_that.missionBriefing,_that.whatToBring,_that.proof,_that.adminReviewNote,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String taskId,  String volunteerId,  double matchScore,  MatchStatus status,  String missionBriefing,  String whatToBring,  ProofObject? proof,  String? adminReviewNote, @TimestampConverter()  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _MatchRecord():
return $default(_that.id,_that.taskId,_that.volunteerId,_that.matchScore,_that.status,_that.missionBriefing,_that.whatToBring,_that.proof,_that.adminReviewNote,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String taskId,  String volunteerId,  double matchScore,  MatchStatus status,  String missionBriefing,  String whatToBring,  ProofObject? proof,  String? adminReviewNote, @TimestampConverter()  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _MatchRecord() when $default != null:
return $default(_that.id,_that.taskId,_that.volunteerId,_that.matchScore,_that.status,_that.missionBriefing,_that.whatToBring,_that.proof,_that.adminReviewNote,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchRecord implements MatchRecord {
  const _MatchRecord({required this.id, required this.taskId, required this.volunteerId, required this.matchScore, required this.status, required this.missionBriefing, required this.whatToBring, this.proof, this.adminReviewNote, @TimestampConverter() this.completedAt});
  factory _MatchRecord.fromJson(Map<String, dynamic> json) => _$MatchRecordFromJson(json);

@override final  String id;
@override final  String taskId;
@override final  String volunteerId;
@override final  double matchScore;
@override final  MatchStatus status;
@override final  String missionBriefing;
@override final  String whatToBring;
@override final  ProofObject? proof;
@override final  String? adminReviewNote;
@override@TimestampConverter() final  DateTime? completedAt;

/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchRecordCopyWith<_MatchRecord> get copyWith => __$MatchRecordCopyWithImpl<_MatchRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.volunteerId, volunteerId) || other.volunteerId == volunteerId)&&(identical(other.matchScore, matchScore) || other.matchScore == matchScore)&&(identical(other.status, status) || other.status == status)&&(identical(other.missionBriefing, missionBriefing) || other.missionBriefing == missionBriefing)&&(identical(other.whatToBring, whatToBring) || other.whatToBring == whatToBring)&&(identical(other.proof, proof) || other.proof == proof)&&(identical(other.adminReviewNote, adminReviewNote) || other.adminReviewNote == adminReviewNote)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,volunteerId,matchScore,status,missionBriefing,whatToBring,proof,adminReviewNote,completedAt);

@override
String toString() {
  return 'MatchRecord(id: $id, taskId: $taskId, volunteerId: $volunteerId, matchScore: $matchScore, status: $status, missionBriefing: $missionBriefing, whatToBring: $whatToBring, proof: $proof, adminReviewNote: $adminReviewNote, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$MatchRecordCopyWith<$Res> implements $MatchRecordCopyWith<$Res> {
  factory _$MatchRecordCopyWith(_MatchRecord value, $Res Function(_MatchRecord) _then) = __$MatchRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String taskId, String volunteerId, double matchScore, MatchStatus status, String missionBriefing, String whatToBring, ProofObject? proof, String? adminReviewNote,@TimestampConverter() DateTime? completedAt
});


@override $ProofObjectCopyWith<$Res>? get proof;

}
/// @nodoc
class __$MatchRecordCopyWithImpl<$Res>
    implements _$MatchRecordCopyWith<$Res> {
  __$MatchRecordCopyWithImpl(this._self, this._then);

  final _MatchRecord _self;
  final $Res Function(_MatchRecord) _then;

/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskId = null,Object? volunteerId = null,Object? matchScore = null,Object? status = null,Object? missionBriefing = null,Object? whatToBring = null,Object? proof = freezed,Object? adminReviewNote = freezed,Object? completedAt = freezed,}) {
  return _then(_MatchRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,volunteerId: null == volunteerId ? _self.volunteerId : volunteerId // ignore: cast_nullable_to_non_nullable
as String,matchScore: null == matchScore ? _self.matchScore : matchScore // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,missionBriefing: null == missionBriefing ? _self.missionBriefing : missionBriefing // ignore: cast_nullable_to_non_nullable
as String,whatToBring: null == whatToBring ? _self.whatToBring : whatToBring // ignore: cast_nullable_to_non_nullable
as String,proof: freezed == proof ? _self.proof : proof // ignore: cast_nullable_to_non_nullable
as ProofObject?,adminReviewNote: freezed == adminReviewNote ? _self.adminReviewNote : adminReviewNote // ignore: cast_nullable_to_non_nullable
as String?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of MatchRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProofObjectCopyWith<$Res>? get proof {
    if (_self.proof == null) {
    return null;
  }

  return $ProofObjectCopyWith<$Res>(_self.proof!, (value) {
    return _then(_self.copyWith(proof: value));
  });
}
}

// dart format on
