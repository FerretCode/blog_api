import wisp
import mist
import gleam/erlang/process
import dot_env
import router/router
import redis/redis
import dot_env/env

pub fn main() {
  dot_env.load_with_opts(dot_env.Opts(
    path: "./.env",
    debug: False,
    capitalize: False,
  ))

  wisp.configure_logger()

  let secret_key_base = case env.get("SECRET_KEY") {
    Ok(secret_key) -> secret_key
    Error(_) -> panic
  }
  let assert Ok(redis_client) = redis.connect()
  let context = router.Context(redis_client: redis_client)
  let handler = router.handle_request(_, context)
  let assert Ok(_) =
    handler
    |> wisp.mist_handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
