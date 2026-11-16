# Passwordless sign-in in the shape of Rails 8's authentication generator:
# every action needs a signed-in guest unless its controller calls
# allow_unauthenticated_access. Browsers carry a session cookie; API calls can
# pass api_key instead, as on SerpApi.
module Authentication
  extend ActiveSupport::Concern

  SESSION_LIFETIME = 30.days

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.user ||= (find_user_by_cookie || find_user_by_api_key)&.tap(&:seen!)
  end

  def find_user_by_cookie
    return unless (id = cookies.signed[:session_id])

    Current.session = Session.where(_id: id).first
    Current.session&.user&.then { |user| user if user.guest? }
  end

  def find_user_by_api_key
    return if params[:api_key].blank?

    User.where(api_key: params[:api_key].to_s).first&.then { |user| user if user.guest? }
  end

  def request_authentication
    if request.format.json?
      render json: { error: "Invalid API key. Sign in at #{sign_in_url} and your key is in the playground." }, status: :unauthorized
    else
      session[:return_to_after_authenticating] = request.url if request.get?
      redirect_to sign_in_path
    end
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || playground_url
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: client_ip).tap do |new_session|
      Current.session = new_session
      Current.user = user
      cookies.signed[:session_id] = { value: new_session.id.to_s, httponly: true, same_site: :lax, expires: SESSION_LIFETIME }
    end
  end

  def terminate_session
    Current.session&.delete
    cookies.delete(:session_id)
  end
end
