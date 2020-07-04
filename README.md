# Tobito solver and web implementation

Tobito (飛人) is an abstract strategy game by [Yamamoto Mitsuo (山本光夫)](http://www.logygames.com/).

Its two players version is small enough to be fully solved by computer (191390 game states reachable from the starting positions).

The start positions are draws, as two perfect players will repeat positions indefinitely to avoid losing.

This web implementation features an unbeatable perfect AI, to train and learn about the game.

## Solver

This solver uses simple backwards analysis from the winning states to determine which states are sure wins for either players:

- For a given state, if any child state is a win for the current player, it is a also a win for current player (just pick that child state).
- If all children states are a win for the other player, this one is also a win for the other player (whatever we play, the other player can win).

We start from the win states, which are known, and propagate the information backwards. Any time that a state becomes determined (win for either player), we add all its parents to the queue to treat again. States that satisfy neither conditions after all children have been checked are draws: it is possible to loop infinitely in the state graph in order to avoid making a mistake.

To give something interesting to do at draw states, we compute "heatmaps" of the game space: for each state, the "heat" relative to a player is the sum of inverse squared distances to all win states for that player.

An AI player will always pick the best category of child states (wins, then draws, then losses), and within that category, the state with the best heat:

- aggressive AI tries to maximize the heat for its player
- prudent AI tries to minimize the heat for the other player
- balanced AI tries to maximize the difference

This leads to an AI player that actually goes towards winning when playing against an imperfect (human) player, making it an interesting game.

The solver was written in Lua 5.3.

## Web implementation

The web game uses basic HTML and CSS elements, and the logic is in Lua, thanks to the [Fengari](https://fengari.io/) interpreter. The web game uses fully precomputed solutions for each state and each style of AI (aggressive, balanced, prudent).

## License

The game of Tobito was created by [Yamamoto Mitsuo 山本光夫](http://www.logygames.com/) and the graphics for the board are used with his permission.

Source code for the solver and web implementation is released under the [MIT license](LICENSE.md).

Include [Fengari](https://fengari.io/), released under MIT license.
