
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'corporate_pay_body.freezed.dart';
part 'corporate_pay_body.g.dart';

@freezed
class CorporatePayBody with _$CorporatePayBody {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CorporatePayBody({
    required int boxId,
    required int amount,
    required int customerCorporateAccountId,

  }) = _CorporatePayBody;

  factory CorporatePayBody.fromJson(Map<String, dynamic> json) => _$CorporatePayBodyFromJson(json);
}
