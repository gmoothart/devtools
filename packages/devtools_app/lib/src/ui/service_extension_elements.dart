// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../globals.dart';
import '../service_extensions.dart';
import '../service_manager.dart' show ServiceExtensionState;
import '../service_registrations.dart';
import 'analytics.dart' as ga;
import 'html_elements.dart';
import 'primer.dart';

List<CoreElement> getServiceExtensionElements() {
  return [
    div(c: 'btn-group collapsible-985 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(slowAnimations).button,
      ]),
    div(c: 'btn-group collapsible-985 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(debugPaint).button,
        ServiceExtensionButton(debugPaintBaselines).button,
      ]),
    div(c: 'btn-group collapsible-1150 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(repaintRainbow).button,
        ServiceExtensionButton(debugAllowBanner).button,
      ]),
    div(c: 'btn-group nowrap margin-left')
      ..add(TogglePlatformSelector().selector)
  ];
}

/// Checkbox that stays synced with the value of a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
///
/// See also:
/// * ServiceExtensionButton, which provides the same functionality but uses
///   a button instead of a button. In general, using a button makes the UI
///   more compact but the checkbox makes the current state of the UI clearer.
class ServiceExtensionCheckbox {
  ServiceExtensionCheckbox(this.extensionDescription)
      : element = CoreElement('label') {
    final checkbox = CoreElement('input')..setAttribute('type', 'checkbox');
    _checkboxElement = checkbox.element;

    element.add(<CoreElement>[
      checkbox,
      span(text: ' ${extensionDescription.description}'),
    ]);

    final extensionName = extensionDescription.extension;

    // Disable button for unavailable service extensions.
    checkbox.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => checkbox.disabled = !available);

    _checkboxElement.onChange.listen((_) {
      ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

      final bool selected = _checkboxElement.checked;
      serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionDescription.extension,
        selected,
        selected
            ? extensionDescription.enabledValue
            : extensionDescription.disabledValue,
      );
    });
    _updateState();
  }

  final ToggleableServiceExtensionDescription extensionDescription;
  final CoreElement element;
  html.InputElement _checkboxElement;

  void _updateState() {
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      final extensionEnabled = state.value == extensionDescription.enabledValue;
      _checkboxElement.checked = extensionEnabled;
      // We display the tooltips in the reverse order they show up in
      // ServiceExtensionButton as for a checkbox it makes more sense to show
      // a tooltip for the current value instead of for the value clicking on
      // the button would switch to.
      element.tooltip = extensionEnabled
          ? extensionDescription.disabledTooltip
          : extensionDescription.enabledTooltip;
    });
  }
}

/// Button that calls a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
///
/// See also:
/// * ServiceExtensionCheckbox, which provides the same functionality but
///   uses a checkbox instead of a button. In general, using a checkbox makes
///   the state of the UI clearer but requires more space.
class ServiceExtensionButton {
  ServiceExtensionButton(this.extensionDescription)
      : button = PButton.icon(
          extensionDescription.description,
          extensionDescription.icon,
          title: extensionDescription.disabledTooltip,
        )..small() {
    final extensionName = extensionDescription.extension;

    // Disable button for unavailable service extensions.
    button.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => button.disabled = !available);

    button.click(() => _click());

    _updateState();
  }

  final ToggleableServiceExtensionDescription extensionDescription;
  final PButton button;

  void _click() {
    ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionDescription.extension,
      !wasSelected,
      wasSelected
          ? extensionDescription.disabledValue
          : extensionDescription.enabledValue,
    );
  }

  void _updateState() {
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      final extensionEnabled = state.value == extensionDescription.enabledValue;
      button.toggleClass('selected', extensionEnabled);
      button.tooltip = extensionEnabled
          ? extensionDescription.enabledTooltip
          : extensionDescription.disabledTooltip;
    });
  }
}

/// Button that calls a registered service from flutter_tools. Registered
/// services can be found in [service_registrations.dart].
class RegisteredServiceExtensionButton {
  RegisteredServiceExtensionButton(
    this.serviceDescription,
    this.action,
    this.errorAction,
  ) {
    button = PButton.icon(
      serviceDescription.title,
      serviceDescription.icon,
      title: serviceDescription.title,
    )
      ..small()
      ..hidden(true);

    // Only show the button if the device supports the given service.
    final serviceRegisteredListenable =
        serviceManager.registeredServiceListenable(serviceDescription.service);
    serviceRegisteredListenable.addListener(() {
      final registered = serviceRegisteredListenable.value;
      button.hidden(!registered);
    });

    button.click(() => _click());
  }

  final RegisteredServiceDescription serviceDescription;
  final Future<void> Function() action;
  final void Function(dynamic) errorAction;
  PButton button;

  void _click() async {
    try {
      button.disabled = true;
      await action();
    } catch (e) {
      errorAction(e);
    } finally {
      button.disabled = false;
    }
  }
}

/// Dropdown selector that calls a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
class ServiceExtensionSelector {
  ServiceExtensionSelector(this.extensionDescription) : selector = PSelect() {
    selector
      ..small()
      ..clazz('button-bar-dropdown')
      ..change(_handleSelect)
      ..tooltip = extensionDescription.tooltips.first ??
          extensionDescription.description;

    final extensionName = extensionDescription.extension;

    // Disable selector for unavailable service extensions.
    selector.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => selector.disabled = !available);

    addOptions();
    updateState();
  }

  final ServiceExtensionDescription extensionDescription;

  final PSelect selector;

  String _selectedValue;

  void _handleSelect() {
    if (selector.value == _selectedValue) return;

    ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

    final extensionValue = extensionDescription
        .values[extensionDescription.displayValues.indexOf(selector.value)];

    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionDescription.extension,
      true,
      extensionValue,
    );

    _selectedValue = selector.value;
  }

  void addOptions() {
    extensionDescription.displayValues.forEach(selector.option);
  }

  void updateState() {
    // Select option whose state is already enabled.
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      updateSelection(state);
    });
  }

  void updateSelection(ServiceExtensionState state) {
    if (state.value != null) {
      int selectedIndex = extensionDescription.values.indexOf(state.value);
      if (selectedIndex == -1) {
        // Gracefully handle unexpected extension description values by adding
        // them to the list of extension descriptions.
        // This is a bit of a hack but is acceptable for the dart:html version
        // of the application. In the Flutter version we should keep a list of
        // service extension descriptions separate form the core definition
        // of the extensions.
        extensionDescription.values.add(state.value);
        extensionDescription.displayValues.add(state.value);
        selectedIndex = extensionDescription.values.length - 1;
        selector.option(extensionDescription.displayValues[selectedIndex]);
      }
      selector.selectedIndex = selectedIndex;
      selector.element.children[selectedIndex].style.display = '';
      _selectedValue = extensionDescription.displayValues[selectedIndex];
    }
  }
}

class TogglePlatformSelector extends ServiceExtensionSelector {
  TogglePlatformSelector() : super(togglePlatformMode);

  static const fuchsia = 'Fuchsia';

  @override
  void addOptions() {
    super.addOptions();
    for (int i = 0; i < extensionDescription.values.length; i++) {
      if (extensionDescription.displayValues[i].contains(fuchsia)) {
        selector.element.children[i].style.display = 'none';
      }
    }
  }
}
