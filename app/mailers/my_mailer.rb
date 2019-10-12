class MyMailer < Devise::Mailer
  helper :application # gives access to all helpers defined within `application_helper`.
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
  default template_path: 'devise/mailer' # to make sure that your mailer uses the devise views

  def test_email
    mail(
        from: "no-reply@newseye.eu",
        to: "axel.jeancaurant@gmail.com",
        subject: "Test mail",
        body: "Test mail body"
    )
  end
end