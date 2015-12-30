require "spec_helper"

describe Lita::Handlers::Help, lita_handler: true do
  it { is_expected.to route_command("help").to(:help) }
  it { is_expected.to route_command("help foo").to(:help) }

  describe "#help" do
    let(:secret_handler_class) do
      Class.new(Lita::Handler) do
        route(/secret/, :secret, restrict_to: :the_nobodies, help: {
          "secret" => "no one should ever see this help message"
        })
      end
    end

    context "when no alias is defined" do
      before do
        allow(robot.config.robot).to receive(:alias).and_return(nil)
      end

      it "sends help information for all commands" do
        send_command("help")
        expect(replies.last).to match(
          /#{robot.mention_name}: help.+#{robot.mention_name}: help COMMAND/m
        )
      end

      it "sends help information for commands starting with COMMAND" do
        send_command("help help COMMAND")
        expect(replies.last).to match(/#{robot.mention_name}: help COMMAND - Lists/)
        expect(replies.last).not_to match(/help - Lists/)
      end
    end

    context "when an alias is defined" do
      before do
        allow(robot.config.robot).to receive(:alias).and_return("!")
      end

      it "sends help information for all commands" do
        send_command("help")
        expect(replies.last).to match(/!help.+!help COMMAND/m)
      end

      it "sends help information for commands starting with COMMAND" do
        send_command("help help COMMAND")
        expect(replies.last).to match(/!help COMMAND - Lists/)
        expect(replies.last).not_to match(/help - Lists/)
      end
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

      before { registry.register_handler(secret_handler_class) }

      it "shows the unauthorized message for commands the user doesn't have access to" do
        send_command("help")
        expect(replies.last).to include("secret")
        expect(replies.last).to include("Unauthorized")
      end

      it "omits the unauthorized message if the user has access" do
        send_command("help", as: authorized_user)
        expect(replies.last).to include("secret")
        expect(replies.last).not_to include("Unauthorized")
      end
    end
  end
end
