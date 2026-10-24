// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:nexa_core/nexa_core.dart' as _i829;
import 'package:nexa_sdk/src/data/gateway/nexa_gateway_api.dart' as _i969;
import 'package:nexa_sdk/src/di/sdk_module.dart' as _i470;
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart' as _i292;
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart'
    as _i1004;
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart' as _i131;
import 'package:nexa_sdk/src/nexa_overrides.dart' as _i480;
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart' as _i668;
import 'package:nexa_sdk/src/session/session_manager.dart' as _i1027;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt initSdkScope({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final sdkModule = _$SdkModule();
    gh.lazySingleton<_i829.ConversationReducer>(() => sdkModule.reducer());
    gh.lazySingleton<_i829.CredentialManager>(
      () => sdkModule.credentialManager(gh<_i829.NexaAuthProvider>()),
    );
    gh.lazySingleton<_i829.NexaLogger>(
      () => sdkModule.logger(gh<_i480.NexaOverrides>()),
    );
    gh.lazySingleton<_i668.NexaPermissionHandler>(
      () => sdkModule.permissionHandler(gh<_i480.NexaOverrides>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => sdkModule.dio(
        gh<_i829.NexaConfig>(),
        gh<_i829.CredentialManager>(),
        gh<_i829.NexaLogger>(),
      ),
    );
    gh.lazySingleton<_i969.NexaGatewayApi>(
      () => sdkModule.gatewayApi(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i829.VoiceProvisioner>(
      () => sdkModule.voiceProvisioner(
        gh<_i480.NexaOverrides>(),
        gh<_i829.NexaConfig>(),
        gh<_i829.NexaLogger>(),
        gh<_i361.Dio>(),
        gh<_i131.NexaVoiceOptions>(),
      ),
    );
    gh.lazySingleton<_i829.RealtimeVoiceTransport>(
      () => sdkModule.voiceTransport(
        gh<_i480.NexaOverrides>(),
        gh<_i829.NexaConfig>(),
        gh<_i829.NexaLogger>(),
      ),
    );
    gh.lazySingleton<_i829.ChatTransport>(
      () => sdkModule.chatTransport(
        gh<_i480.NexaOverrides>(),
        gh<_i829.NexaConfig>(),
        gh<_i829.NexaLogger>(),
        gh<_i969.NexaGatewayApi>(),
        gh<_i361.Dio>(),
      ),
    );
    gh.lazySingleton<_i1027.SessionManager>(
      () => sdkModule.sessionManager(
        gh<_i829.ChatTransport>(),
        gh<_i829.CredentialManager>(),
        gh<_i829.NexaConfig>(),
        gh<_i829.NexaLogger>(),
      ),
    );
    gh.factory<_i292.ChatBloc>(
      () => _i292.ChatBloc(
        gh<_i1027.SessionManager>(),
        gh<_i829.ConversationReducer>(),
        gh<_i668.NexaPermissionHandler>(),
        gh<_i829.NexaLogger>(),
        gh<_i829.NexaConfig>(),
      ),
    );
    gh.lazySingleton<_i1004.NexaVoiceController>(
      () => sdkModule.voiceController(
        gh<_i1027.SessionManager>(),
        gh<_i829.VoiceProvisioner>(),
        gh<_i829.RealtimeVoiceTransport>(),
        gh<_i668.NexaPermissionHandler>(),
        gh<_i829.NexaLogger>(),
        gh<_i131.NexaVoiceOptions>(),
        gh<_i829.NexaConfig>(),
      ),
    );
    return this;
  }
}

class _$SdkModule extends _i470.SdkModule {}
