# TrialServer

Simple elixir server application to demonstrate basic UDP communication, with need to keep track of session state. Can be used for a preliminary exercise session before writing clients for the MIA server.

## Running

> mix trial.server

## The Trial protocol

* Communication by lines of data via UDP (UTF-8 encoded strings, newline terminated)
* The server opens an UDP port (default 4080)
* A client requests a trial session, the server will then send in turn five mathematical tasks and wait for the solution.
* After five tasks are completed, the server will send a summary report.

### A trial session
* client->server: `START`
* server->client: `<task>`  
`<task>` is a string with the following structure:
`<function>:<uuid>:<parameter>:<parameter>[:<parameter>]*`
* client->server: `<uuid>:<result>`

`<function>` is one of **ADD**, **MULTIPLY**, **SUBTRACT**. Parameters are integers. There are at least two parameters, but there can be more.

Example server messages are:

* `ADD:4160806a2f2846759d6c7e764f4bcbd5:184:106:107`
* `SUBTRACT:45429b851ac549fc9e2e38f9ee289061:27:107:91:55`
* `MULTIPLY:6868c974bf7140eabb18b826bedacd54:175:126:172:119`

The correct responses for these example server messages:

* `4160806a2f2846759d6c7e764f4bcbd5:397`
* `45429b851ac549fc9e2e38f9ee289061:-226`
* `6868c974bf7140eabb18b826bedacd54:451319400`

After five tasks are completed:
* server->client: `ALL CORRECT` (if all results were correct)
* server->client: `<n1> WRONG, <n2> CORRECT` (reporting number of wrong / correct results)

