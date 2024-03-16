import radish
import radish/client.{type Message}
import gleam/erlang/process.{type Subject}
import gleam/result
import gleam/int
import errors/errors.{try}
import dot_env/env

pub type RadishError {
  ParseError
  ConnectionError
}

pub type RedisClient {
  RedisClient(connection: Subject(Message))
}

fn get_port() -> Result(Int, RadishError) {
  use redis_port_string <- try(env.get("REDIS_PORT"), ParseError)
  use redis_port <- try(int.parse(redis_port_string), ParseError)
  Ok(redis_port)
}

pub fn connect() -> Result(RedisClient, RadishError) {
  use redis_host <- try(env.get("REDIS_HOST"), ParseError)
  let result = {
    use port <- result.try(get_port())
    use client <- try(
      radish.start(redis_host, port, [radish.Timeout(128)]),
      ConnectionError,
    )
    Ok(client)
  }
  case result {
    Ok(connection) -> Ok(RedisClient(connection))
    Error(_) -> Error(ConnectionError)
  }
}

pub fn disconnect(client: RedisClient) {
  radish.shutdown(client.connection)
}
