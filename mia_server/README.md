# MiaServer

This provides an environment for running Mia games, where the players are bots programmed by participants in an exercise session.

The game is run by a server (provided here). The players communicate with that server using a simple text-based protocol over UDP.

## Running

If required, edit config files in `/config` to adjust server port, timeout, and logging level.

Start the server with:

> mix mia.server

## The MIA Protocol

### Communication between server and clients

* Communication by lines of data via UDP (UTF-8 encoded strings, newline terminated)
* The server opens an UDP port (default 4080)
* Clients send a message to the server to register as players, and will get notified from now on the start of each new round
* The clients have a rather short time window for any replies (default 250 ms)
* During the game rounds, the server will provide a unique UUID token together with each message send to the active player/players. The player must include this token in his reply message.
* A client can also register itself as a spectator. A spectator cannot participate actively, but gets all messages that are broadcast to all clients.

### Registration
* client->server: `REGISTER;<name>`
* client->server: `REGISTER_SPECTATOR`

If `<name>` is valid and not used already:
* The server will now communicate with the client via the source IP/port of the registration message
* server->client: `REGISTERED`

If the name was already registered from the same IP:
* The server changes to the new port for further communication
* server->client: `ALREADY REGISTERED`

Otherwise:
* server->client: `REJECTED`

Criteria for a valid player name:
* no whitespace, semicolons, colons, or commas
* not longer than 20 characters

### Invitation to a new game round
* server->clients: `ROUND STARTING;<token>`
* client->server: `JOIN;<token>`

If at least one player joins:
* The joined players are shuffled randomly
* server->clients: `ROUND STARTED;<round_number>;<player names>`  
`<player names>` as a comma-separated list of participating players, in the order how they will play in this round

Otherwise:
* server->clients: `ROUND CANCELED;NO PLAYERS`  
In that case, a new round is started.

Rounds with only one participating player are cancelled immediately after they started:
* server->clients: `ROUND CANCELED;ONLY ONE PLAYER`

### Playing a round
In order of the shuffled player sequence:
* server->client: `YOUR TURN;<token>`
* client->server: `<command>;<token>`  
`<command>` one of: **ROLL**, **SEE**

#### ROLL:
* server->clients: `PLAYER ROLLS;<name>`
* server->client: `ROLLED;<dice>;<token>`
* client->server: `ANNOUNCE;<announcement>;<token>`
* server->clients: `ANNOUNCED;<name>;<announcement>`

`<dice>` and `<announcement>` format are two comma-separated die values: `<dice1>,<dice2>`

In case of announced MIA (`2,1`) the roll is immediately revealed:
* If a MIA was really rolled, all other players lose
* If any other combination was rolled, the announcing player loses

* server->clients: `PLAYER LOST;<names>;<reason>`  
`<names>` a comma-separated list of the losing player names

#### SEE:
The server determines whether the formerly announcing player has bluffed or correctly announced, and determines who has lost
* server->clients: `PLAYER WANTS TO SEE;<name>`
* server->clients: `ACTUAL DICE;<dice>`
* server->clients: `PLAYER LOST;<name>;<reason>`

#### Timeout or any other incorrect behaviour
* server->clients: `PLAYER LOST;<name>;<reason>`

#### Aftermath of a round:
* server->clients: `SCORE;<scores*>`  
`<scores*>` as a comma-separated list of entries `<name>:<score>`

#### Messages indicating reasons why player/players lost:

* `SEE BEFORE FIRST ROLL`: Player wanted to see, but he was the first player in a round (no announcement was yet made)
* `ANNOUNCED LOSING DICE`: Announcement was lower or equal to the last announced dice
* `DID NOT ANNOUNCE`: Player did not announce before timeout limit
* `DID NOT TAKE TURN`: Player did not send a command before timeout limit
* `INVALID TURN`: Player message was invalid in any way (malformed, wrong dice, wrong command etc.)
* `SEE FAILED`: Player wanted to see, but the announcement was correct
* `CAUGHT BLUFFING`: Player announced more than he actually rolled, and next player wanted to see
* `LIED ABOUT MIA`: Player announced MIA without having rolled a MIA
* `MIA`: Player announced and rolled a MIA; all other players lose this round

