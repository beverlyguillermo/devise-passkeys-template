# frozen_string_literal: true
require 'devise'

class Devise::Passkeys::RegistrationsController < Devise::RegistrationsController
  include Devise::Passkeys::Concerns::PasskeyReauthentication
  include Warden::WebAuthn::RegistrationHelpers

  before_action :require_no_authentication, only: [:new_challenge]
  before_action :require_email_and_passkey_label, only: [:new_challenge, :create]
  before_action :verify_passkey_registration_challenge, only: [:create]
  before_action :configure_sign_up_params, only: [:create]

  before_action :verify_reauthentication_token, only: [:update, :destroy]

  def new_challenge
    options_for_registration = generate_registration_options(
      relying_party: relying_party,
      user_details: user_details_for_registration,
      exclude: exclude_external_ids_for_registration,
    )

    store_challenge_in_session(options_for_registration: options_for_registration)

    render json: options_for_registration
  end

  def create
    super do |resource|
      if resource.persisted?
        passkey = resource.passkeys.create!(
          label: passkey_params[:passkey_label],
          public_key: @webauthn_credential.public_key,
          external_id: Base64.strict_encode64(@webauthn_credential.raw_id),
          sign_count: @webauthn_credential.sign_count,
          last_used_at: Time.now.utc
        )

        yield [resource, passkey] if block_given?
        delete_registration_user_id!
      end
    end
  end

  protected

  def verify_reauthentication_token
    if !valid_reauthentication_token?(given_reauthentication_token: reauthentication_params[:reauthentication_token])
      render json: {error: find_message(:not_reauthenticated)}, status: :bad_request
    end
  end

  def reauthentication_params
    params.require(:user).permit(:reauthentication_token)
  end

  def update_resource(resource, params)
    resource.update(params)
  end

  # Override if you need to exclude certain external IDs
  def exclude_external_ids_for_registration
    []
  end

  def raw_credential
    passkey_params[:passkey_credential]
  end

  def passkey_params
    params.require(resource_name).permit(:passkey_label, :passkey_credential)
  end

  def require_email_and_passkey_label
    if sign_up_params[:email].blank?
      render json: {message: find_message(:email_missing)}, status: :bad_request
      return false
    end

    if passkey_params[:passkey_label].blank?
      render json: {message: find_message(:passkey_label_missing)}, status: :bad_request
      return false
    end

    return true
  end

  def verify_passkey_registration_challenge
    begin
      @webauthn_credential = verify_registration(relying_party: relying_party)
    rescue ::WebAuthn::Error => e
      error_key = Warden::WebAuthn::ErrorKeyFinder.webauthn_error_key(exception: e)
      render json: {message: find_message(error_key)}, status: :bad_request
    end
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    params[:user][:webauthn_id] = registration_user_id
    devise_parameter_sanitizer.permit(:sign_up, keys: [:webauthn_id])
  end

  def user_details_for_registration
    store_registration_user_id
    { id: registration_user_id, name: sign_up_params[:email] }
  end

  def registration_user_id
    session[registration_user_id_key]
  end

  def delete_registration_user_id!
    session.delete(registration_user_id_key)
  end

  def store_registration_user_id
    session[registration_user_id_key] = WebAuthn.generate_user_id
  end

  def registration_user_id_key
    "#{resource_name}_current_webauthn_user_id"
  end

  def registration_challenge_key
    "#{resource_name}_current_webauthn_registration_challenge"
  end
end