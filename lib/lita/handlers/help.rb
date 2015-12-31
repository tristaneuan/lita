require_relative "../handler/chat_router"

module Lita
  # A namespace to hold all subclasses of {Handler}.
  module Handlers
    # Provides online help about Lita commands for users.
    class Help
      extend Handler::ChatRouter

      route(/^help\s*(.+)?/, :help, command: true, help: {
        "help" => t("help.help_value"),
        t("help.help_command_key") => t("help.help_command_value")
      })

      # Outputs help information about Lita commands.
      # @param response [Response] The response object.
      # @return [void]
      def help(response)
        # TODO: Respond with list of handlers unless argument specified; show help for specified handler in that case
        topic = response.matches[0][0]
        return response.reply_privately(list_handlers.join("\n")) if topic.nil?

        #output = build_help(response)
        #output = filter_help(output, response)
        #response.reply_privately output.join("\n")
        response.reply_privately(list_commands(topic, response.user).join("\n"))
      end

      private

      # Checks if the user is authorized to at least one of the given groups.
      def authorized?(user, required_groups)
        required_groups.nil? || required_groups.any? do |group|
          robot.auth.user_in_group?(user, group)
        end
      end

      # # Creates an array of help info for all registered routes.
      # def build_help(response)

      def list_handlers
        robot.handlers.map do |handler|
          next unless handler.respond_to?(:routes)

          string = "#{handler.name.split('::').last}"
          #string << ": #{handler.gem.description}" unless handler.gem.description.nil?
          string << ": #{handler.gem.description}" unless handler.gem.nil?

          string
        end.flatten.compact
      end

      def list_commands(topic, user)
        handlers = robot.handlers.select { |handler| handler.name.split('::').last.downcase == topic.strip.downcase }
        return "No matching help topics found for #{topic}" if handlers.empty?
        handlers.map do |handler|
          handler.routes.map do |route|
            route.help.map do |command, description|
              #string << "\n#{help_command(route, command, description)}"
              string = help_command(route, command, description)
              string << t("help.unauthorized") unless authorized?(user, route.required_groups)
              string
            end
          end
        end
      end

      # Filters the help output by an optional command.
      def filter_help(output, response)
        filter = response.matches[0][0]

        if filter
          output.select { |line| /(?:@?#{address})?#{filter}/i === line }
        else
          output
        end
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
