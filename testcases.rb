# sends a XEP 0217 encrypted session request
class E2eNegotiation < TestCase
  def call
    playback 'xep217'
  end
end

# sends a message with a XEP 0184 message receipt request
class ReceiptRequest < TestCase
  def call
    playback 'receipt_request'
  end
end

# sends a XEP-0199 client-to-client ping
class ClientToClientPing < TestCase
  def call
    playback 'xmpp_ping'
  end
end
