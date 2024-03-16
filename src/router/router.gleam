import wisp.{type Request, type Response}
import middleware/middleware
import routes/post/post
import routes/user/user
import redis/redis

pub type Context {
  Context(redis_client: redis.RedisClient)
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- middleware.middleware(req)
  case wisp.path_segments(req) {
    [] -> post.get_posts(req)

    ["user", "create"] -> user.create_user(req, ctx.redis_client)

    ["post", "posts"] -> post.get_posts(req)

    _ -> wisp.not_found()
  }
}
