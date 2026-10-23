import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/di/sdk_injector.config.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/nexa_overrides.dart';

/// Builds an **isolated** `GetIt` container for one `NexaClient`.
///
/// The SDK never touches `GetIt.instance`, so a host app that also uses
/// get_it cannot collide with SDK registrations and the SDK can be disposed
/// and re-initialised cleanly.
@InjectableInit(
  initializerName: 'initSdkScope',
  preferRelativeImports: false,
  asExtension: true,
)
GetIt buildSdkInjector({
  required NexaConfig config,
  required NexaAuthProvider authProvider,
  required NexaOverrides overrides,
  NexaVoiceOptions voiceOptions = const NexaVoiceOptions(),
}) {
  final getIt = GetIt.asNewInstance()
    ..registerSingleton<NexaConfig>(config)
    ..registerSingleton<NexaAuthProvider>(authProvider)
    ..registerSingleton<NexaOverrides>(overrides)
    ..registerSingleton<NexaVoiceOptions>(voiceOptions);
  return getIt.initSdkScope();
}
