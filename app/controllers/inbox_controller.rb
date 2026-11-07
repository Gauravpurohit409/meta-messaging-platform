class InboxController < ApplicationController
  def index
    @messages = current_user.whatsapp_account.inbound_messages.order(received_at: :desc).limit(100)
  end
end
