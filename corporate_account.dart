import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:p150bar/domain/model/car_wash_from_promo_code.dart';

part 'corporate_account.freezed.dart';

@freezed
class CorporateAccount with _$CorporateAccount {
  const factory CorporateAccount({
    required int id,
    required String title,
    required int minimumAmount,
    required int balance,
    List<CarWashFromPromoCode>? carWashesInfo,
  }) = _CorporateAccount;
}
