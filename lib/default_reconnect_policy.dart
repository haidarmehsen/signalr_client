import 'iretry_policy.dart';

class DefaultRetryPolicy implements IRetryPolicy {
  late List<int?> _retryDelays;

  static const List<int?> defaultRetryDelaysInMilliseconds = [
    0,
    2000,
    10000,
    30000,
    null
  ];

  DefaultRetryPolicy({List<int>? retryDelays}) {
    _retryDelays = retryDelays != null
        ? [...retryDelays, null]
        : defaultRetryDelaysInMilliseconds;
  }

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    return _retryDelays[retryContext.previousRetryCount];
  }
}
