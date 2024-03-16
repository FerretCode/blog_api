import gleam/result
import wisp.{type Response}

pub fn try(res: Result(a, b), error: c, next) {
  result.try(result.replace_error(res, error), next)
}

pub fn default_errors(status: Int, error: a) -> Response {
  todo
}
