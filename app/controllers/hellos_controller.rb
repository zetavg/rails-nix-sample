class HellosController < ActionController::Base
  def create
    data = { time: Time.current, ip: request.remote_ip }
    data[:message] = params[:message] if params[:message].present?
    ActionCable.server.broadcast 'hello_messages', data
    head :ok
  end
end
