# TrademarkFreeStrategicLandWarfare

Sort of like Stratego.  Heck, a whole lot like Stratego.

## Rules

  * http://www.stratego.com/en/play/stratego-rules/
  * https://www.playmonster.com/wp-content/uploads/2018/06/7471_Classic_English_Rules.pdf

Be sure to pay attention to the dynamics of the `:scout`, `:spy`, `:marshall`, and `:miner`.

## Instructions

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server` (or `iex -S mix phx.server` if you like to insert `IEx.pry` debugger statements)

## LiveView

I decided to give LiveView a try.  Here is the result.  Visit [`localhost:4000/stratego`](http://localhost:4000/stratego)
in your browser.

Select 2 players (they can both be the same implementation / name), and then click "GO!".  You'll see play/pause/forward type
controls shortly thereafter, and you can navigate the game to help troubleshoot.

You can hover over any square to learn what kind of piece it is and what its rank is.

## Fork this repo

You'll make a bot and then open a PR against this repo.

## Make a bot

Your bot should implement `@behaviour TrademarkFreeStrategicLandWarfare.Player`.  You'll need 3 functions in your module,
which should be put in the `lib/trademark_free_strategic_land_warfare/players/` directory.

  * `name()`
    * return the text name of your player.
  * `initial_pieces_placement()`
    * return your initial piece placement, from the perspective of the person sitting at the bottom of the board.  it
      should be a list with 4 lists of 10 player piece names (`:miner`, `:bomb`, etc.)
  * `turn(%TrademarkFreeStrategicLandWarfare.Board{}, %TrademarkFreeStrategicLandWarfare.Player{}, any())
    * return `{piece.uuid, direction, spaces to advance, state}`

Keep in mind that the `%Board{}` passed  to `turn()` is not rotated. If you are player 2, you will start at the top
of the board.  You will be randomly assigned a player number for each battle in the finals.  There are a ton of public
functions that you can use in `Board`, `Player`, and `Piece`.  Some will help you with rotating the table if you
prefer to think of it from a single player's position.  It was too hard to make an intuitive interface that flipped the board
for you automatically.  I hope it isn't too painful.

Just like if you were playing the game for real, you can only know another player's piece by:
  * a piece moving more than 1 square in a single turn, which is immediately revealed as a `:scout`
  * a defending piece that is attacked will reveal both that piece and the attacker piece, and at most only one of those
    will remain.  So keep in mind that some of the functions, like `Piece.attack/2` won't give you any information
    on who will win if the piece is currently marked as `visible: false`.

See `TrademarkFreeStrategicLandWarfare.Players.SemiRandom` for an example.

## Open a PR

Once everyone has submitted, we'll run everyone against everyone else.  Originally, I hoped to make a tournament
structure for this, but I didn't have time (and trust me, this took enough time as it is).

## Remaining TODOs

  * a way to run all the players against each other
  * a way to run previous games
  * add unit tests for `Player`, `Players`, and `Game`.
  * help me make the interface better
  * make a human-playable version that can be put online, akin to https://codenames.plus.
  * deploy that to heroku or digital ocean
  * special rule for loss on 3 back to back identical moves between two squares
