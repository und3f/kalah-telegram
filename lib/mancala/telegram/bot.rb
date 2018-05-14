require 'telegram/bot'
require 'mancala/game.rb'

class Integer
    def to_s_fw()
        to_s.chars.map { |c| (c.ord+65248).chr("utf-8") }.join
    end
end

class Bot
    attr_reader   :botName
    attr_accessor :games
    attr_accessor :users
    attr_accessor :gameId

    def initialize(token, botName)
        @botName = botName
        @games = {}
        @users = {}
        @bot = Telegram::Bot::Client.new(token, logger: Logger.new($stderr))
        @gameId = 1
    end

    def run()
        @bot.listen do |message|
            case message

            when Telegram::Bot::Types::Message
                args = message.text.split(" ")
                chatId = message.chat.id
            when Telegram::Bot::Types::CallbackQuery
                args = message.data.split(" ")
                command = args.shift()
                chatId = message.from.id
                @bot.api.answer_callback_query(callback_query_id: message.id)
            end

            command = args.shift()
            if command[0]=='/'
                command = command[1..-1]
            end

            next if command.nil?

            case command.downcase
            when 'start'
                unless args[0].nil?
                    joinGame(chatId, args[0])
                else
                    @bot.api.send_message(chat_id: chatId, text: "Welcome!")
                end
            when 'newgame'
                newGame(chatId, args)
            when 'endgame'
                game = @users[chatId]
                endGame(game) unless game.nil?
            when 'joingame'
                joinGame(chatId, args[0])
            when 'sow'
                turn(chatId, args[0].to_i - 1)
            else
                is_integer = Integer(command) rescue false
                if is_integer
                    turn(chatId, command.to_i - 1)
                else
                    @bot.api.send_message(chat_id: chatId, text: "Unknown command")
                end
            end
        end
    end

    def newGame(chatId, args)
        game = @users[chatId]
        if ! game.nil?
            @bot.api.send_message(chat_id: chatId, text: "Please end current game")
            return
        end

        board = Game.new()
        gameId = @gameId.to_s + "-" + rand(1000).to_s
        @gameId += 1
        @users[chatId] = @games[gameId] = {:board => board, :players => [chatId, nil], :id => gameId}

        url = "https://t.me/#{@botName}?start=#{gameId}"
        @bot.api.send_message(chat_id: chatId, text: "Game created, forward link to a friend #{url}")
    end

    def joinGame(chatId, joiningGame)
        game = @games[joiningGame]

        if game.nil?
            _sendMessage(chatId, "Unknown game");
            return
        end

        if !@users[chatId].nil? and @users[chatId] != game
            @bot.api.send_message(chat_id: chatId, text: "Please end current game")
            return
        end

        game[:players][1] = chatId
        @users[chatId] = game
        @bot.api.send_message(chat_id: chatId, text: "You joined game with #{game[:players][0]}")

        for i in 0..1
            boardString = _prepareBoard(game[:board].board, i)
            chatId = game[:players][i]
            _sendMessage(chatId, "Game started!\nBoard:\n" + boardString, parse_mode: 'HTML')
        end
        _sowMessage(game[:players][0], game[:board])
    end

    def turn(chatId, houseIndex)
        game = @users[chatId]
        if game.nil?
            _sendMessage(chatId, "There are no game")
            return
        end

        if (houseIndex.nil?)
            _sendMessage(chatId, "Please use /sow [house]")
            return
        end

        board = game[:board]
        unless game[:players][board.activePlayer] == chatId
            _sendMessage(chatId, "It is opponent's turn")
            return
        end
        player = board.activePlayer

        begin
            nextPlayer = board.turn(houseIndex);
        rescue ArgumentError => error
            _sendMessage(chatId, "Please validate your command, /sow <index>")
            return
        end

        _sendMessage(chatId, _prepareBoard(game[:board].board, player), parse_mode: 'HTML')
        opponent = (player + 1) % 2
        houses = board.board.size() / 2 - 1
        _sendMessage(
            game[:players][opponent],
            "Opponent sowed from the house ##{houses-houseIndex}:\n" + _prepareBoard(game[:board].board, opponent),
            parse_mode: "HTML");

        if nextPlayer.nil?
            endGame(game)
            return
        end

        chatIdNextPlayer = game[:players][nextPlayer]

        _sowMessage(chatIdNextPlayer, board)
    end

    def _sowMessage(chatId, board)
        _sendMessage(chatId, "Your turn, choose the house to sow from")
    end

    def _prepareSowKeyboard(board)
        houses = board.board.size() / 2 - 1
        kb = []
        for i in 1..houses
            kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: i, callback_data: "sow #{i}"))
        end
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [kb], one_time_keyboard: true, resize_keyboard: true)
        return markup
    end

    def endGame(game)
        for i in 0..1
            chatId = game[:players][i]
            next if chatId.nil?
            _sendMessage(chatId, "Game ended.")
            @users.delete(chatId)
        end
        @games.delete(game[:id])
        return
    end

    def _prepareBoard(board, player)
        boardString = ""
        store = board.size / 2 
        playerStore = store * (1 + player) - 1
        opponentStore = store * (1 + (player + 1) % 2) - 1

        spacing = "\u3000\u3000\u3000\u3000"
        boardString += "#{spacing}（#{board[opponentStore].to_s_fw}） -- Opponent\n"

        mirrorHouse = board.size() / 2
        offset = store * player
        for i in 0 .. board.size() / 2 - 2
            boardString += "/#{i+1}\u3000（#{board[(i + 1 + opponentStore) % board.size].to_s_fw}）\u3000（#{board[(playerStore + store - 1 - i) % board.size].to_s_fw}）\n"
        end
        boardString += "#{spacing}（#{board[playerStore].to_s_fw}） -- Own\n"
        return boardString
    end

    def _sendMessage(chatId, message, opts = {})
        @bot.api.send_message({chat_id: chatId, text: message}.merge(opts))
    end
end
