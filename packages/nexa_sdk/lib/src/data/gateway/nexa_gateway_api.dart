import 'package:dio/dio.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_dtos.dart';
import 'package:retrofit/retrofit.dart';

part 'nexa_gateway_api.g.dart';

/// Typed client for the **proposed** NEXA gateway SDK surface.
///
/// STATUS: PROPOSED. No gateway deployment exists; these paths are the
/// contract handed to the backend team
/// (`docs/contracts/nexa-gateway-api.proposed.yaml`). The GPU Manager is never
/// called from here: it sits behind the gateway.
@RestApi()
abstract class NexaGatewayApi {
  factory NexaGatewayApi(Dio dio, {String? baseUrl}) = _NexaGatewayApi;

  @POST('/v1/sdk/sessions')
  Future<SessionDto> createSession(@Body() CreateSessionRequestDto body);

  /// Long-poll for events after [after]. The server holds the request up to
  /// [waitMs] when nothing is pending. (SSE is the preferred upgrade path.)
  @GET('/v1/sdk/sessions/{sessionId}/events')
  Future<EventPageDto> pollEvents(
    @Path('sessionId') String sessionId,
    @Query('after') int after,
    @Query('wait_ms') int waitMs,
  );

  @POST('/v1/sdk/sessions/{sessionId}/messages')
  Future<void> postMessage(
    @Path('sessionId') String sessionId,
    @Body() MessageRequestDto body,
    @Header('Idempotency-Key') String idempotencyKey,
  );

  @POST('/v1/sdk/sessions/{sessionId}/tool-actions')
  Future<void> postToolAction(
    @Path('sessionId') String sessionId,
    @Body() Map<String, Object?> action,
  );

  @POST('/v1/sdk/sessions/{sessionId}/permissions/{requestId}')
  Future<void> reportPermission(
    @Path('sessionId') String sessionId,
    @Path('requestId') String requestId,
    @Body() PermissionResultDto body,
  );

  @POST('/v1/sdk/sessions/{sessionId}/messages/{messageId}/cancel')
  Future<void> cancelMessage(
    @Path('sessionId') String sessionId,
    @Path('messageId') String messageId,
  );

  @DELETE('/v1/sdk/sessions/{sessionId}')
  Future<void> endSession(@Path('sessionId') String sessionId);
}
