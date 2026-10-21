# FORK: never contact hub.2.chatwoot.com. sync_with_hub is the only path that can
# rewrite INSTALLATION_PRICING_PLAN (Enterprise::Internal::CheckNewVersionsJob
# ignores `locked`), so it must stay inert even if upstream re-schedules the job.
# This is the code layer of the telemetry block; /etc/hosts + iptables + the
# DISABLE_TELEMETRY env var are the others. send_push is left alone: push relay
# is gated by ENABLE_PUSH_RELAY_SERVER.
module ForkDisableChatwootHub
  # Callers index the result (`['version']`), so return an empty hash, not nil.
  def sync_with_hub
    {}
  end

  def register_instance(*); end

  def emit_event(*); end
end

Rails.application.config.to_prepare do
  ChatwootHub.singleton_class.prepend(ForkDisableChatwootHub)
end
