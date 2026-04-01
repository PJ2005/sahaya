// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskModel {

 String get id; String get problemCardId; TaskType get taskType; String get description; List<String> get skillTags; int get estimatedVolunteers; double get estimatedDurationHours; TaskStatus get status; List<String> get assignedVolunteerIds; String get locationWard;@OptionalGeoPointConverter() GeoPoint? get locationGeoPoint;
/// Create a copy of TaskModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskModelCopyWith<TaskModel> get copyWith => _$TaskModelCopyWithImpl<TaskModel>(this as TaskModel, _$identity);

  /// Serializes this TaskModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskModel&&(identical(other.id, id) || other.id == id)&&(identical(other.problemCardId, problemCardId) || other.problemCardId == problemCardId)&&(identical(other.taskType, taskType) || other.taskType == taskType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.skillTags, skillTags)&&(identical(other.estimatedVolunteers, estimatedVolunteers) || other.estimatedVolunteers == estimatedVolunteers)&&(identical(other.estimatedDurationHours, estimatedDurationHours) || other.estimatedDurationHours == estimatedDurationHours)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.assignedVolunteerIds, assignedVolunteerIds)&&(identical(other.locationWard, locationWard) || other.locationWard == locationWard)&&(identical(other.locationGeoPoint, locationGeoPoint) || other.locationGeoPoint == locationGeoPoint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,problemCardId,taskType,description,const DeepCollectionEquality().hash(skillTags),estimatedVolunteers,estimatedDurationHours,status,const DeepCollectionEquality().hash(assignedVolunteerIds),locationWard,locationGeoPoint);

@override
String toString() {
  return 'TaskModel(id: $id, problemCardId: $problemCardId, taskType: $taskType, description: $description, skillTags: $skillTags, estimatedVolunteers: $estimatedVolunteers, estimatedDurationHours: $estimatedDurationHours, status: $status, assignedVolunteerIds: $assignedVolunteerIds, locationWard: $locationWard, locationGeoPoint: $locationGeoPoint)';
}


}

/// @nodoc
abstract mixin class $TaskModelCopyWith<$Res>  {
  factory $TaskModelCopyWith(TaskModel value, $Res Function(TaskModel) _then) = _$TaskModelCopyWithImpl;
@useResult
$Res call({
 String id, String problemCardId, TaskType taskType, String description, List<String> skillTags, int estimatedVolunteers, double estimatedDurationHours, TaskStatus status, List<String> assignedVolunteerIds, String locationWard,@OptionalGeoPointConverter() GeoPoint? locationGeoPoint
});




}
/// @nodoc
class _$TaskModelCopyWithImpl<$Res>
    implements $TaskModelCopyWith<$Res> {
  _$TaskModelCopyWithImpl(this._self, this._then);

  final TaskModel _self;
  final $Res Function(TaskModel) _then;

/// Create a copy of TaskModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? problemCardId = null,Object? taskType = null,Object? description = null,Object? skillTags = null,Object? estimatedVolunteers = null,Object? estimatedDurationHours = null,Object? status = null,Object? assignedVolunteerIds = null,Object? locationWard = null,Object? locationGeoPoint = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,problemCardId: null == problemCardId ? _self.problemCardId : problemCardId // ignore: cast_nullable_to_non_nullable
as String,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as TaskType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,skillTags: null == skillTags ? _self.skillTags : skillTags // ignore: cast_nullable_to_non_nullable
as List<String>,estimatedVolunteers: null == estimatedVolunteers ? _self.estimatedVolunteers : estimatedVolunteers // ignore: cast_nullable_to_non_nullable
as int,estimatedDurationHours: null == estimatedDurationHours ? _self.estimatedDurationHours : estimatedDurationHours // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus,assignedVolunteerIds: null == assignedVolunteerIds ? _self.assignedVolunteerIds : assignedVolunteerIds // ignore: cast_nullable_to_non_nullable
as List<String>,locationWard: null == locationWard ? _self.locationWard : locationWard // ignore: cast_nullable_to_non_nullable
as String,locationGeoPoint: freezed == locationGeoPoint ? _self.locationGeoPoint : locationGeoPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskModel].
extension TaskModelPatterns on TaskModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskModel value)  $default,){
final _that = this;
switch (_that) {
case _TaskModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskModel value)?  $default,){
final _that = this;
switch (_that) {
case _TaskModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String problemCardId,  TaskType taskType,  String description,  List<String> skillTags,  int estimatedVolunteers,  double estimatedDurationHours,  TaskStatus status,  List<String> assignedVolunteerIds,  String locationWard, @OptionalGeoPointConverter()  GeoPoint? locationGeoPoint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskModel() when $default != null:
return $default(_that.id,_that.problemCardId,_that.taskType,_that.description,_that.skillTags,_that.estimatedVolunteers,_that.estimatedDurationHours,_that.status,_that.assignedVolunteerIds,_that.locationWard,_that.locationGeoPoint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String problemCardId,  TaskType taskType,  String description,  List<String> skillTags,  int estimatedVolunteers,  double estimatedDurationHours,  TaskStatus status,  List<String> assignedVolunteerIds,  String locationWard, @OptionalGeoPointConverter()  GeoPoint? locationGeoPoint)  $default,) {final _that = this;
switch (_that) {
case _TaskModel():
return $default(_that.id,_that.problemCardId,_that.taskType,_that.description,_that.skillTags,_that.estimatedVolunteers,_that.estimatedDurationHours,_that.status,_that.assignedVolunteerIds,_that.locationWard,_that.locationGeoPoint);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String problemCardId,  TaskType taskType,  String description,  List<String> skillTags,  int estimatedVolunteers,  double estimatedDurationHours,  TaskStatus status,  List<String> assignedVolunteerIds,  String locationWard, @OptionalGeoPointConverter()  GeoPoint? locationGeoPoint)?  $default,) {final _that = this;
switch (_that) {
case _TaskModel() when $default != null:
return $default(_that.id,_that.problemCardId,_that.taskType,_that.description,_that.skillTags,_that.estimatedVolunteers,_that.estimatedDurationHours,_that.status,_that.assignedVolunteerIds,_that.locationWard,_that.locationGeoPoint);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskModel extends TaskModel {
  const _TaskModel({required this.id, required this.problemCardId, required this.taskType, this.description = 'No description provided', required final  List<String> skillTags, required this.estimatedVolunteers, required this.estimatedDurationHours, required this.status, required final  List<String> assignedVolunteerIds, this.locationWard = 'Unknown Ward', @OptionalGeoPointConverter() this.locationGeoPoint}): _skillTags = skillTags,_assignedVolunteerIds = assignedVolunteerIds,super._();
  factory _TaskModel.fromJson(Map<String, dynamic> json) => _$TaskModelFromJson(json);

@override final  String id;
@override final  String problemCardId;
@override final  TaskType taskType;
@override@JsonKey() final  String description;
 final  List<String> _skillTags;
@override List<String> get skillTags {
  if (_skillTags is EqualUnmodifiableListView) return _skillTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skillTags);
}

@override final  int estimatedVolunteers;
@override final  double estimatedDurationHours;
@override final  TaskStatus status;
 final  List<String> _assignedVolunteerIds;
@override List<String> get assignedVolunteerIds {
  if (_assignedVolunteerIds is EqualUnmodifiableListView) return _assignedVolunteerIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assignedVolunteerIds);
}

@override@JsonKey() final  String locationWard;
@override@OptionalGeoPointConverter() final  GeoPoint? locationGeoPoint;

/// Create a copy of TaskModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskModelCopyWith<_TaskModel> get copyWith => __$TaskModelCopyWithImpl<_TaskModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskModel&&(identical(other.id, id) || other.id == id)&&(identical(other.problemCardId, problemCardId) || other.problemCardId == problemCardId)&&(identical(other.taskType, taskType) || other.taskType == taskType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._skillTags, _skillTags)&&(identical(other.estimatedVolunteers, estimatedVolunteers) || other.estimatedVolunteers == estimatedVolunteers)&&(identical(other.estimatedDurationHours, estimatedDurationHours) || other.estimatedDurationHours == estimatedDurationHours)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._assignedVolunteerIds, _assignedVolunteerIds)&&(identical(other.locationWard, locationWard) || other.locationWard == locationWard)&&(identical(other.locationGeoPoint, locationGeoPoint) || other.locationGeoPoint == locationGeoPoint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,problemCardId,taskType,description,const DeepCollectionEquality().hash(_skillTags),estimatedVolunteers,estimatedDurationHours,status,const DeepCollectionEquality().hash(_assignedVolunteerIds),locationWard,locationGeoPoint);

@override
String toString() {
  return 'TaskModel(id: $id, problemCardId: $problemCardId, taskType: $taskType, description: $description, skillTags: $skillTags, estimatedVolunteers: $estimatedVolunteers, estimatedDurationHours: $estimatedDurationHours, status: $status, assignedVolunteerIds: $assignedVolunteerIds, locationWard: $locationWard, locationGeoPoint: $locationGeoPoint)';
}


}

/// @nodoc
abstract mixin class _$TaskModelCopyWith<$Res> implements $TaskModelCopyWith<$Res> {
  factory _$TaskModelCopyWith(_TaskModel value, $Res Function(_TaskModel) _then) = __$TaskModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String problemCardId, TaskType taskType, String description, List<String> skillTags, int estimatedVolunteers, double estimatedDurationHours, TaskStatus status, List<String> assignedVolunteerIds, String locationWard,@OptionalGeoPointConverter() GeoPoint? locationGeoPoint
});




}
/// @nodoc
class __$TaskModelCopyWithImpl<$Res>
    implements _$TaskModelCopyWith<$Res> {
  __$TaskModelCopyWithImpl(this._self, this._then);

  final _TaskModel _self;
  final $Res Function(_TaskModel) _then;

/// Create a copy of TaskModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? problemCardId = null,Object? taskType = null,Object? description = null,Object? skillTags = null,Object? estimatedVolunteers = null,Object? estimatedDurationHours = null,Object? status = null,Object? assignedVolunteerIds = null,Object? locationWard = null,Object? locationGeoPoint = freezed,}) {
  return _then(_TaskModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,problemCardId: null == problemCardId ? _self.problemCardId : problemCardId // ignore: cast_nullable_to_non_nullable
as String,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as TaskType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,skillTags: null == skillTags ? _self._skillTags : skillTags // ignore: cast_nullable_to_non_nullable
as List<String>,estimatedVolunteers: null == estimatedVolunteers ? _self.estimatedVolunteers : estimatedVolunteers // ignore: cast_nullable_to_non_nullable
as int,estimatedDurationHours: null == estimatedDurationHours ? _self.estimatedDurationHours : estimatedDurationHours // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus,assignedVolunteerIds: null == assignedVolunteerIds ? _self._assignedVolunteerIds : assignedVolunteerIds // ignore: cast_nullable_to_non_nullable
as List<String>,locationWard: null == locationWard ? _self.locationWard : locationWard // ignore: cast_nullable_to_non_nullable
as String,locationGeoPoint: freezed == locationGeoPoint ? _self.locationGeoPoint : locationGeoPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint?,
  ));
}


}

// dart format on
