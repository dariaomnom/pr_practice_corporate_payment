import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p150bar/constants.dart';
import 'package:p150bar/domain/bloc/customer_settings_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_card_creation_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_methods_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_scenario_bloc.dart';
import 'package:p150bar/domain/model/corporate_account.dart';
import 'package:p150bar/domain/model/payment_card.dart';
import 'package:p150bar/domain/service/main_service.dart';
import 'package:p150bar/injection.dart';
import 'package:p150bar/presentation/application/application_theme.dart';
import 'package:p150bar/presentation/design/util/constants.dart';
import 'package:p150bar/presentation/design/widgets/bottom_wide_button.dart';
import 'package:p150bar/presentation/design/widgets/custom_flushbar.dart';
import 'package:p150bar/presentation/design/widgets/loading_container.dart';
import 'package:p150bar/presentation/design/widgets/payment_card_list_tile.dart';
import 'package:p150bar/presentation/design/widgets/payment_method_item.dart';
import 'package:p150bar/presentation/home_page/payment_scenario/modal_pages/card_initialization_sber.dart';

class PaymentMethodsList extends StatefulWidget {
  final List<PaymentCard> boundPaymentCardsList;
  final List<CorporateAccount> corporateAccountsList;
  final String currency;
  final String bonusBalance;
  final PaymentCard? currentPaymentCard;
  final CurrentPaymentMethod currentPaymentMethod;
  final CorporateAccount? currentCorporateAccount;
  final ScrollPhysics? physics;
  final bool isAddCard;

  const PaymentMethodsList({
    required this.boundPaymentCardsList,
    required this.currency,
    required this.bonusBalance,
    required this.currentPaymentMethod,
    required this.isAddCard,
    required this.corporateAccountsList,
    this.physics,
    this.currentPaymentCard,
    this.currentCorporateAccount,
  });

  @override
  _PaymentMethodsListState createState() => _PaymentMethodsListState();
}

class _PaymentMethodsListState extends State<PaymentMethodsList> {
  final _paymentCardCreationBloc = getIt<PaymentCardCreationBloc>();
  late PaymentBloc _paymentBloc;
  late PaymentMethodsBloc _paymentMethodBloc;
  late List<Widget> _listPaymentMethods = <Widget>[];

  @override
  void initState() {
    _paymentBloc = getIt<PaymentBloc>();
    _paymentBloc.add(const PaymentEvent.finishPay());
    super.initState();
  }

  @override
  void dispose() {
    _paymentCardCreationBloc.close();
    _paymentBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _paymentMethodBloc = context.read<PaymentMethodsBloc>();
    _listPaymentMethods = _getListPaymentMethods();
    return BlocConsumer<PaymentBloc, PaymentState>(
      bloc: _paymentBloc,
      listener: (context, state) {
        state.maybeMap(
          initCard: (initCard) =>
              _initializePaymentMethod(context: context, formUrl: initCard.formUrl, bloc: _paymentBloc),
          error: (error) {
            CustomFlushbar.showError(context, message: error.message);
            _paymentBloc.add(const PaymentEvent.finishPay());
          },
          warning: (warning) {
            CustomFlushbar.showError(context, message: warning.message);
            _paymentBloc.add(const PaymentEvent.finishPay());
          },
          cancel: (cancel) {
            CustomFlushbar.showError(context, message: cancel.message);
            _paymentBloc.add(const PaymentEvent.finishPay());
          },
          orElse: () => false,
        );
      },
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: Container(
            key: ValueKey(state.toString()),
            color: ApplicationTheme.backgroundColor,
            child: state.maybeMap(
              loading: (loading) => LoadingContainer.getLoader(context),
              ready: (ready) {
                return ListView.separated(
                  physics: widget.physics,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(
                    height: 0,
                  ),
                  itemBuilder: (BuildContext context, int index) => _listPaymentMethods[index],
                  itemCount: _listPaymentMethods.length,
                );
              },
              orElse: () {
                return null;
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _getListPaymentMethods() {
    return [
      if (widget.boundPaymentCardsList.isNotEmpty)
        ..._getBoundPaymentCardsList(
          widget.boundPaymentCardsList,
          widget.currentPaymentCard,
          widget.currentPaymentMethod,
        ),
     _getCashAccount(
        widget.currentPaymentMethod,
      ),
      _getBonusAccount(
        widget.currency,
        widget.bonusBalance,
        widget.currentPaymentMethod,
      ),
      if (widget.corporateAccountsList.isNotEmpty)
        ..._getCorporateAccount(
            widget.corporateAccountsList, widget.currentPaymentMethod, widget.currentCorporateAccount),

      _getAddMessage(),
      if (widget.isAddCard) _getAddPaymentMethodButton(widget.currency),
      SizedBox(
        height: MainService().heightBottomNavBarBottom + 50,
      ),
    ];
  }

  List<Widget> _getCorporateAccount(List<CorporateAccount> corporateAccountsList,
          CurrentPaymentMethod currentPaymentMethod, CorporateAccount? currentCorporateAccount) =>
      corporateAccountsList
          .map(
            (corporateAccount) => PaymentMethodItem(
              isMini: false,
              paymentMethod: CurrentPaymentMethod.corporatePayment,
              bloc: _paymentMethodBloc,
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
              isChecked: currentPaymentMethod == CurrentPaymentMethod.corporatePayment &&
                  corporateAccount.id == currentCorporateAccount?.id,
              corporateAccount: corporateAccount,
            ),
          )
          .toList(growable: false);

  Widget _getBonusAccount(
    String currency,
    String customerBonusBalance,
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        isMini: false,
        paymentMethod: CurrentPaymentMethod.bonusPayment,
        bloc: _paymentMethodBloc,
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
        keyItem: 'Бонусный счет',
        isChecked: currentPaymentMethod == CurrentPaymentMethod.bonusPayment,
      );

  Widget _getCashAccount(
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      PaymentMethodItem(
        isMini: false,
        paymentMethod: CurrentPaymentMethod.cashPayment,
        bloc: _paymentMethodBloc,
        title: const Text(
          'Наличные / Карта (NFC)',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: ApplicationTheme.fontSizeText,
            fontWeight: ApplicationTheme.fontWeightButton,
          ),
        ),
        pathIcon: 'assets/images/icons/cash_icon.png',
        keyItem: 'Наличные счет',
        isChecked: currentPaymentMethod == CurrentPaymentMethod.cashPayment,
      );

  List<Widget> _getBoundPaymentCardsList(
    List<PaymentCard> boundPaymentCardsList,
    PaymentCard? currentPaymentCard,
    CurrentPaymentMethod currentPaymentMethod,
  ) =>
      boundPaymentCardsList
          .map(
            (paymentCard) => _getSlidableTile(
              paymentCard: paymentCard,
              child: PaymentMethodItem(
                isMini: false,
                paymentMethod: CurrentPaymentMethod.cardPayment,
                bloc: _paymentMethodBloc,
                title: Text(
                  'Карта ${paymentCard.title}',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontSize: ApplicationTheme.fontSizeText,
                    fontWeight: ApplicationTheme.fontWeightButton,
                  ),
                ),
                pathIcon: boundPaymentCardsList.indexOf(paymentCard).isEven
                    ? 'assets/images/icons/card_icon.png'
                    : 'assets/images/icons/card_icon_black.png',
                keyItem: paymentCard.title,
                paymentCard: paymentCard,
                isChecked: currentPaymentMethod == CurrentPaymentMethod.cardPayment &&
                    currentPaymentCard?.id == paymentCard.id,
              ),
            ),
          )
          .toList(growable: false);

  Widget _getAddMessage() => Container(
        color: ApplicationTheme.backgroundColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: const Text(
          'Укажите предпочитаемый способ оплаты',
          style: ApplicationTheme.textStyleText,
        ),
      );

  Widget _getAddPaymentMethodButton(String currency) => Container(
        color: ApplicationTheme.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 80),
        child: BottomWideButton(
          buttonColor: ApplicationTheme.primaryColor,
          textColor: ApplicationTheme.fontButtonColor,
          onPressed: () {
            context.read<CustomerSettingsBloc>().add(
                  const CustomerSettingsEvent.addAction(code: '7'),
                );
            _paymentBloc.add(
              PaymentEvent.pay(boxId: 0, cardId: newCardAllPS.id, amount: 10),
            );
          },
          text: 'Добавить карту',
        ),
      );

  Widget _getSlidableTile({
    required PaymentCard paymentCard,
    required Widget child,
  }) =>
      PaymentCardListTile(
        paymentCardItem: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: child,
        ),
        paymentCard: paymentCard,
      );

  Future<void> _initializePaymentMethod({
    required BuildContext context,
    required String formUrl,
    required PaymentBloc bloc,
  }) async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(
      MaterialPageRoute(
        builder: (context) => CardInitializationSber(
          formUrl: formUrl,
          paymentBloc: bloc,
          textLoader: 'Для привязки карты мы спишем небольшую сумму и сразу же вернем её вам.',
        ),
      ),
    );
  }
}
