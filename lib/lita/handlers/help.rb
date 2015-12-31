require_relative "../handler/chat_router"

module Lita
  # A namespace to hold all subclasses of {Handler}.
  module Handlers
    # Provides online help about Lita commands for users.
    class Help
      extend Handler::ChatRouter

      route(
        /^help\s*((?<handler>\S+)\s*(?<substring>.+)?)?/i,
        :help, command: true, help: {
          "help" => t("help.help_value"),
          t("help.help_handler_key") => t("help.help_handler_value"),
          t("help.help_command_key") => t("help.help_command_value")
        }
      )

      # Outputs help information about Lita commands.
      # @param response [Response] The response object.
      # @return [void]
      def help(response)
        handler = response.match_data["handler"]
        return response.reply_privately(
          t("help.info", address: address) + "\n" + list_handlers.join("\n")
        ) if handler.nil?

        substring = response.match_data["substring"]
        output = list_commands(handler, substring, response.user)
        response.reply_privately(output.join("\n"))
      end

      private

      # Checks if the user is authorized to at least one of the given groups.
      def authorized?(user, required_groups)
        required_groups.nil? || required_groups.any? do |group|
          robot.auth.user_in_group?(user, group)
        end
      end

      # Creates an array containing the names (and descriptions if applicable)
      # of all installed handlers.
      def list_handlers
        robot.handlers.map do |handler|
          next unless handler.respond_to?(:routes)

          string = "#{handler.name.split('::').last}"
          string << ": #{handler.gem.description}" unless handler.gem.nil?
          string
        end.flatten.compact
      end

      # Creates an array of help info for a specified handler. Optionally
      # filters commands matching a given substring.
      def list_commands(handler_name, substring, user)
        handlers = robot.handlers.select { |handler| handler.name.split('::').last.downcase == handler_name.strip.downcase }
        return ["No matching handlers found for '#{handler_name}'"] if handlers.empty?
        output = handlers.map do |handler|
          handler.routes.map do |route|
            route.help.map do |command, description|
              string = help_command(route, command, description)
              string << t("help.unauthorized") unless authorized?(user, route.required_groups)
              string
            end
          end
        end.flatten
        filter_help(output, substring)
      end

      # Filters the help output by an optional command.
      def filter_help(output, substring)
        return output if substring.nil?
        output.select { |line| /(?:@?#{address})?#{substring}/i === line }
      end

      # Formats an individual command's help message.
      def help_command(route, command, description)
        command = "#{address}#{command}" if route.command?
        "#{command} - #{description}"
      end

      # The way the bot should be addressed in order to trigger a command.
      def address
        robot.config.robot.alias || "#{name}: "
      end

      # Fallback in case no alias is defined.
      def name
        robot.config.robot.mention_name || robot.config.robot.name
      end
    end

    Lita.register_handler(Help)
  end
end
