# mia_elixir

This provides an environment for running Mia games, where the players are bots programmed by participants in an exercise session.

The rules of the classic MIA dice game at [wikipedia: Mia(game)](https://en.wikipedia.org/wiki/Mia_%28game%29)

Port to the Elixir programming language, with some additional Python programs.

Inspiring original is found here:

[Conrad Thrukrals Maexchen server](https://github.com/conradthukral/maexchen)

## Sub Projects:

* `echo_server`: Demonstrating basic UDP server communication in Elixir.
* `trial_server`: Server to provide sessions presenting simple mathematical tasks to participating clients. Can be used for preliminary exercise to write clients, before writing the more sophisticated clients needed for MIA gameplay.
* `mia_server`: The server running and managing a MIA gameplay session.
* `python`: Various exercises and helper programs in python. Most important `mia_observer.py`, which connects as spectator to a mia server, and plots the progression of game scores of the participating players in real-time.
* `mia_client`: My old elixir client code from the 2013 MIA hacking session. Unsure if this still works ;-)  
* `macos_localhost.sh`: Only needed when running the ExUnit mix tests under a MacOS environment. This script adds more localhost alias addresses; needed to simulate clients connecting from different IPs. Asks for root password or needs properly set sudo rights.

## License

Where not indicated otherwise:

Copyright (c) 2017 Steffen Bauer  
Distributed under the MIT license, see LICENSE

