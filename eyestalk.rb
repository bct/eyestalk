#!/usr/bin/env ruby

require 'xmpp4r'

# wait 10 seconds for a reply
TIMEOUT = 10

# how often to check for messages
INTERVAL = 1

class TestSession
  attr_reader :jid

  def initialize(client, jid)
    @client = client
    @jid = jid

    # the list of tests we still have to do
    @queue = [E2eNegotiation, ReceiptRequest]

    send 'beginning tests.'

    proceed
  end

  # we received a message, the test fails
  def received msg
    send <<END
I see you!
failed test: #{@current_test.inspect}
END

    send <<END
  you sent:
#{msg}
END
  end

  def proceed
    if @queue.empty?
      send 'all tests are done. send another message to start from the beginning.'
      @client.end_session(@jid.to_s)

      return
    end

    klass = @queue.shift

    @current_test = klass.new(self)

    @current_test.call

    Thread.new do
      # wait TIMEOUT seconds to receive a message, then begin the next test
      sleep TIMEOUT
      proceed
    end
  end

  def send(msg)
    if msg.is_a? String
      msg = Jabber::Message.new(@jid, msg)
      msg.type = :chat
    end

    @client.send(msg)
  end
end

# a set of actions that might cause a presence leak
class TestCase
  def initialize(session)
    @session = session
    @jid = session.jid
  end

  def send *args
    @session.send *args
  end

  def inspect
    "#<#{self.class}>"
  end
end

# sends a XEP 0217 encrypted session request
class E2eNegotiation < TestCase
  def call
    m = Jabber::Message.new(@jid)
    d = REXML::Document.new <<END
<feature xmlns='http://jabber.org/protocol/feature-neg'>
<x type='form' xmlns='jabber:x:data'>
  <field type='hidden' var='FORM_TYPE'>
    <value>urn:xmpp:ssn</value>
  </field>
  <field type='boolean' var='accept'>
    <value>1</value>
    <required/>
  </field>
  <field type='list-single' var='otr'>
    <option><value>false</value></option>
    <option><value>true</value></option>
    <required/>
  </field>
  <field type='list-single' var='disclosure'>
    <option><value>never</value></option>
    <required/>
  </field>
  <field type='list-single' var='security'>
    <option><value>e2e</value></option>
    <option><value>c2s</value></option>
    <required/>
  </field>
  <field type='list-single' var='modp'>
    <option><value>5</value></option>
    <option><value>14</value></option>
    <option><value>2</value></option>
    <option><value>1</value></option>
  </field>
  <field type='hidden' var='crypt_algs'>
    <value>aes128-ctr</value>
  </field>
  <field type='hidden' var='hash_algs'>
    <value>sha256</value>
  </field>
  <field type='hidden' var='compress'>
    <value>none</value>
  </field>
  <field type='list-multi' var='stanzas'>
    <option><value>message</value></option>
    <option><value>iq</value></option>
    <option><value>presence</value></option>
  </field>
  <field type='hidden' var='init_pubkey'>
    <value>none</value>
  </field>
  <field type='hidden' var='resp_pubkey'>
    <value>none</value>
  </field>
  <field type='list-single' var='ver'>
    <option><value>1.3</value></option>
    <option><value>1.2</value></option>
  </field>
  <field type='hidden' var='rekey_freq'>
    <value>4294967295</value>
  </field>
  <field type='hidden' var='my_nonce'>
    <value>MA==</value>
  </field>
  <field type='hidden' var='sas_algs'>
    <value>sas28x5</value>
  </field>
  <field type='hidden' var='dhhashes'>
    <value>MA==</value>
    <value>MA==</value>
    <value>MA==</value>
    <value>MA==</value>
  </field>
</x>
</feature>
END

    m.add d.root
    send(m)
  end
end

# sends a message with a XEP 0184 message receipt request
class ReceiptRequest < TestCase
  def call
    m = Jabber::Message.new(@jid)
    d = REXML::Document.new <<END
<request xmlns='urn:xmpp:receipts'/>
END

    m.add d.root
    send(m)
  end
end

class TestBot < Jabber::Client
  def initialize(jid, passwd)
    super(jid)

    @sessions = {}

    self.connect
    self.auth(passwd)
    self.send(Jabber::Presence.new)

    self.add_message_callback do |msg|
      fjid = msg.from.to_s

      begin
        if @sessions[fjid]
          @sessions[fjid].received(msg)
        else
          @sessions[fjid] = TestSession.new(self, fjid)
        end
      rescue e
        puts "EXCEPTION!"
        puts msg.inspect
        puts e.inspect
      end
    end
  end

  def end_session fjid
    @sessions[fjid] = nil
  end
end

if __FILE__ == $0
  jid = ARGV[0]
  passwd = ARGV[1]

  client = TestBot.new(jid, passwd)

  Thread.stop
end
