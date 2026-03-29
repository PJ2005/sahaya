// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'volunteer_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VolunteerProfile {

 String get id; String get uid;@GeoPointConverter() GeoPoint get locationGeoPoint; double get radiusKm; List<String> get skillTags; String get languagePref; bool get availabilityWindowActive;@TimestampConverter() DateTime get availabilityUpdatedAt; String? get fcmToken;
/// Create a copy of VolunteerProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolunteerProfileCopyWith<VolunteerProfile> get copyWith => _$VolunteerProfileCopyWithImpl<VolunteerProfile>(this as VolunteerProfile, _$identity);

  /// Serializes this VolunteerProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolunteerProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.locationGeoPoint, locationGeoPoint) || other.locationGeoPoint == locationGeoPoint)&&(identical(other.radiusKm, radiusKm) || other.radiusKm == radiusKm)&&const DeepCollectionEquality().equals(other.skillTags, skillTags)&&(identical(other.languagePref, languagePref) || other.languagePref == languagePref)&&(identical(other.availabilityWindowActive, availabilityWindowActive) || other.availabilityWindowActive == availabilityWindowActive)&&(identical(other.availabilityUpdatedAt, availabilityUpdatedAt) || other.availabilityUpdatedAt == availabilityUpdatedAt)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,locationGeoPoint,radiusKm,const DeepCollectionEquality().hash(skillTags),languagePref,availabilityWindowActive,availabilityUpdatedAt,fcmToken);

@override
String toString() {
  return 'VolunteerProfile(id: $id, uid: $uid, locationGeoPoint: $locationGeoPoint, radiusKm: $radiusKm, skillTags: $skillTags, languagePref: $languagePref, availabilityWindowActive: $availabilityWindowActive, availabilityUpdatedAt: $availabilityUpdatedAt, fcmToken: $fcmToken)';
}


}

/// @nodoc
abstract mixin class $VolunteerProfileCopyWith<$Res>  {
  factory $VolunteerProfileCopyWith(VolunteerProfile value, $Res Function(VolunteerProfile) _then) = _$VolunteerProfileCopyWithImpl;
@useResult
$Res call({
 String id, String uid,@GeoPointConverter() GeoPoint locationGeoPoint, double radiusKm, List<String> skillTags, String languagePref, bool availabilityWindowActive,@TimestampConverter() DateTime availabilityUpdatedAt, String? fcmToken
});




}
/// @nodoc
class _$VolunteerProfileCopyWithImpl<$Res>
    implements $VolunteerProfileCopyWith<$Res> {
  _$VolunteerProfileCopyWithImpl(this._self, this._then);

  final VolunteerProfile _self;
  final $Res Function(VolunteerProfile) _then;

/// Create a copy of VolunteerProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uid = null,Object? locationGeoPoint = null,Object? radiusKm = null,Object? skillTags = null,Object? languagePref = null,Object? availabilityWindowActive = null,Object? availabilityUpdatedAt = null,Object? fcmToken = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,locationGeoPoint: null == locationGeoPoint ? _self.locationGeoPoint : locationGeoPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint,radiusKm: null == radiusKm ? _self.radiusKm : radiusKm // ignore: cast_nullable_to_non_nullable
as double,skillTags: null == skillTags ? _self.skillTags : skillTags // ignore: cast_nullable_to_non_nullable
as List<String>,languagePref: null == languagePref ? _self.languagePref : languagePref // ignore: cast_nullable_to_non_nullable
as String,availabilityWindowActive: null == availabilityWindowActive ? _self.availabilityWindowActive : availabilityWindowActive // ignore: cast_nullable_to_non_nullable
as bool,availabilityUpdatedAt: null == availabilityUpdatedAt ? _self.availabilityUpdatedAt : availabilityUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VolunteerProfile].
extension VolunteerProfilePatterns on VolunteerProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolunteerProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolunteerProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolunteerProfile value)  $default,){
final _that = this;
switch (_that) {
case _VolunteerProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolunteerProfile value)?  $default,){
final _that = this;
switch (_that) {
case _VolunteerProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String uid, @GeoPointConverter()  GeoPoint locationGeoPoint,  double radiusKm,  List<String> skillTags,  String languagePref,  bool availabilityWindowActive, @TimestampConverter()  DateTime availabilityUpdatedAt,  String? fcmToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolunteerProfile() when $default != null:
return $default(_that.id,_that.uid,_that.locationGeoPoint,_that.radiusKm,_that.skillTags,_that.languagePref,_that.availabilityWindowActive,_that.availabilityUpdatedAt,_that.fcmToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String uid, @GeoPointConverter()  GeoPoint locationGeoPoint,  double radiusKm,  List<String> skillTags,  String languagePref,  bool availabilityWindowActive, @TimestampConverter()  DateTime availabilityUpdatedAt,  String? fcmToken)  $default,) {final _that = this;
switch (_that) {
case _VolunteerProfile():
return $default(_that.id,_that.uid,_that.locationGeoPoint,_that.radiusKm,_that.skillTags,_that.languagePref,_that.availabilityWindowActive,_that.availabilityUpdatedAt,_that.fcmToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String uid, @GeoPointConverter()  GeoPoint locationGeoPoint,  double radiusKm,  List<String> skillTags,  String languagePref,  bool availabilityWindowActive, @TimestampConverter()  DateTime availabilityUpdatedAt,  String? fcmToken)?  $default,) {final _that = this;
switch (_that) {
case _VolunteerProfile() when $default != null:
return $default(_that.id,_that.uid,_that.locationGeoPoint,_that.radiusKm,_that.skillTags,_that.languagePref,_that.availabilityWindowActive,_that.availabilityUpdatedAt,_that.fcmToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolunteerProfile extends VolunteerProfile {
  const _VolunteerProfile({required this.id, required this.uid, @GeoPointConverter() required this.locationGeoPoint, required this.radiusKm, required final  List<String> skillTags, required this.languagePref, required this.availabilityWindowActive, @TimestampConverter() required this.availabilityUpdatedAt, this.fcmToken}): _skillTags = skillTags,super._();
  factory _VolunteerProfile.fromJson(Map<String, dynamic> json) => _$VolunteerProfileFromJson(json);

@override final  String id;
@override final  String uid;
@override@GeoPointConverter() final  GeoPoint locationGeoPoint;
@override final  double radiusKm;
 final  List<String> _skillTags;
@override List<String> get skillTags {
  if (_skillTags is EqualUnmodifiableListView) return _skillTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skillTags);
}

@override final  String languagePref;
@override final  bool availabilityWindowActive;
@override@TimestampConverter() final  DateTime availabilityUpdatedAt;
@override final  String? fcmToken;

/// Create a copy of VolunteerProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolunteerProfileCopyWith<_VolunteerProfile> get copyWith => __$VolunteerProfileCopyWithImpl<_VolunteerProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolunteerProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolunteerProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.locationGeoPoint, locationGeoPoint) || other.locationGeoPoint == locationGeoPoint)&&(identical(other.radiusKm, radiusKm) || other.radiusKm == radiusKm)&&const DeepCollectionEquality().equals(other._skillTags, _skillTags)&&(identical(other.languagePref, languagePref) || other.languagePref == languagePref)&&(identical(other.availabilityWindowActive, availabilityWindowActive) || other.availabilityWindowActive == availabilityWindowActive)&&(identical(other.availabilityUpdatedAt, availabilityUpdatedAt) || other.availabilityUpdatedAt == availabilityUpdatedAt)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,locationGeoPoint,radiusKm,const DeepCollectionEquality().hash(_skillTags),languagePref,availabilityWindowActive,availabilityUpdatedAt,fcmToken);

@override
String toString() {
  return 'VolunteerProfile(id: $id, uid: $uid, locationGeoPoint: $locationGeoPoint, radiusKm: $radiusKm, skillTags: $skillTags, languagePref: $languagePref, availabilityWindowActive: $availabilityWindowActive, availabilityUpdatedAt: $availabilityUpdatedAt, fcmToken: $fcmToken)';
}


}

/// @nodoc
abstract mixin class _$VolunteerProfileCopyWith<$Res> implements $VolunteerProfileCopyWith<$Res> {
  factory _$VolunteerProfileCopyWith(_VolunteerProfile value, $Res Function(_VolunteerProfile) _then) = __$VolunteerProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String uid,@GeoPointConverter() GeoPoint locationGeoPoint, double radiusKm, List<String> skillTags, String languagePref, bool availabilityWindowActive,@TimestampConverter() DateTime availabilityUpdatedAt, String? fcmToken
});




}
/// @nodoc
class __$VolunteerProfileCopyWithImpl<$Res>
    implements _$VolunteerProfileCopyWith<$Res> {
  __$VolunteerProfileCopyWithImpl(this._self, this._then);

  final _VolunteerProfile _self;
  final $Res Function(_VolunteerProfile) _then;

/// Create a copy of VolunteerProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uid = null,Object? locationGeoPoint = null,Object? radiusKm = null,Object? skillTags = null,Object? languagePref = null,Object? availabilityWindowActive = null,Object? availabilityUpdatedAt = null,Object? fcmToken = freezed,}) {
  return _then(_VolunteerProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,locationGeoPoint: null == locationGeoPoint ? _self.locationGeoPoint : locationGeoPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint,radiusKm: null == radiusKm ? _self.radiusKm : radiusKm // ignore: cast_nullable_to_non_nullable
as double,skillTags: null == skillTags ? _self._skillTags : skillTags // ignore: cast_nullable_to_non_nullable
as List<String>,languagePref: null == languagePref ? _self.languagePref : languagePref // ignore: cast_nullable_to_non_nullable
as String,availabilityWindowActive: null == availabilityWindowActive ? _self.availabilityWindowActive : availabilityWindowActive // ignore: cast_nullable_to_non_nullable
as bool,availabilityUpdatedAt: null == availabilityUpdatedAt ? _self.availabilityUpdatedAt : availabilityUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
