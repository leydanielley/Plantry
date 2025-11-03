// =============================================
// GROWLOG - AsyncValue Pattern for State Management
// =============================================

/// Sealed class representing the state of an asynchronous operation
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> {
///   AsyncValue<List<Plant>> _plants = const Loading();
///
///   Future<void> _loadPlants() async {
///     setState(() => _plants = const Loading());
///
///     try {
///       final plants = await _plantRepo.findAll();
///       setState(() => _plants = Success(plants));
///     } catch (e) {
///       setState(() => _plants = Error('Failed to load plants', e));
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return switch (_plants) {
///       Loading() => const Center(child: CircularProgressIndicator()),
///       Success(:final data) => ListView.builder(
///         itemCount: data.length,
///         itemBuilder: (context, i) => PlantCard(data[i]),
///       ),
///       Error(:final message) => ErrorView(
///         message: message,
///         onRetry: _loadPlants,
///       ),
///     };
///   }
/// }
/// ```
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Check if currently loading
  bool get isLoading => this is Loading<T>;

  /// Check if has data
  bool get hasData => this is Success<T>;

  /// Check if has error
  bool get hasError => this is Error<T>;

  /// Get data if available, null otherwise
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        _ => null,
      };

  /// Get error message if available, null otherwise
  String? get errorOrNull => switch (this) {
        Error(:final message) => message,
        _ => null,
      };
}

/// Loading state - operation in progress
class Loading<T> extends AsyncValue<T> {
  const Loading();

  @override
  String toString() => 'Loading<$T>()';
}

/// Success state - operation completed successfully with data
class Success<T> extends AsyncValue<T> {
  final T data;

  const Success(this.data);

  @override
  String toString() => 'Success<$T>(data: $data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Error state - operation failed with error
class Error<T> extends AsyncValue<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const Error(
    this.message, [
    this.error,
    this.stackTrace,
  ]);

  @override
  String toString() => 'Error<$T>(message: $message, error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Extension methods for AsyncValue
extension AsyncValueX<T> on AsyncValue<T> {
  /// Map the data to a new type, preserving loading/error states
  AsyncValue<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Loading() => Loading<R>(),
      Success(:final data) => Success(transform(data)),
      Error(:final message, :final error, :final stackTrace) =>
        Error(message, error, stackTrace),
    };
  }

  /// Execute callback when in success state
  void whenSuccess(void Function(T data) callback) {
    if (this case Success(:final data)) {
      callback(data);
    }
  }

  /// Execute callback when in error state
  void whenError(void Function(String message, Object? error) callback) {
    if (this case Error(:final message, :final error)) {
      callback(message, error);
    }
  }
}
