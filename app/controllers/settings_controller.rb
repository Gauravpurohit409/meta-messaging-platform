class SettingsController < ApplicationController
  def show
    @account = current_user.whatsapp_account
  end

  def update
    @account = current_user.whatsapp_account
    attributes = account_params
    attributes.delete(:access_token) if attributes[:access_token].blank?

    if @account.update(attributes)
      redirect_to settings_path, notice: "WhatsApp connection saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def regenerate_verify_token
    current_user.whatsapp_account.regenerate_verify_token!
    redirect_to settings_path, notice: "Verify token replaced. Paste the new one into the Meta webhook form."
  end

  private

  def account_params
    params.require(:whatsapp_account).permit(:demo_mode, :waba_id, :phone_number_id, :display_phone, :access_token)
  end
end
