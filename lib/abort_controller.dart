typedef OnAbort = void Function();

/// Represents a signal that can be monitored to determine if a request has been aborted.
abstract class IAbortSignal {
  /// Indicates if the request has been aborted.
  bool? get aborted;

  /// Set this to a handler that will be invoked when the request is aborted.
  OnAbort? onabort;
}

class AbortController implements IAbortSignal {
  // Properties
  bool? _isAborted;

  @override
  OnAbort? onabort;

  @override
  bool? get aborted => _isAborted;

  IAbortSignal get signal => this;

  // Methods

  AbortController() {
    _isAborted = false;
  }

  void abort() {
    if (!_isAborted!) {
      _isAborted = true;
      if (onabort != null) {
        onabort!();
      }
    }
  }
}
