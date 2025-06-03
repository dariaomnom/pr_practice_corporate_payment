import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p150bar/constants.dart';
import 'package:p150bar/domain/bloc/payment/payment_methods_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_scenario_bloc.dart';
import 'package:p150bar/domain/model/car_wash.dart';
import 'package:p150bar/domain/model/corporate_account.dart';
import 'package:p150bar/domain/model/payment_card.dart';
import 'package:p150bar/presentation/application/application_theme.dart';
import 'package:p150bar/presentation/design/util/constants.dart';
import 'package:p150bar/presentation/design/widgets/payment_method_item.dart';

class PaymentMethodsSelectList extends StatefulWidget {
  final List<PaymentCard> boundPaymentCardsList;
  final List<CorporateAccount> corporateAccountsList;
  final String currency;
  final String bonusBalance;
  final PaymentCard? currentPaymentCard;
  final CurrentPaymentMethod currentPaymentMethod;
  final CorporateAccount? currentCorporateAccount;
  final ScrollPhysics? physics;
  final CarWash? currentCarWash;

  const PaymentMethodsSelectList({
    required this.boundPaymentCardsList,
    required this.currency,
    required this.bonusBalance,
    required this.currentPaymentMethod,
    this.physics,
    required this.corporateAccountsList,
    required this.currentCarWash,
    this.currentPaymentCard,
    this.currentCorporateAccount,
  });

  @override
  _PaymentMethodsSelectListState createState() => _PaymentMethodsSelectListState();
}

class _PaymentMethodsSelectListState extends State<PaymentMethodsSelectList> {
  late List<Widget> _listPaymentMethods = [];
  late List<CorporateAccount> _corporateAccountsList = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listPaymentMethods = _getListPaymentMethods();
    return ListView.builder(
      shrinkWrap: true,
      physics: widget.physics,
      padding: const EdgeInsets.symmetric(vertical: 5),
      itemBuilder: (BuildContext context, int index) => _listPaymentMethods[index],
      itemCount: _listPaymentMethods.length,
    );
  }

  List<Widget> _getListPaymentMethods() {
    _corporateAccountsList = widget.corporateAccountsList
        .where(
          (account) => account.carWashesInfo?.where((info) => info.id == widget.currentCarWash?.id).isNotEmpty ?? false,
        )
        .toList();
    return [
      if (widget.currentCarWash?.isYookassa ?? false) _getPaymentCard(widget.currentPaymentCard, widget.currentPaymentMethod),
      _getBonusAccount(
        widget.currency,
        widget.bonusBalance,
        widget.currentPaymentMethod,
      ),
      _getCashAccount(
        widget.currentPaymentMethod,
      ),
      if (_corporateAccountsList.isNotEmpty)
        _getCorporateAccount(
            widget.currentCorporateAccount ?? _corporateAccountsList.first, widget.currentPaymentMethod),
    ];
  }

  Widget _getBonusAccount(
    String currency,
    String customerBonusBalance,
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        title: Row(
          children: [
            const Text(
              'Бонусы',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: ApplicationTheme.fontSizeText,
                fontWeight: ApplicationTheme.fontWeightButton,
              ),
            ),
            Text(
              ' - $customerBonusBalance Б',
              style: ApplicationTheme.textStyleText,
            ),
          ],
        ),
        pathIcon: 'assets/images/icons/bonus.png',
        keyItem: "Бонусы",
        isChecked: currentPaymentMethod == CurrentPaymentMethod.bonusPayment,
        paymentMethod: CurrentPaymentMethod.bonusPayment,
        bloc: context.read<PaymentMethodsBloc>(),
        paddingRight: 0,
      );

  Widget _getCorporateAccount(
    CorporateAccount corporateAccount,
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        title: Row(
          children: [
            Text(
              corporateAccount.title,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: ApplicationTheme.fontSizeText,
                fontWeight: ApplicationTheme.fontWeightButton,
              ),
            ),
            Text(
              ' - ${corporateAccount.balance} ${Constants.rouble}',
              style: ApplicationTheme.textStyleText,
            ),
          ],
        ),
        pathIcon: 'assets/images/icons/corporate_account.png',
        keyItem: corporateAccount.title,
        isChecked: currentPaymentMethod == CurrentPaymentMethod.corporatePayment,
        corporateAccount: corporateAccount,
        paymentMethod: CurrentPaymentMethod.corporatePayment,
        bloc: context.read<PaymentMethodsBloc>(),
        addButton: widget.corporateAccountsList.length > 1 ? _getAddButton() : null,
        paddingRight: 0,
        onTap: (BuildContext context) => showPaymentCard(context),
      );

  Widget _getCashAccount(
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        title: const Text(
          'Наличные / Карта (NFC)',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: ApplicationTheme.fontSizeText,
            fontWeight: ApplicationTheme.fontWeightButton,
          ),
        ),
        pathIcon: 'assets/images/icons/cash_icon.png',
        keyItem: "Наличные",
        isChecked: currentPaymentMethod == CurrentPaymentMethod.cashPayment,
        paymentMethod: CurrentPaymentMethod.cashPayment,
        bloc: context.read<PaymentMethodsBloc>(),
        paddingRight: 0,
      );

  Widget _getPaymentCard(
    PaymentCard? currentPaymentCard,
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        title: Text(
          widget.currentPaymentCard?.id != newCardAllPS.id
              ? 'Карта ${widget.currentPaymentCard?.title}'
              : 'Картой в приложении',
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: ApplicationTheme.fontSizeText,
            fontWeight: ApplicationTheme.fontWeightButton,
          ),
        ),
        pathIcon: 'assets/images/icons/card_icon.png',
        keyItem: "Банковская карта",
        isChecked: currentPaymentMethod == CurrentPaymentMethod.cardPayment,
        paymentCard: currentPaymentCard ?? newCardAllPS,
        paymentMethod: CurrentPaymentMethod.cardPayment,
        bloc: context.read<PaymentMethodsBloc>(),
        addButton: widget.boundPaymentCardsList.isNotEmpty ? _getAddButton() : null,
        paddingRight: 0,
        onTap: (BuildContext context) => showPaymentCard(context),
      );

  Widget _getAddButton() => GestureDetector(
        onTap: () {
          showPaymentCard(context);
        },
        behavior: HitTestBehavior.translucent,
        child: AbsorbPointer(
          absorbing: false,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 60,
              height: 42,
              padding: const EdgeInsets.only(
                left: 32,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/icons/payment_select.png',
                  width: 16,
                  height: 16,
                ),
              ),
            ),
          ),
        ),
      );

  void showPaymentCard(BuildContext context) {
    context.read<PaymentMethodsBloc>().add(const PaymentMethodsEvent.showPaymentCard());
  }
}
