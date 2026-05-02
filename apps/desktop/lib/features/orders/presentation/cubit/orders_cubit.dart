import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/orders/domain/repositories/orders_repository.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required OrdersRepository repository})
      : _repository = repository,
        super(const OrdersInitial());

  final OrdersRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const OrdersLoading());
    try {
      final orders = await _repository.getOrders();
      emit(OrdersLoaded(orders: orders));
    } on ApiException catch (e, st) {
      _log.e('Orders load failed', error: e, stackTrace: st);
      emit(OrdersFailure(e.message));
    } catch (e, st) {
      _log.e('Orders load failed', error: e, stackTrace: st);
      emit(const OrdersFailure('Unable to reach server. Is it running?'));
    }
  }

  /// Fetches the Polar customer portal URL and copies it to the clipboard.
  ///
  /// Returns the URL string on success, or `null` if the server has no portal
  /// URL configured (404). Callers may show a snackbar based on the result.
  Future<String?> openPortal() async {
    try {
      final url = await _repository.portalUrl();
      if (url != null) {
        await Clipboard.setData(ClipboardData(text: url));
      }
      return url;
    } catch (e, st) {
      _log.e('Portal URL fetch failed', error: e, stackTrace: st);
      return null;
    }
  }
}
