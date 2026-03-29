// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'problem_card.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProblemCard {

 String get id; String get ngoId; IssueType get issueType; String get locationWard; String get locationCity; SeverityLevel get severityLevel; int get affectedCount; String get description; double get confidenceScore; ProblemStatus get status; double get priorityScore; double get severityContrib; double get scaleContrib; double get recencyContrib; double get gapContrib;@TimestampConverter() DateTime get createdAt; bool get anonymized;
/// Create a copy of ProblemCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProblemCardCopyWith<ProblemCard> get copyWith => _$ProblemCardCopyWithImpl<ProblemCard>(this as ProblemCard, _$identity);

  /// Serializes this ProblemCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProblemCard&&(identical(other.id, id) || other.id == id)&&(identical(other.ngoId, ngoId) || other.ngoId == ngoId)&&(identical(other.issueType, issueType) || other.issueType == issueType)&&(identical(other.locationWard, locationWard) || other.locationWard == locationWard)&&(identical(other.locationCity, locationCity) || other.locationCity == locationCity)&&(identical(other.severityLevel, severityLevel) || other.severityLevel == severityLevel)&&(identical(other.affectedCount, affectedCount) || other.affectedCount == affectedCount)&&(identical(other.description, description) || other.description == description)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.status, status) || other.status == status)&&(identical(other.priorityScore, priorityScore) || other.priorityScore == priorityScore)&&(identical(other.severityContrib, severityContrib) || other.severityContrib == severityContrib)&&(identical(other.scaleContrib, scaleContrib) || other.scaleContrib == scaleContrib)&&(identical(other.recencyContrib, recencyContrib) || other.recencyContrib == recencyContrib)&&(identical(other.gapContrib, gapContrib) || other.gapContrib == gapContrib)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.anonymized, anonymized) || other.anonymized == anonymized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ngoId,issueType,locationWard,locationCity,severityLevel,affectedCount,description,confidenceScore,status,priorityScore,severityContrib,scaleContrib,recencyContrib,gapContrib,createdAt,anonymized);

@override
String toString() {
  return 'ProblemCard(id: $id, ngoId: $ngoId, issueType: $issueType, locationWard: $locationWard, locationCity: $locationCity, severityLevel: $severityLevel, affectedCount: $affectedCount, description: $description, confidenceScore: $confidenceScore, status: $status, priorityScore: $priorityScore, severityContrib: $severityContrib, scaleContrib: $scaleContrib, recencyContrib: $recencyContrib, gapContrib: $gapContrib, createdAt: $createdAt, anonymized: $anonymized)';
}


}

/// @nodoc
abstract mixin class $ProblemCardCopyWith<$Res>  {
  factory $ProblemCardCopyWith(ProblemCard value, $Res Function(ProblemCard) _then) = _$ProblemCardCopyWithImpl;
@useResult
$Res call({
 String id, String ngoId, IssueType issueType, String locationWard, String locationCity, SeverityLevel severityLevel, int affectedCount, String description, double confidenceScore, ProblemStatus status, double priorityScore, double severityContrib, double scaleContrib, double recencyContrib, double gapContrib,@TimestampConverter() DateTime createdAt, bool anonymized
});




}
/// @nodoc
class _$ProblemCardCopyWithImpl<$Res>
    implements $ProblemCardCopyWith<$Res> {
  _$ProblemCardCopyWithImpl(this._self, this._then);

  final ProblemCard _self;
  final $Res Function(ProblemCard) _then;

/// Create a copy of ProblemCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ngoId = null,Object? issueType = null,Object? locationWard = null,Object? locationCity = null,Object? severityLevel = null,Object? affectedCount = null,Object? description = null,Object? confidenceScore = null,Object? status = null,Object? priorityScore = null,Object? severityContrib = null,Object? scaleContrib = null,Object? recencyContrib = null,Object? gapContrib = null,Object? createdAt = null,Object? anonymized = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ngoId: null == ngoId ? _self.ngoId : ngoId // ignore: cast_nullable_to_non_nullable
as String,issueType: null == issueType ? _self.issueType : issueType // ignore: cast_nullable_to_non_nullable
as IssueType,locationWard: null == locationWard ? _self.locationWard : locationWard // ignore: cast_nullable_to_non_nullable
as String,locationCity: null == locationCity ? _self.locationCity : locationCity // ignore: cast_nullable_to_non_nullable
as String,severityLevel: null == severityLevel ? _self.severityLevel : severityLevel // ignore: cast_nullable_to_non_nullable
as SeverityLevel,affectedCount: null == affectedCount ? _self.affectedCount : affectedCount // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,confidenceScore: null == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProblemStatus,priorityScore: null == priorityScore ? _self.priorityScore : priorityScore // ignore: cast_nullable_to_non_nullable
as double,severityContrib: null == severityContrib ? _self.severityContrib : severityContrib // ignore: cast_nullable_to_non_nullable
as double,scaleContrib: null == scaleContrib ? _self.scaleContrib : scaleContrib // ignore: cast_nullable_to_non_nullable
as double,recencyContrib: null == recencyContrib ? _self.recencyContrib : recencyContrib // ignore: cast_nullable_to_non_nullable
as double,gapContrib: null == gapContrib ? _self.gapContrib : gapContrib // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,anonymized: null == anonymized ? _self.anonymized : anonymized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProblemCard].
extension ProblemCardPatterns on ProblemCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProblemCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProblemCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProblemCard value)  $default,){
final _that = this;
switch (_that) {
case _ProblemCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProblemCard value)?  $default,){
final _that = this;
switch (_that) {
case _ProblemCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ngoId,  IssueType issueType,  String locationWard,  String locationCity,  SeverityLevel severityLevel,  int affectedCount,  String description,  double confidenceScore,  ProblemStatus status,  double priorityScore,  double severityContrib,  double scaleContrib,  double recencyContrib,  double gapContrib, @TimestampConverter()  DateTime createdAt,  bool anonymized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProblemCard() when $default != null:
return $default(_that.id,_that.ngoId,_that.issueType,_that.locationWard,_that.locationCity,_that.severityLevel,_that.affectedCount,_that.description,_that.confidenceScore,_that.status,_that.priorityScore,_that.severityContrib,_that.scaleContrib,_that.recencyContrib,_that.gapContrib,_that.createdAt,_that.anonymized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ngoId,  IssueType issueType,  String locationWard,  String locationCity,  SeverityLevel severityLevel,  int affectedCount,  String description,  double confidenceScore,  ProblemStatus status,  double priorityScore,  double severityContrib,  double scaleContrib,  double recencyContrib,  double gapContrib, @TimestampConverter()  DateTime createdAt,  bool anonymized)  $default,) {final _that = this;
switch (_that) {
case _ProblemCard():
return $default(_that.id,_that.ngoId,_that.issueType,_that.locationWard,_that.locationCity,_that.severityLevel,_that.affectedCount,_that.description,_that.confidenceScore,_that.status,_that.priorityScore,_that.severityContrib,_that.scaleContrib,_that.recencyContrib,_that.gapContrib,_that.createdAt,_that.anonymized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ngoId,  IssueType issueType,  String locationWard,  String locationCity,  SeverityLevel severityLevel,  int affectedCount,  String description,  double confidenceScore,  ProblemStatus status,  double priorityScore,  double severityContrib,  double scaleContrib,  double recencyContrib,  double gapContrib, @TimestampConverter()  DateTime createdAt,  bool anonymized)?  $default,) {final _that = this;
switch (_that) {
case _ProblemCard() when $default != null:
return $default(_that.id,_that.ngoId,_that.issueType,_that.locationWard,_that.locationCity,_that.severityLevel,_that.affectedCount,_that.description,_that.confidenceScore,_that.status,_that.priorityScore,_that.severityContrib,_that.scaleContrib,_that.recencyContrib,_that.gapContrib,_that.createdAt,_that.anonymized);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProblemCard extends ProblemCard {
  const _ProblemCard({required this.id, required this.ngoId, required this.issueType, required this.locationWard, required this.locationCity, required this.severityLevel, required this.affectedCount, required this.description, required this.confidenceScore, required this.status, required this.priorityScore, required this.severityContrib, required this.scaleContrib, required this.recencyContrib, required this.gapContrib, @TimestampConverter() required this.createdAt, required this.anonymized}): super._();
  factory _ProblemCard.fromJson(Map<String, dynamic> json) => _$ProblemCardFromJson(json);

@override final  String id;
@override final  String ngoId;
@override final  IssueType issueType;
@override final  String locationWard;
@override final  String locationCity;
@override final  SeverityLevel severityLevel;
@override final  int affectedCount;
@override final  String description;
@override final  double confidenceScore;
@override final  ProblemStatus status;
@override final  double priorityScore;
@override final  double severityContrib;
@override final  double scaleContrib;
@override final  double recencyContrib;
@override final  double gapContrib;
@override@TimestampConverter() final  DateTime createdAt;
@override final  bool anonymized;

/// Create a copy of ProblemCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProblemCardCopyWith<_ProblemCard> get copyWith => __$ProblemCardCopyWithImpl<_ProblemCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProblemCardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProblemCard&&(identical(other.id, id) || other.id == id)&&(identical(other.ngoId, ngoId) || other.ngoId == ngoId)&&(identical(other.issueType, issueType) || other.issueType == issueType)&&(identical(other.locationWard, locationWard) || other.locationWard == locationWard)&&(identical(other.locationCity, locationCity) || other.locationCity == locationCity)&&(identical(other.severityLevel, severityLevel) || other.severityLevel == severityLevel)&&(identical(other.affectedCount, affectedCount) || other.affectedCount == affectedCount)&&(identical(other.description, description) || other.description == description)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.status, status) || other.status == status)&&(identical(other.priorityScore, priorityScore) || other.priorityScore == priorityScore)&&(identical(other.severityContrib, severityContrib) || other.severityContrib == severityContrib)&&(identical(other.scaleContrib, scaleContrib) || other.scaleContrib == scaleContrib)&&(identical(other.recencyContrib, recencyContrib) || other.recencyContrib == recencyContrib)&&(identical(other.gapContrib, gapContrib) || other.gapContrib == gapContrib)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.anonymized, anonymized) || other.anonymized == anonymized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ngoId,issueType,locationWard,locationCity,severityLevel,affectedCount,description,confidenceScore,status,priorityScore,severityContrib,scaleContrib,recencyContrib,gapContrib,createdAt,anonymized);

@override
String toString() {
  return 'ProblemCard(id: $id, ngoId: $ngoId, issueType: $issueType, locationWard: $locationWard, locationCity: $locationCity, severityLevel: $severityLevel, affectedCount: $affectedCount, description: $description, confidenceScore: $confidenceScore, status: $status, priorityScore: $priorityScore, severityContrib: $severityContrib, scaleContrib: $scaleContrib, recencyContrib: $recencyContrib, gapContrib: $gapContrib, createdAt: $createdAt, anonymized: $anonymized)';
}


}

/// @nodoc
abstract mixin class _$ProblemCardCopyWith<$Res> implements $ProblemCardCopyWith<$Res> {
  factory _$ProblemCardCopyWith(_ProblemCard value, $Res Function(_ProblemCard) _then) = __$ProblemCardCopyWithImpl;
@override @useResult
$Res call({
 String id, String ngoId, IssueType issueType, String locationWard, String locationCity, SeverityLevel severityLevel, int affectedCount, String description, double confidenceScore, ProblemStatus status, double priorityScore, double severityContrib, double scaleContrib, double recencyContrib, double gapContrib,@TimestampConverter() DateTime createdAt, bool anonymized
});




}
/// @nodoc
class __$ProblemCardCopyWithImpl<$Res>
    implements _$ProblemCardCopyWith<$Res> {
  __$ProblemCardCopyWithImpl(this._self, this._then);

  final _ProblemCard _self;
  final $Res Function(_ProblemCard) _then;

/// Create a copy of ProblemCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ngoId = null,Object? issueType = null,Object? locationWard = null,Object? locationCity = null,Object? severityLevel = null,Object? affectedCount = null,Object? description = null,Object? confidenceScore = null,Object? status = null,Object? priorityScore = null,Object? severityContrib = null,Object? scaleContrib = null,Object? recencyContrib = null,Object? gapContrib = null,Object? createdAt = null,Object? anonymized = null,}) {
  return _then(_ProblemCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ngoId: null == ngoId ? _self.ngoId : ngoId // ignore: cast_nullable_to_non_nullable
as String,issueType: null == issueType ? _self.issueType : issueType // ignore: cast_nullable_to_non_nullable
as IssueType,locationWard: null == locationWard ? _self.locationWard : locationWard // ignore: cast_nullable_to_non_nullable
as String,locationCity: null == locationCity ? _self.locationCity : locationCity // ignore: cast_nullable_to_non_nullable
as String,severityLevel: null == severityLevel ? _self.severityLevel : severityLevel // ignore: cast_nullable_to_non_nullable
as SeverityLevel,affectedCount: null == affectedCount ? _self.affectedCount : affectedCount // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,confidenceScore: null == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProblemStatus,priorityScore: null == priorityScore ? _self.priorityScore : priorityScore // ignore: cast_nullable_to_non_nullable
as double,severityContrib: null == severityContrib ? _self.severityContrib : severityContrib // ignore: cast_nullable_to_non_nullable
as double,scaleContrib: null == scaleContrib ? _self.scaleContrib : scaleContrib // ignore: cast_nullable_to_non_nullable
as double,recencyContrib: null == recencyContrib ? _self.recencyContrib : recencyContrib // ignore: cast_nullable_to_non_nullable
as double,gapContrib: null == gapContrib ? _self.gapContrib : gapContrib // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,anonymized: null == anonymized ? _self.anonymized : anonymized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
