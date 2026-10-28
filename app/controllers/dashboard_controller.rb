class DashboardController < ApplicationController
  def show
    @account = current_user.whatsapp_account
    @templates = current_user.templates
    @campaigns = current_user.campaigns.includes(:template).order(updated_at: :desc).limit(6)
  end
end
