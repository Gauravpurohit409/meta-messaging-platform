class SettingsController < ApplicationController
  def show
    @account = current_user.whatsapp_account
  end

  def update
    @account = current_user.whatsapp_account
    if params.dig(:whatsapp_account, :demo_mode).to_s == "0"
      @account.errors.add(:base, "Use Embedded Signup to connect a live WhatsApp account.")
      render :show, status: :unprocessable_entity
      return
    end

    attributes = account_params
    attributes.delete(:access_token) if attributes[:access_token].blank?
    attributes[:demo_mode] = true

    if @account.update(attributes)
      redirect_to settings_path, notice: "WhatsApp connection saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def connect
    @account = current_user.whatsapp_account
    unless Meta::AppConfig.embedded_signup_ready?
      @account.errors.add(:base, "Embedded Signup is not configured")
      render :show, status: :unprocessable_entity
      return
    end
    unless Meta::EmbeddedSignup.acceptable?(code: params[:code], waba_id: params[:waba_id], phone_number_id: params[:phone_number_id])
      @account.errors.add(:base, "Check the signup code and account ids, then try again.")
      render :show, status: :unprocessable_entity
      return
    end

    if Meta::EmbeddedSignup.connect(account: @account, code: params[:code], waba_id: params[:waba_id], phone_number_id: params[:phone_number_id])
      redirect_to settings_path, notice: "WhatsApp connected."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def disconnect
    @account = current_user.whatsapp_account
    if Meta::EmbeddedSignup.disconnect(account: @account)
      redirect_to settings_path, notice: "WhatsApp disconnected."
    else
      redirect_to settings_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  private

  def account_params
    params.require(:whatsapp_account).permit(:demo_mode, :waba_id, :phone_number_id, :display_phone, :access_token)
  end
end
