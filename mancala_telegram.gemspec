# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
    spec.name       = "Mancala-Telegram"
    spec.summary    = "Mancala game Telegram Bot"
    spec.version    = 0.1
    spec.authors    = "Sergey Zasenko"
    spec.email      = "sergii@zasenko.name"
    spec.license    = "GPL-3.0"
    spec.files      = ["lib/mancala/game.rb"]
    spec.require_paths = ["lib"]
    spec.homepage   = "https://github.com/und3f/mancala-telegram"
end
