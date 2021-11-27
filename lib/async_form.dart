import 'package:flutter/material.dart';

/// An optional container for grouping together multiple form field widgets
/// (e.g. [TextField] widgets).
///
/// Each individual form field should be wrapped in a [AsyncFormField] widget, with
/// the [AsyncForm] widget as a common ancestor of all of those. Call methods on
/// [AsyncFormState] to save, reset, or validate each [AsyncFormField] that is a
/// descendant of this [AsyncForm]. To obtain the [AsyncFormState], you may use [AsyncForm.of]
/// with a context whose ancestor is the [AsyncForm], or pass a [GlobalKey] to the
/// [AsyncForm] constructor and call [GlobalKey.currentState].
///
/// {@tool dartpad --template=stateful_widget_scaffold}
/// This example shows a [AsyncForm] with one [TextFormField] to enter an email
/// address and an [ElevatedButton] to submit the form. A [GlobalKey] is used here
/// to identify the [AsyncForm] and validate input.
///
/// ![](https://flutter.github.io/assets-for-api-docs/assets/widgets/form.png)
///
/// ```dart
/// final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
///
/// @override
/// Widget build(BuildContext context) {
///   return Form(
///     key: _formKey,
///     child: Column(
///       crossAxisAlignment: CrossAxisAlignment.start,
///       children: <Widget>[
///         TextFormField(
///           decoration: const InputDecoration(
///             hintText: 'Enter your email',
///           ),
///           validator: (String? value) {
///             if (value == null || value.isEmpty) {
///               return 'Please enter some text';
///             }
///             return null;
///           },
///         ),
///         Padding(
///           padding: const EdgeInsets.symmetric(vertical: 16.0),
///           child: ElevatedButton(
///             onPressed: () {
///               // Validate will return true if the form is valid, or false if
///               // the form is invalid.
///               if (_formKey.currentState!.validate()) {
///                 // Process data.
///               }
///             },
///             child: const Text('Submit'),
///           ),
///         ),
///       ],
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [GlobalKey], a key that is unique across the entire app.
///  * [AsyncFormField], a single form field widget that maintains the current state.
///  * [TextFormField], a convenience widget that wraps a [TextField] widget in a [AsyncFormField].
class AsyncForm extends StatefulWidget {
  /// Creates a container for form fields.
  ///
  /// The [child] argument must not be null.
  const AsyncForm({
    Key? key,
    required this.child,
    @Deprecated(
      'Use autovalidateMode parameter which provides more specific '
          'behavior related to auto validation. '
          'This feature was deprecated after v1.19.0.',
    )
    this.autovalidate = false,
    this.onWillPop,
    this.onChanged,
    AsyncAutovalidateMode? autovalidateMode,
  }) : assert(child != null),
        assert(autovalidate != null),
        assert(
        autovalidate == false ||
            autovalidate == true && autovalidateMode == null,
        'autovalidate and autovalidateMode should not be used together.',
        ),
        autovalidateMode = autovalidateMode ??
            (autovalidate ? AsyncAutovalidateMode.always : AsyncAutovalidateMode.disabled),
        super(key: key);

  /// Returns the closest [AsyncFormState] which encloses the given context.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// FormState form = Form.of(context);
  /// form.save();
  /// ```
  static AsyncFormState? of(BuildContext context) {
    final _AsyncFormScope? scope = context.dependOnInheritedWidgetOfExactType<_AsyncFormScope>();
    return scope?._formState;
  }

  /// The widget below this widget in the tree.
  ///
  /// This is the root of the widget hierarchy that contains this form.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Enables the form to veto attempts by the user to dismiss the [ModalRoute]
  /// that contains the form.
  ///
  /// If the callback returns a Future that resolves to false, the form's route
  /// will not be popped.
  ///
  /// See also:
  ///
  ///  * [WillPopScope], another widget that provides a way to intercept the
  ///    back button.
  final WillPopCallback? onWillPop;

  /// Called when one of the form fields changes.
  ///
  /// In addition to this callback being invoked, all the form fields themselves
  /// will rebuild.
  final VoidCallback? onChanged;

  /// Used to enable/disable form fields auto validation and update their error
  /// text.
  ///
  /// {@macro flutter.widgets.FormField.autovalidateMode}
  final AsyncAutovalidateMode autovalidateMode;

  /// Used to enable/disable form fields auto validation and update their error
  /// text.
  @Deprecated(
    'Use autovalidateMode parameter which provides more specific '
        'behavior related to auto validation. '
        'This feature was deprecated after v1.19.0.',
  )
  final bool autovalidate;

  @override
  AsyncFormState createState() => AsyncFormState();
}

/// State associated with a [AsyncForm] widget.
///
/// A [AsyncFormState] object can be used to [save], [reset], and [validate] every
/// [AsyncFormField] that is a descendant of the associated [AsyncForm].
///
/// Typically obtained via [AsyncForm.of].
class AsyncFormState extends State<AsyncForm> {
  int _generation = 0;
  bool _hasInteractedByUser = false;
  final Set<AsyncFormFieldState<dynamic>> _fields = <AsyncFormFieldState<dynamic>>{};

  // Called when a form field has changed. This will cause all form fields
  // to rebuild, useful if form fields have interdependencies.
  void _fieldDidChange() {
    widget.onChanged?.call();

    _hasInteractedByUser = _fields
        .any((AsyncFormFieldState<dynamic> field) => field._hasInteractedByUser.value);
    _forceRebuild();
  }

  void _forceRebuild() {
    setState(() {
      ++_generation;
    });
  }

  void _register(AsyncFormFieldState<dynamic> field) {
    _fields.add(field);
  }

  void _unregister(AsyncFormFieldState<dynamic> field) {
    _fields.remove(field);
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.autovalidateMode) {
      case AsyncAutovalidateMode.always:
        _validate();
        break;
      case AsyncAutovalidateMode.onUserInteraction:
        if (_hasInteractedByUser) {
          _validate();
        }
        break;
      case AsyncAutovalidateMode.disabled:
        break;
    }

    return WillPopScope(
      onWillPop: widget.onWillPop,
      child: _AsyncFormScope(
        formState: this,
        generation: _generation,
        child: widget.child,
      ),
    );
  }

  /// Saves every [AsyncFormField] that is a descendant of this [AsyncForm].
  void save() {
    for (final AsyncFormFieldState<dynamic> field in _fields)
      field.save();
  }

  /// Resets every [AsyncFormField] that is a descendant of this [AsyncForm] back to its
  /// [AsyncFormField.initialValue].
  ///
  /// The [AsyncForm.onChanged] callback will be called.
  ///
  /// If the form's [AsyncForm.autovalidateMode] property is [AsyncAutovalidateMode.always],
  /// the fields will all be revalidated after being reset.
  void reset() {
    for (final AsyncFormFieldState<dynamic> field in _fields)
      field.reset();
    _hasInteractedByUser = false;
    _fieldDidChange();
  }

  /// Validates every [AsyncFormField] that is a descendant of this [AsyncForm], and
  /// returns true if there are no errors.
  ///
  /// The form will rebuild to report the results.
  Future<bool> validate() async {
    _hasInteractedByUser = true;
    _forceRebuild();
    return await _validate();
  }

  Future<bool> _validate() async{
    bool hasError = false;
    for (final AsyncFormFieldState<dynamic> field in _fields)
      hasError = (await !field.validate()) || hasError;
    return !hasError;
  }
}

class _AsyncFormScope extends InheritedWidget {
  const _AsyncFormScope({
    Key? key,
    required Widget child,
    required AsyncFormState formState,
    required int generation,
  }) : _formState = formState,
        _generation = generation,
        super(key: key, child: child);

  final AsyncFormState _formState;

  /// Incremented every time a form field has changed. This lets us know when
  /// to rebuild the form.
  final int _generation;

  /// The [AsyncForm] associated with this widget.
  AsyncForm get form => _formState.widget;

  @override
  bool updateShouldNotify(_AsyncFormScope old) => _generation != old._generation;
}

/// Signature for validating a form field.
///
/// Returns an error string to display if the input is invalid, or null
/// otherwise.
///
/// Used by [AsyncFormField.validator].
typedef AsyncFormFieldValidator<T> = Future<String?> Function(T? value);

/// Signature for being notified when a form field changes value.
///
/// Used by [AsyncFormField.onSaved].
typedef AsyncFormFieldSetter<T> = void Function(T? newValue);

/// Signature for building the widget representing the form field.
///
/// Used by [AsyncFormField.builder].
typedef AsyncFormFieldBuilder<T> = Widget Function(AsyncFormFieldState<T> field);

/// A single form field.
///
/// This widget maintains the current state of the form field, so that updates
/// and validation errors are visually reflected in the UI.
///
/// When used inside a [AsyncForm], you can use methods on [AsyncFormState] to query or
/// manipulate the form data as a whole. For example, calling [AsyncFormState.save]
/// will invoke each [AsyncFormField]'s [onSaved] callback in turn.
///
/// Use a [GlobalKey] with [AsyncFormField] if you want to retrieve its current
/// state, for example if you want one form field to depend on another.
///
/// A [AsyncForm] ancestor is not required. The [AsyncForm] simply makes it easier to
/// save, reset, or validate multiple fields at once. To use without a [AsyncForm],
/// pass a [GlobalKey] to the constructor and use [GlobalKey.currentState] to
/// save or reset the form field.
///
/// See also:
///
///  * [AsyncForm], which is the widget that aggregates the form fields.
///  * [TextField], which is a commonly used form field for entering text.
class AsyncFormField<T> extends StatefulWidget {
  /// Creates a single form field.
  ///
  /// The [builder] argument must not be null.
  const AsyncFormField({
    Key? key,
    required this.builder,
    this.onSaved,
    this.validator,
    this.initialValue,
    @Deprecated(
      'Use autovalidateMode parameter which provides more specific '
          'behavior related to auto validation. '
          'This feature was deprecated after v1.19.0.',
    )
    this.autovalidate = false,
    this.enabled = true,
    AsyncAutovalidateMode? autovalidateMode,
    this.restorationId,
  }) : assert(builder != null),
        assert(
        autovalidate == false ||
            autovalidate == true && autovalidateMode == null,
        'autovalidate and autovalidateMode should not be used together.',
        ),
        autovalidateMode = autovalidateMode ??
            (autovalidate ? AsyncAutovalidateMode.always : AsyncAutovalidateMode.disabled),
        super(key: key);

  /// An optional method to call with the final value when the form is saved via
  /// [AsyncFormState.save].
  final AsyncFormFieldSetter<T>? onSaved;

  /// An optional method that validates an input. Returns an error string to
  /// display if the input is invalid, or null otherwise.
  ///
  /// The returned value is exposed by the [AsyncFormFieldState.errorText] property.
  /// The [TextFormField] uses this to override the [InputDecoration.errorText]
  /// value.
  ///
  /// Alternating between error and normal state can cause the height of the
  /// [TextFormField] to change if no other subtext decoration is set on the
  /// field. To create a field whose height is fixed regardless of whether or
  /// not an error is displayed, either wrap the  [TextFormField] in a fixed
  /// height parent like [SizedBox], or set the [InputDecoration.helperText]
  /// parameter to a space.
  final AsyncFormFieldValidator<T>? validator;

  /// Function that returns the widget representing this form field. It is
  /// passed the form field state as input, containing the current value and
  /// validation state of this field.
  final AsyncFormFieldBuilder<T> builder;

  /// An optional value to initialize the form field to, or null otherwise.
  final T? initialValue;

  /// Whether the form is able to receive user input.
  ///
  /// Defaults to true. If [autovalidateMode] is not [AsyncAutovalidateMode.disabled],
  /// the field will be auto validated. Likewise, if this field is false, the widget
  /// will not be validated regardless of [autovalidateMode].
  final bool enabled;

  /// Used to enable/disable this form field auto validation and update its
  /// error text.
  ///
  /// {@template flutter.widgets.FormField.autovalidateMode}
  /// If [AsyncAutovalidateMode.onUserInteraction] this form field will only
  /// auto-validate after its content changes, if [AsyncAutovalidateMode.always] it
  /// will auto validate even without user interaction and
  /// if [AsyncAutovalidateMode.disabled] the auto validation will be disabled.
  ///
  /// Defaults to [AsyncAutovalidateMode.disabled] if `autovalidate` is false which
  /// means no auto validation will occur. If `autovalidate` is true then this
  /// is set to [AsyncAutovalidateMode.always] for backward compatibility.
  /// {@endtemplate}
  final AsyncAutovalidateMode autovalidateMode;

  /// Used to enable/disable auto validation and update their error
  /// text.
  @Deprecated(
    'Use autovalidateMode parameter which provides more specific '
        'behavior related to auto validation. '
        'This feature was deprecated after v1.19.0.',
  )
  final bool autovalidate;

  /// Restoration ID to save and restore the state of the form field.
  ///
  /// Setting the restoration ID to a non-null value results in whether or not
  /// the form field validation persists.
  ///
  /// The state of this widget is persisted in a [RestorationBucket] claimed
  /// from the surrounding [RestorationScope] using the provided restoration ID.
  ///
  /// See also:
  ///
  ///  * [RestorationManager], which explains how state restoration works in
  ///    Flutter.
  final String? restorationId;

  @override
  AsyncFormFieldState<T> createState() => AsyncFormFieldState<T>();
}

/// The current state of a [AsyncFormField]. Passed to the [AsyncFormFieldBuilder] method
/// for use in constructing the form field's widget.
class AsyncFormFieldState<T> extends State<AsyncFormField<T>> with RestorationMixin {
  late T? _value = widget.initialValue;
  final RestorableStringN _errorText = RestorableStringN(null);
  final RestorableBool _hasInteractedByUser = RestorableBool(false);

  /// The current value of the form field.
  T? get value => _value;

  /// The current validation error returned by the [AsyncFormField.validator]
  /// callback, or null if no errors have been triggered. This only updates when
  /// [validate] is called.
  String? get errorText => _errorText.value;

  /// True if this field has any validation errors.
  bool get hasError => _errorText.value != null;

  /// True if the current value is valid.
  ///
  /// This will not set [errorText] or [hasError] and it will not update
  /// error display.
  ///
  /// See also:
  ///
  ///  * [validate], which may update [errorText] and [hasError].
  bool get isValid => widget.validator?.call(_value) == null;

  /// Calls the [AsyncFormField]'s onSaved method with the current value.
  void save() {
    widget.onSaved?.call(value);
  }

  /// Resets the field to its initial value.
  void reset() {
    setState(() {
      _value = widget.initialValue;
      _hasInteractedByUser.value = false;
      _errorText.value = null;
    });
    AsyncForm.of(context)?._fieldDidChange();
  }

  /// Calls [AsyncFormField.validator] to set the [errorText]. Returns true if there
  /// were no errors.
  ///
  /// See also:
  ///
  ///  * [isValid], which passively gets the validity without setting
  ///    [errorText] or [hasError].
  bool validate() {
    setState(() {
      _validate();
    });
    return !hasError;
  }

  Future<void> _validate()async{
    if (widget.validator != null)
      _errorText.value = await widget.validator!(_value);
  }

  /// Updates this field's state to the new value. Useful for responding to
  /// child widget changes, e.g. [Slider]'s [Slider.onChanged] argument.
  ///
  /// Triggers the [AsyncForm.onChanged] callback and, if [AsyncForm.autovalidateMode] is
  /// [AsyncAutovalidateMode.always] or [AsyncAutovalidateMode.onUserInteraction],
  /// revalidates all the fields of the form.
  void didChange(T? value) {
    setState(() {
      _value = value;
      _hasInteractedByUser.value = true;
    });
    AsyncForm.of(context)?._fieldDidChange();
  }

  /// Sets the value associated with this form field.
  ///
  /// This method should only be called by subclasses that need to update
  /// the form field value due to state changes identified during the widget
  /// build phase, when calling `setState` is prohibited. In all other cases,
  /// the value should be set by a call to [didChange], which ensures that
  /// `setState` is called.
  @protected
  void setValue(T? value) {
    _value = value;
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_errorText, 'error_text');
    registerForRestoration(_hasInteractedByUser, 'has_interacted_by_user');
  }

  @override
  void deactivate() {
    AsyncForm.of(context)?._unregister(this);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      switch (widget.autovalidateMode) {
        case AsyncAutovalidateMode.always:
          _validate();
          break;
        case AsyncAutovalidateMode.onUserInteraction:
          if (_hasInteractedByUser.value) {
            _validate();
          }
          break;
        case AsyncAutovalidateMode.disabled:
          break;
      }
    }
    AsyncForm.of(context)?._register(this);
    return widget.builder(this);
  }
}

/// Used to configure the auto validation of [AsyncFormField] and [AsyncForm] widgets.
enum AsyncAutovalidateMode {
  /// No auto validation will occur.
  disabled,

  /// Used to auto-validate [AsyncForm] and [AsyncFormField] even without user interaction.
  always,

  /// Used to auto-validate [AsyncForm] and [AsyncFormField] only after each user
  /// interaction.
  onUserInteraction,
}