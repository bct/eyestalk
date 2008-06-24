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

    # the list of tests cases to run
    @queue = TestCase.subclasses

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

    wait_and_proceed
  end

  # wait TIMEOUT seconds to receive a message, then begin the next test
  def wait_and_proceed
    Thread.new do
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

  def send_raw(stanza)
    @client.send(stanza)
  end
end

# a set of actions that might cause a presence leak
class TestCase
  def initialize(session)
    @session = session
    @jid = session.jid
  end

  def inspect
    "#<#{self.class}>"
  end

  def send *args
    @session.send *args
  end

  # sends a prerecorded list of stanzas (stored in ./data/stanzas/record.xml)
  def playback(record_name)
    recorded = File.read("./data/stanzas/#{record_name}.xml")

    xml = REXML::Document.new('<root>' + recorded + '</root>')

    xml.root.elements.each do |stanza|
      stanza.attributes['to'] = @jid.to_s

      @session.send_raw(stanza)
    end
  end

  # keep track of this class' subclasses
  def self.inherited(subclass)
    if superclass.respond_to? :inherited
      superclass.inherited(subclass)
    end

    @subclasses ||= []
    @subclasses << subclass
  end

  def self.subclasses
    @subclasses
  end
end

require 'testcases'

class TestBot < Jabber::Client
  def initialize(jid, passwd)
    super(jid)

    @sessions = {}

    self.connect
    self.auth(passwd)
    self.send(Jabber::Presence.new)

    self.add_stanza_callback do |stanza|
      fjid = stanza.from.to_s

      begin
        if @sessions[fjid]
          @sessions[fjid].received(stanza)
        elsif stanza.is_a? Jabber::Message
          @sessions[fjid] = TestSession.new(self, fjid)
        end
      rescue => e
        puts "EXCEPTION!"
        puts stanza.inspect
        puts e.inspect
        puts e.backtrace
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
