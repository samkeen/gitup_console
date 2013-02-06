require 'net/smtp'

class HtmlMailer

  def send_email(to,opts={})
    opts[:server]      ||= 'localhost'
    opts[:from]        ||= 'example@example.com'
    opts[:from_alias]  ||= 'Example Emailer'
    opts[:subject]     ||= "You need to see this"
    opts[:body]        ||= "Important stuff!"

    msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
MIME-Version: 1.0
Content-type: text/html
Subject: #{opts[:subject]}

    #{opts[:body]}
END_OF_MESSAGE

    Net::SMTP.start(opts[:server]) do |smtp|
      smtp.send_message msg, opts[:from], to
    end
  end
end