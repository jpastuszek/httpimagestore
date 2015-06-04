import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class LoadTest extends Simulation {
  object ImageStore {
    val root = exec(
      http("Root page")
        .get("/")
        .check(
          status.is(200),
          bodyString.is("HTTP Image Store\r\n")
        )
    )

    val health_check = exec(
      http("Health check")
        .get("/health_check")
        .check(
          status.is(200),
          bodyString.is("HTTP Image Store OK\r\n")
        )
    )
  }

  val httpConf = http
    .baseURL("http://localhost:3000")

  val check = scenario("Image Store Check").exec(
    ImageStore.root,
    ImageStore.health_check
  )

  setUp(
    check.inject(atOnceUsers(1)).protocols(httpConf)
  )
}

