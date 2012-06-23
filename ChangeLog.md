# Changes between Bunny 0.8.x and 0.9.0

## Bunny::Channel#open returns a OpenOk response

In 0.8.x, Bunny::Channel#open returned `:open_ok` (a symbol). In 0.9.0, it returns a response method,
`channel.open-ok`.

## Bunny::Channel#close returns a CloseOk response

In 0.8.x, Bunny::Channel#open returned `:close_ok` (a symbol). In 0.9.0, it returns a response method,
`channel.close-ok`.
