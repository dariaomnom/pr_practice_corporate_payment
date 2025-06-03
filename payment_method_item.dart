import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p150bar/domain/bloc/payment/payment_methods_bloc.dart';
import 'package:p150bar/domain/bloc/payment/payment_scenario_bloc.dart';
import 'package:p150bar/domain/model/corporate_account.dart';
import 'package:p150bar/domain/model/payment_card.dart';
import 'package:p150bar/presentation/application/application_theme.dart';
import 'package:p150bar/presentation/design/util/payment_methods_handlers.dart';
import 'package:p150bar/presentation/design/widgets/custom_circular_check_box.dart';
import 'package:p150bar/presentation/design/widgets/custom_list_tile.dart';
import 'package:p150bar/presentation/design/widgets/interactive_widget.dart';

class PaymentMethodItem extends StatelessWidget {
  final Widget title;
  final String pathIcon;
  final String keyItem;
  final bool isChecked;
  final double paddingRight;
  final CurrentPaymentMethod paymentMethod;
  final PaymentCard? paymentCard;
  final CorporateAccount? corporateAccount;
  final PaymentMethodsBloc bloc;
  final void Function(BuildContext)? onTap;
  final Widget? addButton;
  final bool isMini;

  const PaymentMethodItem({
    required this.title,
    required this.pathIcon,
    required this.keyItem,
    required this.isChecked,
    this.paymentCard,
    required this.bloc,
    this.addButton,
    Key? key,
    this.corporateAccount,
    required this.paymentMethod,
    this.paddingRight = 30.0,
    this.onTap,
    this.isMini = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InteractiveWidget(
      tappedColor: ApplicationTheme.primaryColor.withValues(alpha: 0.1),
      onTap: () {
        if (!isChecked) {
          PaymentMethodsHandlers.selectPaymentMethod(
            paymentMethod: paymentMethod,
            corporateAccount: corporateAccount,
            paymentCard: paymentCard,
            bloc: bloc,
          );
        } else if (addButton != null && onTap != null) {
          onTap!(context);
        }
      },
      child: CustomListTile(
        visualDensity: isMini ? const VisualDensity(vertical: -2): VisualDensity.standard,
        key: ValueKey(keyItem),
        tileColor: ApplicationTheme.backgroundColor,
        leading: Image.asset(
          pathIcon,
          width: 24,
          height: 24,
        ),
        title: Container(
          child: title,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            addButton ?? const SizedBox(),
            Padding(
              padding: EdgeInsets.only(right: paddingRight),
              child: CustomCircularCheckBox(
                isChecked: isChecked,
                color: ApplicationTheme.primaryColor,
                onTap: (_) => PaymentMethodsHandlers.selectPaymentMethod(
                  corporateAccount: corporateAccount,
                  paymentMethod: paymentMethod,
                  paymentCard: paymentCard,
                  bloc: bloc,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
