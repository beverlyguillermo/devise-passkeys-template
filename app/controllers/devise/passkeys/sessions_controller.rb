# frozen_string_literal: true

class Devise::Passkeys::SessionsController < Devise::SessionsController
  include Warden::WebAuthn::AuthenticationInitiationHelpers
  include Warden::WebAuthn::StrategyHelpers

  # Prepending is crucial to ensure that the relying party is set in the
  # request.env before the strategy is executed
  prepend_before_action :set_relying_party_in_request_env

  def new_challenge
    options_for_authentication = generate_authentication_options(relying_party: relying_party)

    store_challenge_in_session(options_for_authentication: options_for_authentication)

    render json: options_for_authentication
  end

  protected

  def authentication_challenge_key
    "#{resource_name}_current_webauthn_authentication_challenge"
  end

  def set_relying_party_in_request_env
    raise RuntimeError, "need to define relying_party for this SessionsController"
  end
end