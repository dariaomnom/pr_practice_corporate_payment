import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:p150bar/data/model/api_car_wash_from_promo_code.dart';
import 'package:p150bar/domain/model/corporate_account.dart';

part 'api_corporate_account.freezed.dart';
part 'api_corporate_account.g.dart';

@freezed
@HiveType(typeId: 27)
class ApiCorporateAccount with _$ApiCorporateAccount {

  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory ApiCorporateAccount({
    @HiveField(0) required int id,
    @HiveField(1) required String title,
    @HiveField(2) required int minimumAmount,
    @HiveField(3) required int balance,
    @HiveField(4) List<ApiCarWashFromPromoCode>? carWashesInfo,
  }) = _ApiCorporateAccount;

  const ApiCorporateAccount._();

  factory ApiCorporateAccount.fromJson(Map<String, dynamic> json) => _$ApiCorporateAccountFromJson(json);

  CorporateAccount toDomain() => CorporateAccount(
    id: id,
    title: title,
    minimumAmount: minimumAmount,
    balance: balance,
    carWashesInfo: carWashesInfo?.map((e) => e.toDomain()).toList(),
  );

  factory ApiCorporateAccount.fromDomain(CorporateAccount corporateAccount) => ApiCorporateAccount(
    id: corporateAccount.id,
    title: corporateAccount.title,
    minimumAmount: corporateAccount.minimumAmount,
    balance: corporateAccount.balance,
    carWashesInfo: corporateAccount.carWashesInfo?.map((carWash) => ApiCarWashFromPromoCode.fromDomain(carWash)).toList(),
  );
}
