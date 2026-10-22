import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_chat_transport.dart';
import 'package:nexa_sdk/src/data/gateway/nexa_gateway_api.dart';
import 'package:nexa_sdk/src/data/network/dio_factory.dart';
import 'package:nexa_sdk/src/nexa_overrides.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

/// Injectable module for the SDK's internal object graph.
///
/// `NexaConfig`, `NexaAuthProvider` and `NexaOverrides` are registered by
/// `SdkInjector` before `initSdkScope` runs, because they are runtime values
/// supplied by the host.
@module
abstract class SdkModule {
  @lazySingleton
  NexaLogger logger(NexaOverrides overrides) =>
      overrides.logger ?? const NoopNexaLogger();

  @lazySingleton
  NexaPermissionHandler permissionHandler(NexaOverrides overrides) =>
      overrides.permissionHandler ?? const DenyAllPermissionHandler();

  @lazySingleton
  CredentialManager credentialManager(NexaAuthProvider provider) =>
      CredentialManager(provider);

  @lazySingleton
  Dio dio(
    NexaConfig config,
    CredentialManager credentials,
    NexaLogger logger,
  ) => DioFactory.create(
    config: config,
    credentials: credentials,
    logger: logger,
  );

  @lazySingleton
  NexaGatewayApi gatewayApi(Dio dio) => NexaGatewayApi(dio);

  /// The override wins; otherwise the (proposed) gateway transport.
  @lazySingleton
  ChatTransport chatTransport(
    NexaOverrides overrides,
    NexaConfig config,
    NexaLogger logger,
    NexaGatewayApi api,
    Dio dio,
  ) {
    final override = overrides.chatTransport;
    if (override != null) {
      if (config.environment != NexaEnvironment.development) {
        logger.log(
          NexaLogLevel.warning,
          'A ChatTransport override is active outside development. '
          'Mocks must never ship in production builds.',
        );
      }
      return override;
    }
    return GatewayChatTransport(
      api: api,
      dio: dio,
      config: config,
      logger: logger,
    );
  }

  @lazySingleton
  SessionManager sessionManager(
    ChatTransport transport,
    CredentialManager credentials,
    NexaConfig config,
    NexaLogger logger,
  ) => SessionManager(
    transport: transport,
    credentials: credentials,
    config: config,
    logger: logger,
  );

  @lazySingleton
  ConversationReducer reducer() => const ConversationReducer();
}
