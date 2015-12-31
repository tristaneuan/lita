require "spec_helper"

describe Lita::Handlers::Help, lita_handler: true do
  it { is_expected.to route_command("help").to(:help) }
  it { is_expected.to route_command("help foo").to(:help) }

  describe "#help" do
    let(:dummy_handler_class) do
      Class.new(Lita::Handler) do
        def self.name
          "Dummy"
        end

        route(/secret/, :secret, restrict_to: :the_nobodies, help: {
          "secret" => "This help message should be accompanied by a caveat"
        })
      end
    end

    before do
      registry.register_handler(dummy_handler_class)
      allow(Gem).to receive(:loaded_specs).and_return(
        { 'lita-dummy' => double('Gem', description: 'A dummy handler.') }
      )
      allow(robot.config.robot).to receive(:alias).and_return("!")
    end

    it "lists all installed handlers" do
      send_command("help")
      expect(replies.last).to match(/^Type '!help HANDLER'.+installed:\nHelp\nDummy: A dummy handler\.$/)
    end

    it "sends help information for all commands under a given handler" do
      send_command("help help")
      expect(replies.last).to match(/!help(?:.+!help HANDLER){2}/m)
    end

    it "sends help information for commands matching a substring under a given handler" do
      send_command("help help available")
      expect(replies.last).to match(/!help HANDLER - Lists/)
      expect(replies.last).not_to match(/help information/)
    end

    it "uses the mention name when no alias is defined" do
      allow(robot.config.robot).to receive(:alias).and_return(nil)
      send_command("help help")
      expect(replies.last).to match(/#{robot.mention_name}: help/)
    end

    it "responds with an error if no matching handler is installed" do
      send_command("help asdf")
      expect(replies.last).to match(/^No matching handlers found for 'asdf'$/)
    end

    it "doesn't crash if a handler doesn't have routes" do
      event_handler = Class.new do
        extend Lita::Handler::EventRouter
      end

      registry.register_handler(event_handler)

      expect { send_command("help") }.not_to raise_error
    end

    describe "restricted routes" do
      let(:authorized_user) do
        user = Lita::User.create(2, name: "Authorized User")
        Lita::Authorization.new(robot).add_user_to_group!(user, :the_nobodies)
        user
      end

      it "shows the unauthorized message for commands the user doesn't have access to" do
        send_command("help dummy")
        expect(replies.last).to include("secret")
        expect(replies.last).to include("Unauthorized")
      end

      it "omits the unauthorized message if the user has access" do
        send_command("help dummy", as: authorized_user)
        expect(replies.last).to include("secret")
        expect(replies.last).not_to include("Unauthorized")
      end
    end
  end
end
