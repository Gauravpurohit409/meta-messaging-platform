class DataDeletionController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @request = DataDeletionRequest.find_by!(confirmation_code: params[:code])
  end
end
