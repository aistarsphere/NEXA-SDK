/// Deployment environment the SDK targets.
///
/// Gateway base URLs are **not** hard-coded per environment because no NEXA
/// gateway deployment exists yet. The host app supplies `gatewayBaseUri`
/// explicitly; the environment only tunes defaults (timeouts, logging).
enum NexaEnvironment {
  /// Local or shared development gateway. Verbose logging allowed.
  development,

  /// Pre-production gateway with production-like policies.
  staging,

  /// Production gateway. Diagnostic logging is minimised.
  production;

  /// Whether verbose SDK diagnostics are allowed by default.
  bool get allowsVerboseLogging => this != NexaEnvironment.production;
}
