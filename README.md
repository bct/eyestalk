# eyestalk #

a bot for testing an XMPP client for presence leaks

## usage ##

    ./eyestalk.rb bot@example.org password

## dependencies ##

- ruby
- xmpp4r

## writing test cases ##

A test case looks like this:

    class ClientToClientPing < TestCase
      def call
        playback 'xmpp_ping'
      end
    end

The method `playback` looks for a list of stanzas in ./data/stanzas/xmpp_ping.xml, attaches a `to=` attribute to the root of each and sends it to the JID that requested a test.

Any message received from the tested JID is considered a failure. In order to tell which test case caused the client to respond, the suite waits `TIMEOUT` seconds before continuing to the next test.
