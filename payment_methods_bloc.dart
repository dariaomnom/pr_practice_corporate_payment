// Dart imports
import 'dart:async';

// Package imports:
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

// Project imports:
import 'package:p150bar/constants.dart';
import 'package:p150bar/data/api/api_exceptions.dart';
import 'package:p150bar/domain/bloc/autorization/authorization_bloc.dart';
import 'package:p150bar/domain/bloc/cities/cities_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_scenario_bloc.dart';
import 'package:p150bar/domain/model/city.dart';
import 'package:p150bar/domain/model/corporate_account.dart';
import 'package:p150bar/domain/model/payment_card.dart';
import 'package:p150bar/domain/model/unknown_error.dart';
import 'package:p150bar/domain/repository/customer_repository.dart';
import 'package:p150bar/domain/repository/local_data_repository.dart';
import 'package:p150bar/domain/repository/payment_repository.dart';
import 'package:p150bar/domain/repository/reference_repository.dart';
import 'package:p150bar/injection.dart';
import 'package:p150bar/logger.dart';
import 'package:p150bar/presentation/design/util/constants.dart';

part 'payment_methods_bloc.freezed.dart';

@lazySingleton
class PaymentMethodsBloc extends Bloc<PaymentMethodsEvent, PaymentMethodsState> {
  final PaymentRepository _paymentRepository;
  final CustomerRepository _customerRepository;
  final LocalDataRepository _localDataRepository;
  final AuthorizationBloc _authorizationBloc;
  final ReferenceRepository _referenceRepository;

  StreamSubscription<int>? _countryIdSubscription;
  late StreamSubscription? _streamSubscription;

  final List<PaymentCard> _boundPaymentCardsList = [];
  final List<CorporateAccount> _corporateAccountsList = [];
  late bool _isShowPaymentCard = false;

  String? _bonusBalance;
  PaymentCard? _currentPaymentCard;
  CurrentPaymentMethod _currentPaymentMethod = CurrentPaymentMethod.bonusPayment;
  CorporateAccount? _currentCorporateAccount;
  String _currency = Constants.rouble;
  CitiesBloc citiesBloc = getIt<CitiesBloc>();
  City? currentCity;

  PaymentMethodsBloc(
    this._paymentRepository,
    this._authorizationBloc,
    this._customerRepository,
    this._localDataRepository,
    this._referenceRepository,
  ) : super(const PaymentMethodsState.loading()) {
    _streamSubscription = _authorizationBloc.stream.listen((AuthorizationState authorizationState) {
      authorizationState.maybeMap(
        unauthorized: (value) {
          if (!value.isSignedUp) {
            add(const PaymentMethodsEvent.clear());
          }
        },
        authorized: (value) {
          add(const PaymentMethodsEvent.clear());
          add(const PaymentMethodsEvent.loadPaymentCards(refresh: true));
        },
        orElse: () => null,
      );
    });

    _countryIdSubscription = _customerRepository.getCountryIdStream().listen((id) {
      if (_currency == Constants.rouble && id != 1) {
        add(PaymentMethodsEvent.setCurrency(id));
        add(const PaymentMethodsEvent.loadPaymentCards(refresh: true));
      }
    });
  }

  @override
  Future<void> close() {
    _countryIdSubscription?.cancel();
    _streamSubscription?.cancel();
    return super.close();
  }

  Stream<PaymentMethodsState> mapEventToState(PaymentMethodsEvent event) async* {
    await updateCurrentCity();

    if (event is _LoadPaymentCards) {
      if (event.refresh || (_boundPaymentCardsList.isEmpty)) {
        try {
          final corporateAccountsListStream = _paymentRepository.getCorporateAccountsStream();
          await for (final corporateAccountsList in corporateAccountsListStream) {
            _corporateAccountsList
              ..clear()
              ..addAll(corporateAccountsList.toList());
          }
          final paymentCardsListStream = _paymentRepository.getPaymentCardsStream();
          await for (final paymentCardsList in paymentCardsListStream) {
            _boundPaymentCardsList // активные карты
              ..clear()
              ..addAll(paymentCardsList.where((paymentCard) => paymentCard.status == 10).toList());

            await _loadCardIdFromPref();

            if (_currentPaymentMethod == CurrentPaymentMethod.cardPayment && _currentPaymentCard?.id == -2) {
              if (_currentPaymentCard?.id != -2) {
                add(
                  PaymentMethodsEvent.selectCurrentPaymentMethod(
                    paymentMethod: _currentPaymentMethod,
                    corporateAccount: _currentCorporateAccount,
                    paymentCard: _currentPaymentCard,
                  ),
                );
              }
            }

            if (_bonusBalance == null) add(const PaymentMethodsEvent.loadBonusBalance(refresh: true));

            yield PaymentMethodsState.ready(
              boundPaymentCardsList: _boundPaymentCardsList,
              corporateAccountsList: _corporateAccountsList,
              bonusBalance: _bonusBalance ?? '0',
              currentPaymentMethod: _currentPaymentMethod,
              currentCorporateAccount: _currentCorporateAccount,
              currentPaymentCard: _currentPaymentCard,
              currency: _currency,
              isLoading: true,
              isShowPaymentCard: _isShowPaymentCard,
              currentCity: currentCity,
            );
          }
          yield (state as _Ready).copyWith(isLoading: false);
        } catch (err) {
          yield PaymentMethodsState.error(
            err is ApiException ? err.message : UnknownError.getErrorMessage(),
            PaymentTypeError.otherError,
          );
        }
      } else {
        yield PaymentMethodsState.ready(
          boundPaymentCardsList: _boundPaymentCardsList,
          corporateAccountsList: _corporateAccountsList,
          bonusBalance: _bonusBalance ?? '0',
          currentPaymentMethod: _currentPaymentMethod,
          currentPaymentCard: _currentPaymentCard,
          currentCorporateAccount: _currentCorporateAccount,
          currency: _currency,
          isLoading: false,
          isShowPaymentCard: _isShowPaymentCard,
          currentCity: currentCity,
        );
      }
    }

    if (event is _LoadBonusBalance) {
      try {
        final customerBonusBalanceStream = _customerRepository.getCustomerBonusBalanceStream();
        await for (final customerBonusBalance in customerBonusBalanceStream) {
          _bonusBalance = customerBonusBalance;
          if (_currentPaymentMethod == CurrentPaymentMethod.bonusPayment && (_bonusBalance ?? '0') == '0') {
            _currentPaymentMethod = CurrentPaymentMethod.cashPayment;
          }
          yield PaymentMethodsState.ready(
            boundPaymentCardsList: _boundPaymentCardsList,
            corporateAccountsList: _corporateAccountsList,
            bonusBalance: _bonusBalance ?? '0',
            currentPaymentMethod: _currentPaymentMethod,
            currentPaymentCard: _currentPaymentCard,
            currentCorporateAccount: _currentCorporateAccount,
            currency: _currency,
            isLoading: true,
            isShowPaymentCard: _isShowPaymentCard,
            currentCity: currentCity,
          );
        }
        yield (state as _Ready).copyWith(isLoading: false);
      } catch (err) {
        yield PaymentMethodsState.error(
          err is ApiException ? err.message : UnknownError.getErrorMessage(),
          PaymentTypeError.otherError,
        );
      }
    }

    if (event is _UpdatePaymentCard) {
      try {
        await _paymentRepository.updatePaymentCard(
          title: event.title,
          id: event.paymentCardId,
        );
        add(const PaymentMethodsEvent.loadPaymentCards(refresh: true));
      } catch (err) {
        yield PaymentMethodsState.error(
          err is ApiException ? err.message : UnknownError.getErrorMessage(),
          PaymentTypeError.otherError,
        );
      }
    }

    if (event is _DeletePaymentCard) {
      try {
        _removePaymentCardInList(_boundPaymentCardsList, event.paymentCardId);

        yield PaymentMethodsState.ready(
          boundPaymentCardsList: _boundPaymentCardsList,
          corporateAccountsList: _corporateAccountsList,
          bonusBalance: _bonusBalance ?? '0',
          currentPaymentMethod: _currentPaymentMethod,
          currentPaymentCard: _currentPaymentCard,
          currentCorporateAccount: _currentCorporateAccount,
          currency: _currency,
          isLoading: true,
          isShowPaymentCard: _isShowPaymentCard,
          currentCity: currentCity,
        );

        await _paymentRepository.deletePaymentCard(event.paymentCardId);
        add(const PaymentMethodsEvent.loadPaymentCards(refresh: true));
      } catch (err) {
        yield PaymentMethodsState.error(
          err is ApiException ? err.message : UnknownError.getErrorMessage(),
          PaymentTypeError.otherError,
        );
      }
    }

    if (event is _SelectCurrentPaymentMethod) {
      try {
        if (_currentPaymentMethod != event.paymentMethod) {
          _currentPaymentMethod = event.paymentMethod;
          _localDataRepository.setPaymentMethod(_currentPaymentMethod);
        }
        if (_currentCorporateAccount != event.corporateAccount) {
          _currentCorporateAccount = event.corporateAccount;
          if (_currentCorporateAccount != null) {
            _localDataRepository.setCorporateAccountId(_currentCorporateAccount?.id ?? 0);
          } else {
            _localDataRepository.clearCorporateAccountId();
          }
        }

        if (event.paymentCard != null && _currentPaymentCard != event.paymentCard) {
          _currentPaymentCard = event.paymentCard;
          final id = event.paymentCard?.id;
          _paymentRepository.setCardId(id);
          _localDataRepository.setCardId(id ?? 0);
        }

        yield PaymentMethodsState.ready(
          boundPaymentCardsList: _boundPaymentCardsList,
          corporateAccountsList: _corporateAccountsList,
          bonusBalance: _bonusBalance ?? '0',
          currentPaymentMethod: _currentPaymentMethod,
          currentPaymentCard: _currentPaymentCard,
          currentCorporateAccount: _currentCorporateAccount,
          currency: _currency,
          isLoading: false,
          isShowPaymentCard: _isShowPaymentCard,
          currentCity: currentCity,
        );
      } catch (err) {
        logger.e(err);
      }
    }

    if (event is _OnError) {
      yield PaymentMethodsState.error(event.message, PaymentTypeError.otherError);
      yield PaymentMethodsState.ready(
        boundPaymentCardsList: _boundPaymentCardsList,
        corporateAccountsList: _corporateAccountsList,
        bonusBalance: _bonusBalance ?? '0',
        currentPaymentMethod: _currentPaymentMethod,
        currentPaymentCard: _currentPaymentCard,
        currentCorporateAccount: _currentCorporateAccount,
        currency: _currency,
        isLoading: false,
        isShowPaymentCard: _isShowPaymentCard,
        currentCity: currentCity,
      );
    }

    if (event is _Clear &&
        (_boundPaymentCardsList.isNotEmpty || _corporateAccountsList.isNotEmpty || _bonusBalance != null)) {
      _boundPaymentCardsList.clear();
      _corporateAccountsList.clear();
      _bonusBalance = null;
      _currency = Constants.rouble;
      _localDataRepository.clearCardId();
      _localDataRepository.clearCorporateAccountId();
      _localDataRepository.clearPaymentMethod();
      _paymentRepository.setCardId(null);
      yield PaymentMethodsState.ready(
        boundPaymentCardsList: _boundPaymentCardsList,
        corporateAccountsList: _corporateAccountsList,
        bonusBalance: _bonusBalance ?? '0',
        currentPaymentMethod: _currentPaymentMethod,
        currentPaymentCard: _currentPaymentCard,
        currentCorporateAccount: _currentCorporateAccount,
        currency: _currency,
        isLoading: false,
        isShowPaymentCard: _isShowPaymentCard,
        currentCity: currentCity,
      );
    }

    if (event is _setCurrency) {
      _currency = event.countryId == 1 ? Constants.rouble : Constants.tenge;
      yield PaymentMethodsState.ready(
        boundPaymentCardsList: _boundPaymentCardsList,
        corporateAccountsList: _corporateAccountsList,
        bonusBalance: _bonusBalance ?? '0',
        currentPaymentMethod: _currentPaymentMethod,
        currentPaymentCard: _currentPaymentCard,
        currentCorporateAccount: _currentCorporateAccount,
        currency: _currency,
        isLoading: false,
        isShowPaymentCard: _isShowPaymentCard,
        currentCity: currentCity,
      );
    }

    if (event is _showPaymentCard) {
      _isShowPaymentCard = true;
      yield PaymentMethodsState.ready(
        boundPaymentCardsList: _boundPaymentCardsList,
        corporateAccountsList: _corporateAccountsList,
        bonusBalance: _bonusBalance ?? '0',
        currentPaymentMethod: _currentPaymentMethod,
        currentPaymentCard: _currentPaymentCard,
        currentCorporateAccount: _currentCorporateAccount,
        currency: _currency,
        isLoading: false,
        isShowPaymentCard: _isShowPaymentCard,
        currentCity: currentCity,
      );
    }

    if (event is _hidePaymentCard) {
      _isShowPaymentCard = false;
      if (event.isReady) {
        yield PaymentMethodsState.ready(
          boundPaymentCardsList: _boundPaymentCardsList,
          corporateAccountsList: _corporateAccountsList,
          bonusBalance: _bonusBalance ?? '0',
          currentPaymentMethod: _currentPaymentMethod,
          currentPaymentCard: _currentPaymentCard,
          currentCorporateAccount: _currentCorporateAccount,
          currency: _currency,
          isLoading: false,
          isShowPaymentCard: _isShowPaymentCard,
          currentCity: currentCity,
        );
      }
    }
  }

  void _removePaymentCardInList(List<PaymentCard> paymentCardsList, int id) {
    if (paymentCardsList.isNotEmpty) {
      List<PaymentCard> card;
      card = paymentCardsList.where((paymentCard) => paymentCard.id == id).toList();
      if (card.isNotEmpty) {
        paymentCardsList.remove(card.first);
      }
    }
  }

  Future<void> updateCurrentCity() async {
    List<City> localCities = [];
    final cityId = _customerRepository.getCityId();
    if (cityId != null && cityId != currentCity?.id) {
      final countryId = _customerRepository.getCountryId();
      final citiesStream = _referenceRepository.getCitiesStream(countryId);
      await for (final cities in citiesStream) {
        localCities = cities;
      }
      currentCity = localCities.firstWhereOrNull(
        (city) => city.id == cityId,
      );
    }
  }

  Future<void> _loadCardIdFromPref() async {
    final paymentMethod = await _localDataRepository.getPaymentMethod();
    if (paymentMethod != null && paymentMethod != _currentPaymentMethod) {
      _currentPaymentMethod = paymentMethod;
    }

    final cardId = await _localDataRepository.getCardId();
    if (cardId != null) {
      _currentPaymentCard = _boundPaymentCardsList.firstWhereOrNull(
        (card) => card.id == cardId,
      );
    }

    if (_currentPaymentCard == null) {
      if (_boundPaymentCardsList.isNotEmpty) {
        _currentPaymentCard = _boundPaymentCardsList.last;
      } else {
        _currentPaymentCard = newCardAllPS;
      }
      _localDataRepository.setCardId(_currentPaymentCard?.id ?? newCardAllPS.id);
    }

    final corporateAccountId = await _localDataRepository.getCorporateAccountId();
    if (corporateAccountId != null) {
      _currentCorporateAccount = _corporateAccountsList.firstWhereOrNull(
        (c) => c.id == corporateAccountId,
      );
    } else {
      if (_corporateAccountsList.isNotEmpty) {
        _currentCorporateAccount = _corporateAccountsList.last;
        _localDataRepository.setCorporateAccountId(_currentCorporateAccount?.id ?? 0);
      }
    }

    if ((_currentCorporateAccount == null && _currentPaymentMethod == CurrentPaymentMethod.corporatePayment) ||
        (_currentPaymentCard?.id == newCardAllPS.id && _currentPaymentMethod == CurrentPaymentMethod.cardPayment) ||
        paymentMethod == null) {
      if (_bonusBalance != null && _bonusBalance != '0') {
        _currentPaymentMethod = CurrentPaymentMethod.bonusPayment;
      } else {
        _currentPaymentMethod = CurrentPaymentMethod.cashPayment;
      }
      add(
        PaymentMethodsEvent.selectCurrentPaymentMethod(
          paymentMethod: _currentPaymentMethod,
          corporateAccount: _currentCorporateAccount,
          paymentCard: _currentPaymentCard,
        ),
      );
    }
  }
}

@freezed
class PaymentMethodsEvent with _$PaymentMethodsEvent {
  const factory PaymentMethodsEvent.loadPaymentCards({@Default(false) bool refresh}) = _LoadPaymentCards;

  const factory PaymentMethodsEvent.loadBonusBalance({@Default(false) bool refresh}) = _LoadBonusBalance;

  const factory PaymentMethodsEvent.setCurrency(int countryId) = _setCurrency;

  const factory PaymentMethodsEvent.updatePaymentCard({
    required int? paymentCardId,
    required String title,
  }) = _UpdatePaymentCard;

  const factory PaymentMethodsEvent.deletePaymentCard({required int paymentCardId}) = _DeletePaymentCard;

  const factory PaymentMethodsEvent.selectCurrentPaymentMethod({
    required CurrentPaymentMethod paymentMethod,
    PaymentCard? paymentCard,
    CorporateAccount? corporateAccount,
  }) = _SelectCurrentPaymentMethod;

  const factory PaymentMethodsEvent.onError(String message) = _OnError;

  const factory PaymentMethodsEvent.clear() = _Clear;

  const factory PaymentMethodsEvent.showPaymentCard() = _showPaymentCard;

  const factory PaymentMethodsEvent.hidePaymentCard({@Default(true) bool isReady}) = _hidePaymentCard;
}

@freezed
class PaymentMethodsState with _$PaymentMethodsState {
  const factory PaymentMethodsState.ready({
    required List<PaymentCard> boundPaymentCardsList,
    required List<CorporateAccount> corporateAccountsList,
    required String bonusBalance,
    @Default(CurrentPaymentMethod.bonusPayment) CurrentPaymentMethod currentPaymentMethod,
    required CorporateAccount? currentCorporateAccount,
    required PaymentCard? currentPaymentCard,
    required String currency,
    required bool isLoading,
    required bool isShowPaymentCard,
    required City? currentCity,
  }) = _Ready;

  const factory PaymentMethodsState.loading({@Default(false) bool refresh}) = _Loading;

  const factory PaymentMethodsState.error(String message, PaymentTypeError typeError) = _Error;
}

enum PaymentTypeError {
  isOnlineBoxError,
  otherError,
}
